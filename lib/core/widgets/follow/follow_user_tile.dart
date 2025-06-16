import 'package:flutter/material.dart';
import 'package:logue/core/themes/app_colors.dart';
import 'package:logue/domain/entities/follow_list_type.dart';

class FollowUserTile extends StatelessWidget {
  final String userId;
  final String username;
  final String name;
  final String avatarUrl;
  final bool isFollowing;
  final bool isMyProfile;
  final FollowListType? tabType;
  final VoidCallback? onTapFollow;
  final VoidCallback? onTapRemove;
  final VoidCallback? onTapProfile;
  final String currentUserId;

  const FollowUserTile({
    super.key,
    required this.userId,
    required this.username,
    required this.name,
    required this.avatarUrl,
    required this.isFollowing,
    required this.isMyProfile,
    required this.currentUserId,
    this.tabType,
    this.onTapFollow,
    this.onTapRemove,
    this.onTapProfile,
  });

  @override
  Widget build(BuildContext context) {
    // 팔로우 버튼 조건
    final showFollowButton = () {
      if (userId == currentUserId) return false;
      // 내가 보고 있고 아직 팔로우 안한 팔로워
      if (isMyProfile && !isFollowing && tabType == FollowListType.followers) {
        return true;
      }

      // 상대방 프로필인데 아직 팔로우 안 한 사용자
      if (!isMyProfile && !isFollowing) {
        return true;
      }

      return false;
    }();


    final showRemoveButton = isMyProfile && tabType == FollowListType.followers;

    return Padding(
        padding: showRemoveButton
            ? const EdgeInsets.fromLTRB(22, 8, 10, 8)
            : const EdgeInsets.fromLTRB(22, 8, 22, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: onTapProfile,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 27,
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

          if (showFollowButton)
            OutlinedButton(
              onPressed: onTapFollow,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.black900, width: 1),
                padding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
                minimumSize: const Size(0, 0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              child: const Text(
                "팔로우",
                style: TextStyle(fontSize: 12, color: AppColors.black900,fontWeight: FontWeight.w400),
              ),
            )
          else
            const SizedBox(height : 26),

          if (showRemoveButton)
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: onTapRemove,
            ),
        ],
      ),
    );
  }
}