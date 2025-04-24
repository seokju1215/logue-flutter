// lib/core/widgets/dialogs/logout_or_delete_dialog.dart
import 'package:flutter/material.dart';
import 'package:logue/core/themes/app_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> showLogoutOrDeleteDialog(BuildContext context) async {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return Theme(
        data: Theme.of(context).copyWith(
          useMaterial3: false,
          dialogBackgroundColor: AppColors.white500,
        ),
        child: Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(30),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 34),
                    const Text('로그아웃', style: TextStyle(fontSize: 20, color: AppColors.black900)),
                    const SizedBox(height: 17),
                    const Text('로그아웃 하시겠어요?', style: TextStyle(fontSize: 12, color: AppColors.black500)),
                    const SizedBox(height: 17),
                    OutlinedButton(
                      onPressed: () async {
                        await Supabase.instance.client.auth.signOut();
                        if (context.mounted) {
                          Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 36),
                        backgroundColor: AppColors.white500,
                        foregroundColor: AppColors.black900,
                        side: const BorderSide(color: AppColors.black300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                      child: const Text('로그아웃'),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        showConfirmDeleteDialog(context);
                      },
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 36),
                        backgroundColor: AppColors.red500,
                        foregroundColor: AppColors.white500,
                        side: const BorderSide(color: AppColors.red500),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                      child: const Text('계정탈퇴'),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, size: 24),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> showConfirmDeleteDialog(BuildContext context) async {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return Theme(
        data: Theme.of(context).copyWith(
          useMaterial3: false,
          dialogBackgroundColor: AppColors.white500,
        ),
        child: Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 10),
                    const Text('계정 탈퇴', style: TextStyle(fontSize: 20, color: AppColors.black900)),
                    const SizedBox(height: 12),
                    const Text(
                      '계정 탈퇴 이후 30일 동안 해당\n구글 계정으로 회원가입이 불가해요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: AppColors.black500),
                    ),
                    const SizedBox(height: 20),
                    OutlinedButton(
                      onPressed: () async {
                        final user = Supabase.instance.client.auth.currentUser;
                        final userId = user?.id;
                        final email = user?.email;
                        if (userId == null) return;

                        final res = await Supabase.instance.client.functions.invoke('delete_account', body: {
                          'userId': userId,
                          'email': email,
                        });

                        if (res.status == 200 && res.data['success'] == true) {
                          if (context.mounted) {
                            Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
                          }
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('계정 삭제에 실패했습니다.')),
                          );
                          Navigator.pop(context);
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 36),
                        backgroundColor: AppColors.red500,
                        foregroundColor: AppColors.white500,
                        side: const BorderSide(color: AppColors.red500),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                      child: const Text('계정탈퇴'),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 36),
                        backgroundColor: AppColors.white500,
                        foregroundColor: AppColors.black900,
                        side: const BorderSide(color: AppColors.black300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                      child: const Text('취소'),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, size: 24),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}