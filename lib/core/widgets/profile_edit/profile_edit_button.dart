import 'package:flutter/material.dart';
import 'package:logue/core/themes/app_colors.dart';

class ProfileEditButton extends StatelessWidget {
  final String label;       // 위에 표시되는 회색 텍스트
  final String username;    // 버튼 안에 표시될 유저 이름
  final VoidCallback onTap; // 버튼 클릭 시 실행될 함수

  const ProfileEditButton({
    Key? key,
    required this.label,
    required this.username,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 9),
          child:Text(
            label,
            style: TextStyle(fontSize: 12, color: AppColors.black500),
          ),),
        Stack(
          children: [
            OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.black500, width: 1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: 9,
                  horizontal: 9,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      username,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.black900, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}