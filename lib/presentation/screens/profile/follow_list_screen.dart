import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logue/domain/entities/follow_list_type.dart';
import 'package:logue/core/themes/app_colors.dart';
import 'package:logue/data/repositories/follow_repository.dart';
import 'package:logue/domain/usecases/follows/follow_user.dart';
import 'package:logue/domain/usecases/follows/unfollow_user.dart';
import 'package:logue/domain/usecases/follows/is_following.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class FollowListTab extends StatefulWidget {
  final FollowListType type;
  final String userId;

  const FollowListTab({super.key, required this.type, required this.userId});

  @override
  State<FollowListTab> createState() => _FollowListTabState();
}

class _FollowListTabState extends State<FollowListTab> {
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
          .eq('follower_id', currentUserId)
          .in_('following_id', idList);

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
    await _followUser(targetUserId);
    await _fetchFollowList();
  }

  Future<void> _handleRemoveFollower(String targetUserId) async {
    await client.rpc('remove_follower', params: {
      'target_user_id': targetUserId,
    });
    await _fetchFollowList();
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
              if (isMyProfile)
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