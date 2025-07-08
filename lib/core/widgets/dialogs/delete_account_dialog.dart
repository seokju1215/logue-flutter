import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:my_logue/core/themes/app_colors.dart';

class DeleteAccountDialog extends StatelessWidget {
  final VoidCallback onConfirm;

  const DeleteAccountDialog({super.key, required this.onConfirm});

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
              onTap: () {},
              child: Stack(
                children: [
                  Container(
                    width: 300,
                    padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 25),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Material(
                          color: Colors.transparent,
                          child: Text(
                            '계정 탈퇴',
                            style: TextStyle(fontSize: 20, color: AppColors.black900),
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Material(
                          color: Colors.transparent,
                          child: Text(
                            '계정 탈퇴 시 모든 기록이 삭제되며,\n삭제된 정보는 복구가 불가해요.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: AppColors.black500),
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: onConfirm,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.red500,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(44),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('계정 탈퇴', style: TextStyle(fontSize: 16)),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('취소', style: TextStyle(fontSize: 14)),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.close, size: 24, color: AppColors.black300),
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