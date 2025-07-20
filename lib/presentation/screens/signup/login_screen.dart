import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_logue/domain/usecases/login_with_google.dart';
import 'package:my_logue/domain/usecases/login_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:my_logue/core/themes/app_colors.dart';
import 'package:my_logue/core/providers/follow_state_provider.dart';

class LoginScreen extends ConsumerWidget {
  final bool blocked;
  const LoginScreen({super.key, this.blocked = false});

  void _loginWithGoogle(BuildContext context, WidgetRef ref) async {
    // 로그인 시 모든 followStateProvider 무효화
    ref.read(followStateInvalidatorProvider).invalidateAll();
    
    final loginUseCase = LoginWithGoogle(Supabase.instance.client);

    try {
      await loginUseCase(context); // 리턴값 안 받아도 됨
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('로그인 실패: $e')),
      );
    }
  }

  void _loginWithApple(BuildContext context, WidgetRef ref) async {
    // 로그인 시 모든 followStateProvider 무효화
    ref.read(followStateInvalidatorProvider).invalidateAll();
    
    final loginUseCase = LoginWithApple(Supabase.instance.client);

    try {
      await loginUseCase(context); // 리턴값 안 받아도 됨
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('로그인 실패: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Stack(
        children: [
          // 로고: 화면 중앙
          Align(
            alignment: Alignment(0, 0.0),
            child: SvgPicture.asset(
              'assets/logue_logo_with_title.svg',
              height: 64,
            ),
          ),

          // 텍스트 + 로그인 버튼: 화면 아래 70% 지점
          Align(
            alignment: Alignment(0, 0.7),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (blocked) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      "해당 계정은 탈퇴 후 14일이 지나지 않아 가입이 불가합니다.\n14일 후 다시 시도해 주세요.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.black900,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                SizedBox(
                  width: 350,
                  child: OutlinedButton.icon(
                    onPressed: () => _loginWithGoogle(context, ref),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.black900,
                      side: const BorderSide(color: AppColors.black500, width: 1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                    ),
                    icon: Image.asset(
                      'assets/google_logo.svg.png',
                      height: 24,
                    ),
                    label: const Text(
                      "Sign in with Google",
                      style: TextStyle(color: AppColors.black900),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: 350,
                  child: OutlinedButton.icon(
                    onPressed: () => _loginWithApple(context, ref),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.black900,
                      side: const BorderSide(color: AppColors.black500, width: 1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                    ),
                    icon: const Icon(
                      Icons.apple,
                      size: 24,
                      color: AppColors.black900,
                    ),
                    label: const Text(
                      "Sign in with Apple",
                      style: TextStyle(color: AppColors.black900),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}