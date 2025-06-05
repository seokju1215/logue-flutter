import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:logue/core/themes/app_colors.dart';
import 'package:logue/presentation/screens/post/my_post_screen.dart';

import '../../../presentation/screens/main_navigation_screen.dart';

class BookLimitDialog extends StatelessWidget {
  const BookLimitDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Stack(
        children: [
          // 🔹 배경 블러 + 어둡게
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(color: Colors.black.withOpacity(0.3)),
            ),
          ),
          // 🔹 다이얼로그 내용
          Center(
            child: GestureDetector(
              onTap: () {},
              child: Stack(
                children: [
                  Container(
                    width: 300,
                    padding: const EdgeInsets.symmetric(
                        vertical: 25, horizontal: 25),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          '안내',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppColors.black900,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          '책은 최대 9권까지 추가가 가능해요.\n기존에 추가한 책을 삭제해주세요.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.black500,
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () async {
                            Navigator.pop(context); // 다이얼로그 닫기
                            Navigator.pop(context);
                            await Navigator.of(context).pushNamedAndRemoveUntil(
                              '/main',
                                  (_) => false,
                              arguments: {
                                'initialTabIndex': 1, // ✅ 프로필 탭
                              },
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.black900,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(40),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            elevation: 0,
                          ),
                          child: const Text('책 삭제하러 가기'),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            '취소',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.black500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 🔹 닫기 버튼
                  Positioned(
                    top: 10,
                    right: 10,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.close,
                          size: 20, color: AppColors.black500),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}