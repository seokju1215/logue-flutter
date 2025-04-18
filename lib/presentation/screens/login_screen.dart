import 'package:flutter/material.dart';
import 'package:logue/domain/usecases/login_with_google.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:logue/core/themes/app_colors.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  void _login(BuildContext context) async {
    final loginUseCase = LoginWithGoogle(Supabase.instance.client);

    try {
      final success = await loginUseCase();
      if (success && context.mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/home',
              (route) => false,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('로그인 실패: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 로고: 화면의 높이 1/2 지점에 위치
          Align(
            alignment: Alignment(0, 0.0), // y = -0.5 (화면 세로의 1/2 위치)
            child: SvgPicture.asset(
              'assets/logue_logo_with_text.svg', // SVG 파일 경로
              height: 94,
            ),
          ),
          // 로그인 버튼: 화면의 하단 1/5 지점에 위치
          Align(
            alignment: Alignment(0, 0.7), // y = 0.8 (화면 하단에서 1/5 위치)
            child: Container(
              width: 350,
              child: OutlinedButton.icon(
                onPressed: () => _login(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.black900, // 텍스트 색상
                  side: BorderSide(color: AppColors.black500, width: 1), // 테두리
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5),
                  ),
                  padding: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                ),
                icon: Image.asset(
                  'assets/google_logo.svg.png',
                  height: 24,
                ),
                label: Text(
                  "Sign in with Google",
                  style: TextStyle(
                    color: AppColors.black900,
                  ),
                ),
              )
            ),
          ),
        ],
      ),
    );
  }
}