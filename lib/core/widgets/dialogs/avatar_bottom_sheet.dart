import 'package:flutter/material.dart';
import 'package:my_logue/core/themes/app_colors.dart';

class AvatarBottomSheet extends StatelessWidget {
  final VoidCallback onPhotoLibraryTap;
  final VoidCallback onDeleteTap;

  const AvatarBottomSheet({
    super.key,
    required this.onPhotoLibraryTap,
    required this.onDeleteTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(40),
          topRight: Radius.circular(40),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 8,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 드래그 핸들
          Container(
            margin: const EdgeInsets.only(top: 15),
            width: 40,
            height: 3,
            decoration: BoxDecoration(
              color: AppColors.black900,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
                      // 옵션들
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                onPhotoLibraryTap();
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.only(top:33),
                child: const Text(
                  '프로필 사진 설정',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.black900,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                onDeleteTap();
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.only(top:28),
                child: const Text(
                  '삭제',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.black500,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),
          // 하단 여백
          const SizedBox(height: 39),
        ],
      ),
    );
  }
} 