import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:logue/core/themes/app_colors.dart';
import 'package:logue/core/widgets/follow/follow_user_tile.dart';
import 'package:logue/presentation/screens/profile/other_profile_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/widgets/common/custom_app_bar.dart';

class LifebookUsersScreen extends StatefulWidget {
  final List<Map<String, dynamic>> users;

  const LifebookUsersScreen({super.key, required this.users});

  @override
  State<LifebookUsersScreen> createState() => _LifebookUsersScreenState();
}

class _LifebookUsersScreenState extends State<LifebookUsersScreen> {
  late List<Map<String, dynamic>> lifebookUsers;
  late String currentUserId;

  @override
  void initState() {
    super.initState();
    currentUserId = Supabase.instance.client.auth.currentUser?.id ?? '';
    lifebookUsers = _sortUsers(widget.users);
  }

  List<Map<String, dynamic>> _sortUsers(List<Map<String, dynamic>> users) {
    final sorted = [...users];
    sorted.sort((a, b) {
      if (a['id'] == currentUserId) return -1;
      if (b['id'] == currentUserId) return 1;

      final aFollowing = (a['is_following'] ?? false) as bool;
      final bFollowing = (b['is_following'] ?? false) as bool;

      if (aFollowing && !bFollowing) return -1;
      if (!aFollowing && bFollowing) return 1;

      return 0;
    });
    return sorted;
  }

  Future<void> _handleFollow(String userId) async {
    final index = lifebookUsers.indexWhere((u) => u['id'] == userId);
    if (index == -1) return;

    final prev = [...lifebookUsers];
    setState(() {
      lifebookUsers[index] = {
        ...lifebookUsers[index],
        'is_following': true,
      };
    });

    final res = await Supabase.instance.client.functions.invoke(
      'follow-user',
      body: {'target_user_id': userId},
      headers: {
        'Authorization':
        'Bearer ${Supabase.instance.client.auth.currentSession?.accessToken}'
      },
    );

    if (res.status == null || res.status! >= 400) {
      // ❌ 실패했으니 롤백 + 안내
      setState(() {
        lifebookUsers = prev;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('팔로우에 실패했어요.')),
      );
    } else {
      // ✅ 성공 시 UI가 잘 반영된 상태 유지
      print('✅ 팔로우 성공: ${res.data}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          '인생 책으로 설정한 사람',
          style: TextStyle(
            fontSize: 16,
            color: AppColors.black900,
            fontWeight: FontWeight.w500,
          ),
        ),
        leading: IconButton(
          icon: SvgPicture.asset('assets/back_arrow.svg'),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      backgroundColor: Colors.white,
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 0),
        itemCount: lifebookUsers.length,
        itemBuilder: (context, index) {
          final user = lifebookUsers[index];
          return FollowUserTile(
            currentUserId: currentUserId,
            userId: user['id'],
            username: user['username'],
            name: user['name'],
            avatarUrl: user['avatar_url'] ?? 'basic',
            isMyProfile: false,
            onTapFollow: () => _handleFollow(user['id']),
            onTapProfile: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => OtherProfileScreen(userId: user['id']),
                ),
              );

              if (mounted && result == true) {
                final profileRes = await Supabase.instance.client
                    .from('profiles')
                    .select('id, username, name, avatar_url')
                    .eq('id', user['id'])
                    .maybeSingle();

                final followRes = await Supabase.instance.client
                    .from('follows')
                    .select('id')
                    .eq('follower_id', currentUserId)
                    .eq('following_id', user['id'])
                    .maybeSingle();

                final profile = profileRes;
                final isFollowing = followRes != null;

                if (profile != null) {
                  setState(() {
                    final index = lifebookUsers
                        .indexWhere((u) => u['id'] == user['id']);
                    if (index != -1) {
                      lifebookUsers[index] = {
                        ...profile,
                        'is_following': isFollowing,
                      };
                      lifebookUsers = _sortUsers(lifebookUsers);
                    }
                  });
                }
              }
            },
          );
        },
      ),
    );
  }
}
