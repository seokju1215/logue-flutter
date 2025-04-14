import 'package:flutter/material.dart';
import 'package:logue/domain/usecases/login_with_google.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("🧪 로그인 화면입니다!"), // 테스트용 텍스트
            ElevatedButton(
              onPressed: () => _login(context),
              child: const Text("Google로 로그인"),
            ),
          ],
        ),
      ),
    );
  }
}