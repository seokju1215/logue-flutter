import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logue/core/themes/app_colors.dart';
import 'package:logue/core/widgets/follow/follow_user_tile.dart';

class LifebookUsersScreen extends StatefulWidget {
  final List<Map<String, dynamic>> users;

  const LifebookUsersScreen({
    super.key,
    required this.users,
  });

  @override
  State<LifebookUsersScreen> createState() => _LifebookUsersScreenState();
}

class _LifebookUsersScreenState extends State<LifebookUsersScreen> {
  late final String? currentUserId;
  late List<Map<String, dynamic>> userList;

  @override
  void initState() {
    super.initState();
    currentUserId = Supabase.instance.client.auth.currentUser?.id;

    // 본인을 가장 위로 정렬
    userList = [...widget.users];
    userList.sort((a, b) {
      if (a['id'] == currentUserId) return -1;
      if (b['id'] == currentUserId) return 1;
      return 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: const Text('인생책 설정한 사람들', style: TextStyle(color: AppColors.black900, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.black900),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: userList.isEmpty
          ? const Center(child: Text('아직 인생책으로 설정한 사람이 없어요.', style: TextStyle(color: AppColors.black500)))
          : ListView.builder(
        itemCount: userList.length,
        itemBuilder: (context, index) {
          final user = userList[index];
          return FollowUserTile(
            userId: user['id'],
            username: user['username'] ?? '사용자',
            name: user['name'] ?? '',
            avatarUrl: user['avatar_url'] ?? 'basic',
            isFollowing: user['is_following'] ?? false,
            showActions: user['id'] != currentUserId,
            showdelete: false,
            onTapFollow: () {
              // 원한다면 FollowUser usecase 연동 가능
            },
            onTapProfile: () {
              Navigator.pushNamed(
                context,
                '/other_profile',
                arguments: user['id'],
              );
            },
          );
        },
      ),
    );
  }
}