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
      await loginUseCase();
      // 로그인 성공 → 홈 이동
      if (context.mounted) {
        Navigator.pushReplacementNamed(context, '/home');
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
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Center(
                child: SvgPicture.asset(
                  'assets/logue_logo_with_text.svg', // SVG 파일 경로
                  height: 94,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 150.0), // 버튼 아래에 간격 추가
              child: OutlinedButton(
                onPressed: () => _login(context),
                style: OutlinedButton.styleFrom(
                  primary: Colors.black, // 텍스트 색상
                  side: BorderSide(color: AppColors.black500, width: 1), // 테두리 색상
                  padding: EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5), // border-radius 설정
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Google로 3초 만에 로그인하기"),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}