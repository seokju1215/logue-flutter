import 'package:flutter/material.dart';
import 'package:logue/core/themes/app_colors.dart';

class FollowUserTile extends StatelessWidget {
  final String userId;
  final String username;
  final String name;
  final String avatarUrl;
  final bool isFollowing;
  final bool showActions;
  final bool showdelete;
  final VoidCallback? onTapFollow;
  final VoidCallback? onTapRemove;
  final VoidCallback? onTapProfile;

  const FollowUserTile({
    super.key,
    required this.userId,
    required this.username,
    required this.name,
    required this.avatarUrl,
    required this.isFollowing,
    required this.showActions,
    required this.showdelete,
    this.onTapFollow,
    this.onTapRemove,
    this.onTapProfile,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: onTapProfile,
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
                    Text(username,
                        style: const TextStyle(
                            fontSize: 14, color: AppColors.black900)),
                    Text(name,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.black500)),
                  ],
                ),
              ],
            ),
          ),
          const Spacer(),
          // Follow 버튼 (조건: showActions == true && !isFollowing)
          if (showActions && !isFollowing)
            OutlinedButton(
              onPressed: onTapFollow,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.black900),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
                minimumSize: const Size(0, 0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              child: const Text(
                "팔로우",
                style: TextStyle(fontSize: 12, color: AppColors.black900),
              ),
            ),

          if (showdelete && isFollowing)
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: onTapRemove,
            ),
        ],
      ),
    );
  }
}
