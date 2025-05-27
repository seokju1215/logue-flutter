import 'package:flutter/material.dart';
import 'package:logue/core/themes/app_colors.dart';
import 'package:logue/domain/entities/follow_list_type.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logue/data/repositories/follow_repository.dart';
import 'package:logue/domain/usecases/follows/follow_user.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class FollowListTab extends StatefulWidget {
  final FollowListType type;
  final String userId;
  final bool isMyProfile;

  const FollowListTab({
    super.key,
    required this.type,
    required this.userId,
    required this.isMyProfile,
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
        }).toList();
      });
    } else {
      setState(() => users = rawList);
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

    return ListView.builder(
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        final avatarUrl = user['avatar_url'] ?? 'basic';
        final username = user['username'] ?? '사용자';
        final name = user['name'] ?? '';
        final isFollowing = user['isFollowing'] == true;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/other_profile', arguments: user['id']),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundImage:
                      avatarUrl == 'basic' ? null : NetworkImage(avatarUrl),
                      child: avatarUrl == 'basic'
                          ? Image.asset('assets/basic_avatar.png')
                          : null,
                    ),
                    const SizedBox(width: 22),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(username, style: const TextStyle(fontSize: 14, color: AppColors.black900)),
                        Text(name, style: const TextStyle(fontSize: 12, color: AppColors.black500)),
                      ],
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (widget.type == FollowListType.followers && isMyProfile) ...[
                if (!isFollowing)
                  OutlinedButton(
                    onPressed: () => _handleFollow(user['id']),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.black900),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      minimumSize: const Size(0, 0),
                    ),
                    child: const Text("팔로우", style: TextStyle(fontSize: 12, color: AppColors.black900)),
                  ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => _handleRemoveFollower(user['id']),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}