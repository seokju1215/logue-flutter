import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:my_logue/core/themes/app_colors.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:app_settings/app_settings.dart';

class ContactPermissionDialog extends StatelessWidget {
  final VoidCallback onConfirm;

  const ContactPermissionDialog({super.key, required this.onConfirm});

  Future<void> _openSettings() async {
    try {
      // 먼저 app_settings 패키지 사용
      await AppSettings.openAppSettings();
    } catch (e) {
      // fallback: permission_handler 사용
      try {
        await openAppSettings();
      } catch (e2) {
        debugPrint('❌ 설정창 열기 실패: $e2');
      }
    }
  }

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
                    padding: const EdgeInsets.symmetric(vertical: 27, horizontal: 25),
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
                            '연락처 접근 권한',
                            style: TextStyle(fontSize: 18, color: AppColors.black900, height: 1.222),
                          ),
                        ),
                        const SizedBox(height: 11),
                        const Material(
                          color: Colors.transparent,
                          child: Text(
                            '친구를 찾기 위해 연락처 접근 권한\n허용이 필요해요.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: AppColors.black500, height: 1.25),
                          ),
                        ),
                        const SizedBox(height: 11),
                        ElevatedButton(
                          onPressed: () {
                            onConfirm(); // 원래 콜백 호출
                            _openSettings(); // 설정창 열기
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.black900,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(44),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('허용', style: TextStyle(fontSize: 16)),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.close, size: 26, color: AppColors.black900),
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