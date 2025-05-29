import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:logue/core/themes/app_colors.dart';

class PostDeleteDialog extends StatelessWidget {
  final VoidCallback onDelete;

  const PostDeleteDialog({super.key, required this.onDelete});

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
          Center(
            child: GestureDetector(
              onTap: () {}, // 내부 터치 막기
              child: Stack(
                children: [
                  Container(
                    width: 300,
                    padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 25),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 10),
                        const Text(
                          '삭제',
                          style: TextStyle(fontSize: 20, color: AppColors.black900, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        const Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '정말 책을 삭제하시겠어요?\n',
                                style: TextStyle(fontSize: 12, color: AppColors.black500, fontWeight: FontWeight.bold),
                              ),
                              TextSpan(
                                text: '작성한 후기도 같이 삭제돼요.',
                                style: TextStyle(fontSize: 12, color: AppColors.black500),
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: onDelete,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.red500,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                            padding: const EdgeInsets.symmetric(horizontal: 100, vertical: 8),
                            elevation: 0,
                          ),
                          child: const Text('삭제', style: TextStyle(fontSize: 16)),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('취소', style: TextStyle(color: AppColors.black900, fontSize: 14)),
                        ),
                      ],
                    ),
                  ),
                  // X 버튼
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.close, size: 24, color: AppColors.black500),
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