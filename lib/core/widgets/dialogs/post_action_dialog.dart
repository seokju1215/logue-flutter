import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:logue/core/themes/app_colors.dart';

class PostActionDialog extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const PostActionDialog({
    super.key,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // ✅ 배경 터치 시 닫기
      onTap: () => Navigator.pop(context),
      child: Stack(
        children: [
          // ✅ 배경 블러 + 어둡게
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(color: Colors.black.withOpacity(0.3)),
            ),
          ),
          // ✅ 다이얼로그 본문
          Center(
            child: GestureDetector(
              // ✅ 다이얼로그 본문 클릭은 이벤트 무시
              onTap: () {},
              child: Stack(
                children: [
                  Container(
                    width: 300,
                    padding: const EdgeInsets.symmetric(
                        vertical: 25, horizontal: 25),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 10),
                        const Text(
                          '책 수정',
                          style: TextStyle(
                              fontSize: 20, color: AppColors.black900),
                        ),
                        const SizedBox(height: 7),
                        const Text(
                          '후기 내용을 수정하거나 또는 \n프로필에서 책을 삭제할 수 있어요.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 12, color: AppColors.black500),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop(); // ✅ 다이얼로그 닫기
                            onEdit(); // ✅ 다이얼로그 닫은 뒤 콜백 실행
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.black900,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(5),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 72, vertical: 8),
                            elevation: 0,
                          ),
                          child: const Text('내용 수정',
                              style: TextStyle(fontSize: 16)),
                        ),
                        TextButton(
                          onPressed: () {
                            onDelete(); // ✅ 콜백 실행
                          },
                          child: const Text('삭제',
                              style: TextStyle(
                                  color: AppColors.red500, fontSize: 14)),
                        ),
                      ],
                    ),
                  ),
                  // ✅ 닫기 버튼 (오른쪽 위)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.close,
                          size: 26, color: AppColors.black900),
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
