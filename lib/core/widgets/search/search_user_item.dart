import 'package:flutter/material.dart';

import '../../../data/models/user_profile.dart';
import '../../themes/app_colors.dart';

class SearchUserItem extends StatelessWidget {
  final UserProfile user;
  final bool isFollowing;
  final VoidCallback onTapFollow;
  final VoidCallback onTapProfile;

  const SearchUserItem({
    super.key,
    required this.user,
    required this.isFollowing,
    required this.onTapFollow,
    required this.onTapProfile,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTapProfile, // ✅ 전체 영역 클릭시
      child: Row(
        children: [
          // 프로필 이미지
          CircleAvatar(
            radius: 27,
            backgroundImage: (user.avatarUrl == null || user.avatarUrl == 'basic')
                ? const AssetImage('assets/basic_avatar.png')
                : NetworkImage(user.avatarUrl!) as ImageProvider,
          ),
          const SizedBox(width: 10),
          // 이름 + 직업
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.username, style: const TextStyle(color: AppColors.black900, fontSize: 14)),
                Text(user.name, style: const TextStyle(color: AppColors.black500, fontSize: 12)),
              ],
            ),
          ),
          // 팔로우 버튼
          OutlinedButton(
            onPressed: onTapFollow,
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: isFollowing ? AppColors.black300 : AppColors.black900),
              foregroundColor: isFollowing ? AppColors.black500 : AppColors.black900,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
              ),
            ),
            child: Text(
              isFollowing ? '팔로잉' : '팔로우',
              style: TextStyle(fontSize: 12, color: isFollowing ? AppColors.black500 : AppColors.black900),
            ),
          )
        ],
      ),
    );
  }
}