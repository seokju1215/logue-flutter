import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:logue/core/themes/app_colors.dart';
import 'package:logue/core/widgets/follow/follow_user_tile.dart';
import 'package:logue/data/repositories/follow_repository.dart';
import 'package:logue/domain/usecases/follows/follow_user.dart';

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
  late final FollowRepository _followRepo;
  late final FollowUser _followUser;
  late List<Map<String, dynamic>> userList;

  @override
  void initState() {
    super.initState();
    currentUserId = Supabase.instance.client.auth.currentUser?.id;

    _followRepo = FollowRepository(
      client: Supabase.instance.client,
      functionBaseUrl: dotenv.env['FUNCTION_BASE_URL']!,
    );
    _followUser = FollowUser(_followRepo);

    userList = [...widget.users];
    userList.sort((a, b) {
      if (a['id'] == currentUserId) return -1;
      if (b['id'] == currentUserId) return 1;
      return 0;
    });
  }

  Future<void> _handleFollow(String userId) async {
    await _followUser(userId);

    // 팔로우 상태 최신화
    setState(() {
      userList = userList.map((user) {
        if (user['id'] == userId) {
          return {...user, 'is_following': true};
        }
        return user;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: const Text('인생책 설정한 사람들',
            style: TextStyle(color: AppColors.black900, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.black900),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: userList.isEmpty
          ? const Center(
          child: Text('아직 인생책으로 설정한 사람이 없어요.',
              style: TextStyle(color: AppColors.black500)))
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
            isMyProfile: user['id'] == currentUserId,
            onTapFollow: () => _handleFollow(user['id']),
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