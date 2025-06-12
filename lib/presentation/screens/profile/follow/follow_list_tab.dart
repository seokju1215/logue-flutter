import 'package:flutter/material.dart';
import 'package:logue/core/themes/app_colors.dart';
import 'package:logue/domain/entities/follow_list_type.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logue/data/repositories/follow_repository.dart';
import 'package:logue/domain/usecases/follows/follow_user.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../../../core/widgets/follow/follow_user_tile.dart';
import '../other_profile_screen.dart';

class FollowListTab extends StatefulWidget {
  final FollowListType type;
  final String userId;
  final bool isMyProfile;
  final void Function()? onChangedCount;

  const FollowListTab({
    super.key,
    required this.type,
    required this.userId,
    required this.isMyProfile,
    this.onChangedCount,
  });

  @override
  State<FollowListTab> createState() => _FollowListTabState();
}

class _FollowListTabState extends State<FollowListTab> {
  final client = Supabase.instance.client;
  late final FollowRepository _followRepo;
  late final FollowUser _followUser;

  List<Map<String, dynamic>> users = [];
  String? currentUserId;

  bool get isMyProfile => currentUserId == widget.userId;

  @override
  void initState() {
    super.initState();
    _followRepo = FollowRepository(
      client: client,
      functionBaseUrl: dotenv.env['FUNCTION_BASE_URL']!,
    );
    _followUser = FollowUser(_followRepo);
    currentUserId = client.auth.currentUser?.id;
    _fetchFollowList();
  }

  @override
  void didUpdateWidget(covariant FollowListTab oldWidget) {
    super.didUpdateWidget(oldWidget);

    // userId가 바뀌었거나, 화면이 다시 보여질 때 다시 불러오기
    if (oldWidget.userId != widget.userId || oldWidget.type != widget.type) {
      _fetchFollowList();
    }
  }

  Future<void> _fetchFollowList() async {
    if (currentUserId == null) return;

    final table = widget.type == FollowListType.followers
        ? 'followers_with_profiles'
        : 'followings_with_profiles';
    final column = widget.type == FollowListType.followers
        ? 'following_id'
        : 'follower_id';

    final res = await client.from(table).select().eq(column, widget.userId);

    final List<Map<String, dynamic>> rawList =
        List<Map<String, dynamic>>.from(res);

    if (widget.type == FollowListType.followers) {
      final idList = rawList.map((e) => e['id']).toList();
      final followRes = await client
          .from('follows')
          .select('following_id')
          .eq('follower_id', currentUserId)
          .in_('following_id', idList);

      final followingIds =
          (followRes as List).map((e) => e['following_id']).toSet();

      setState(() {
        users = rawList.map((user) {
          return {
            ...user,
            'isFollowing': followingIds.contains(user['id']),
          };
        }).toList()
          ..sort((a, b) {
            final aFollowing = a['isFollowing'] == true ? 0 : 1;
            final bFollowing = b['isFollowing'] == true ? 0 : 1;
            return aFollowing.compareTo(bFollowing);
          });
      });
    } else {
      if (!isMyProfile && widget.type == FollowListType.followings) {
        final index = rawList.indexWhere((user) => user['id'] == currentUserId);
        if (index != -1) {
          final me = rawList.removeAt(index);
          rawList.insert(0, me); // 현재 유저를 최상단으로 이동
        }
      }

      // 🔄 이 부분 전체를 아래로 교체
      final idList = rawList.map((e) => e['id']).toList();
      final followRes = await client
          .from('follows')
          .select('following_id')
          .eq('follower_id', currentUserId)
          .in_('following_id', idList);

      final followingIds = (followRes as List).map((e) => e['following_id']).toSet();

      final enrichedList = rawList.map((user) {
        final isSelf = user['id'] == currentUserId;
        return {
          ...user,
          'isFollowing': followingIds.contains(user['id']),
        };
      }).toList();
      enrichedList.sort((a, b) {
        final aFollowing = a['isFollowing'] == true ? 0 : 1;
        final bFollowing = b['isFollowing'] == true ? 0 : 1;
        return aFollowing.compareTo(bFollowing);
      });

      setState(() => users = enrichedList);
    }
  }

  Future<void> _handleFollow(String targetUserId) async {
    // 1. UI 먼저 업데이트
    setState(() {
      final index = users.indexWhere((u) => u['id'] == targetUserId);
      if (index != -1) {
        users[index]['isFollowing'] = true;
        users.sort((a, b) {
          final aFollowing = a['isFollowing'] == true ? 0 : 1;
          final bFollowing = b['isFollowing'] == true ? 0 : 1;
          return aFollowing.compareTo(bFollowing);
        });
      }
    });

    // 2. 서버 반영
    await _followUser(targetUserId);

    // 3. 카운트 업데이트
    widget.onChangedCount?.call();

    // 4. 최종 동기화
    await _fetchFollowList();
  }

  Future<void> _handleRemoveFollower(String targetUserId) async {
    await client.rpc('remove_follower', params: {
      'target_user_id': targetUserId,
    });
    widget.onChangedCount?.call();
    await _fetchFollowList();
  }

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return const Center(child: Text('친구를 추가해 서로의 인생 책을 공유해보세요.', style: TextStyle(color: AppColors.black500, fontSize: 12),));
    }

    return ListView.builder(
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        final avatarUrl = user['avatar_url'] ?? 'basic';
        final username = user['username'] ?? '사용자';
        final name = user['name'] ?? '';
        final isFollowing = user['isFollowing'] == true;

        return FollowUserTile(
          userId: user['id'],
          username: username,
          name: name,
          avatarUrl: avatarUrl,
          isFollowing: isFollowing,
          isMyProfile: isMyProfile,
          tabType: widget.type,
          onTapFollow: () => _handleFollow(user['id']),
          onTapRemove: () => _handleRemoveFollower(user['id']),
          onTapProfile: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => OtherProfileScreen(userId: user['id']),
              ),
            ).then((result) {
              if (result == true) {
                widget.onChangedCount?.call();
                _fetchFollowList();
              }
            });
          },
        );
      },
    );
  }
}
