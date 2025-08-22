import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_logue/domain/entities/follow_list_type.dart';
import 'package:my_logue/core/themes/app_colors.dart';
import 'package:my_logue/data/repositories/follow_repository.dart';
import 'package:my_logue/domain/usecases/follows/follow_user.dart';
import 'package:my_logue/domain/usecases/follows/unfollow_user.dart';
import 'package:my_logue/domain/usecases/follows/is_following.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../../core/providers/follow_state_provider.dart';
import '../../../data/utils/firebase_analytics_util.dart';

class FollowListTab extends ConsumerStatefulWidget {
  final FollowListType type;
  final String userId;

  const FollowListTab({super.key, required this.type, required this.userId});

  @override
  ConsumerState<FollowListTab> createState() => _FollowListTabState();
}

class _FollowListTabState extends ConsumerState<FollowListTab> {
  final client = Supabase.instance.client;
  late final FollowRepository _followRepo;
  late final FollowUser _followUser;
  late final UnfollowUser _unfollowUser;
  late final IsFollowing _isFollowing;
  List<Map<String, dynamic>> users = [];
  String? currentUserId;

  @override
  void initState() {
    super.initState();
    _followRepo = FollowRepository(
      client: client,
      functionBaseUrl: dotenv.env['FUNCTION_BASE_URL']!,
    );
    _followUser = FollowUser(_followRepo);
    _unfollowUser = UnfollowUser(_followRepo);
    _isFollowing = IsFollowing(_followRepo);

    currentUserId = client.auth.currentUser?.id;
    _fetchFollowList();
    print('📌 currentUserId: $currentUserId');
    print('📌 widget.userId: ${widget.userId}');
  }

  Future<void> _fetchFollowList() async {
    if (currentUserId == null) return;

    final table = widget.type == FollowListType.followers
        ? 'followers_with_profiles'
        : 'followings_with_profiles';
    final column = widget.type == FollowListType.followers
        ? 'following_id'
        : 'follower_id';

    final res = await client
        .from(table)
        .select()
        .eq(column, widget.userId);

    if (widget.type == FollowListType.followers) {
      final idList = res.map((e) => e['id']).toList();
      final followCheck = await client
          .from('follows')
          .select('following_id')
          .eq('follower_id', currentUserId ?? '')
          .inFilter('following_id', idList);

      final followingIds = followCheck.map((e) => e['following_id']).toSet();

      setState(() {
        users = res.map((user) {
          return {
            ...user,
            'isFollowing': followingIds.contains(user['id']),
          };
        }).toList();
      });
    } else {
      setState(() => users = List<Map<String, dynamic>>.from(res));
    }
  }

  Future<void> _handleFollow(String targetUserId) async {
    // StateProvider 상태 즉시 업데이트
    final followNotifier = ref.read(followStateProvider(targetUserId).notifier);
    followNotifier.optimisticFollow();
    
    // 로컬 상태 즉시 업데이트
    setState(() {
      final index = users.indexWhere((u) => u['id'] == targetUserId);
      if (index != -1) {
        users[index]['isFollowing'] = true;
      }
    });
    
    // 서버 요청 (백그라운드)
    followNotifier.follow().then((_) {
      // Firebase Analytics 이벤트 전송 (별도 try-catch)
      try {
        final targetUser = users.firstWhere((u) => u['id'] == targetUserId, orElse: () => {});
        debugPrint('🚀🚀🚀 팔로우 리스트에서 이벤트 전송 시도: $targetUserId');
        FirebaseAnalyticsUtil.logFollowUser(
          targetUserId: targetUserId,
          targetUsername: targetUser['username'] ?? '',
          sourceScreen: 'follow_list_screen',
        );
        debugPrint('🎯🎯🎯 팔로우 리스트에서 이벤트 전송 완료: $targetUserId');
      } catch (analyticsError) {
        debugPrint('❌ 팔로우 리스트 이벤트 전송 실패: $analyticsError');
      }
    }).catchError((e) {
      debugPrint('❌ 팔로우 실패: $e');
      // 실패 시 롤백
      followNotifier.optimisticUnfollow();
      if (mounted) {
        setState(() {
          final index = users.indexWhere((u) => u['id'] == targetUserId);
          if (index != -1) {
            users[index]['isFollowing'] = false;
          }
        });
      }
    });
  }

