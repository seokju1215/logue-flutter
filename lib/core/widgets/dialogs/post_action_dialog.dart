// PostActionDialog.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:my_logue/core/themes/app_colors.dart';

class PostActionDialog extends StatelessWidget {
  const PostActionDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Stack(
        children: [
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(color: Colors.black.withOpacity(0.3)),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
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
                  // 공유
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context, 'share');
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.only(top: 33),
                      child: const Text(
                        '공유',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.black900,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                  // 후기 수정
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context, 'edit');
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.only(top: 28),
                      child: const Text(
                        '후기 수정',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.black900,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                  // 보관함으로 이동
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context, 'archive');
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.only(top: 28),
                      child: const Text(
                        '보관함으로 이동',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.black900,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                  // 삭제
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context, 'delete');
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.only(top: 28),
                      child: const Text(
                        '삭제',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.red500,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                  // 하단 여백
                  const SizedBox(height: 39),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}