  Future<void> _handleUnfollow(String targetUserId) async {
    // StateProvider 상태 즉시 업데이트
    final followNotifier = ref.read(followStateProvider(targetUserId).notifier);
    followNotifier.optimisticUnfollow();
    
    // 로컬에서 즉시 제거 (팔로잉 탭에서는 언팔로우 시 목록에서 제거)
    setState(() {
      final index = users.indexWhere((u) => u['id'] == targetUserId);
      if (index != -1) {
        if (widget.type == FollowListType.followings) {
          users.removeAt(index);
        } else {
          users[index]['isFollowing'] = false;
        }
      }
    });
    
    // 서버 요청 (백그라운드)
    followNotifier.unfollow().then((_) {
      // Firebase Analytics 이벤트 전송
      final targetUser = users.firstWhere((u) => u['id'] == targetUserId, orElse: () => {});
      FirebaseAnalyticsUtil.logUnfollowUser(
        targetUserId: targetUserId,
        targetUsername: targetUser['username'] ?? '',
        sourceScreen: 'follow_list_screen',
      );
    }).catchError((e) {
      debugPrint('❌ 언팔로우 실패: $e');
      // 실패 시 롤백
      followNotifier.optimisticFollow();
      if (mounted) {
        _fetchFollowList();
      }
    });
  }

  Future<void> _handleRemoveFollower(String targetUserId) async {
    // 로컬에서 즉시 제거
    setState(() {
      final index = users.indexWhere((u) => u['id'] == targetUserId);
      if (index != -1) {
        users.removeAt(index);
      }
    });
    
    // 서버 요청 (백그라운드)
    client.rpc('remove_follower', params: {
      'target_user_id': targetUserId,
    }).catchError((e) {
      debugPrint('❌ 팔로워 제거 실패: $e');
      // 실패 시 다시 추가 (사용자 정보를 다시 가져와야 함)
      if (mounted) {
        _fetchFollowList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return const Center(child: Text('사용자가 없습니다.'));
    }

    final isMyProfile = currentUserId == widget.userId;

    return ListView.builder(
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        final avatarUrl = user['avatar_url'] ?? 'basic';
        final username = user['username'] ?? '사용자';
        final name = user['name'] ?? '';
        final isFollowing = user['isFollowing'] == true;

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: CircleAvatar(
            backgroundImage: avatarUrl == 'basic' ? null : NetworkImage(avatarUrl),
            child: avatarUrl == 'basic'
                ? Image.asset('assets/basic_avatar.png')
                : null,
          ),
          title: Text(username, style: const TextStyle(fontSize: 14, color: AppColors.black900)),
          subtitle: Text(name, style: const TextStyle(fontSize: 12, color: AppColors.black500)),
          onTap: () {
            print('✅ Tapped: ${user["id"]}');
            Navigator.pushNamed(context, '/other_profile', arguments: user['id']);
          },
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.type == FollowListType.followers && isMyProfile && !isFollowing)
                OutlinedButton(
                  onPressed: () => _handleFollow(user['id']),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.black900),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    minimumSize: const Size(0, 0),
                  ),
                  child: const Text("팔로우", style: TextStyle(fontSize: 12, color: AppColors.black900)),
                ),
              if (widget.type == FollowListType.followings && isFollowing)
                OutlinedButton(
                  onPressed: () => _handleUnfollow(user['id']),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.black500),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    minimumSize: const Size(0, 0),
                  ),
                  child: const Text("팔로잉", style: TextStyle(fontSize: 12, color: AppColors.black500)),
                ),
              if (isMyProfile && widget.type == FollowListType.followers)
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: () => _handleRemoveFollower(user['id']),
                ),
            ],
          ),
        );
      },
    );
  }
}