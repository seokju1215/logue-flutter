import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginWithGoogle {
  final SupabaseClient client;

  LoginWithGoogle(this.client);

  Future<void> call(BuildContext context) async {
    try {
      await client.auth.signOut(); // 혹시 이전 세션 꼬였을 경우를 대비

      await client.auth.signInWithOAuth(
        Provider.google,
        redirectTo: 'dev.seokju.logue://login-callback',
      );

      final session = client.auth.currentSession;
      final email = session?.user.email;

      if (email != null) {
        final response = await client.functions.invoke(
          'check_deleted_user',
          body: {'email': email},
        );

        final data = response.data as Map<String, dynamic>;
        if (data['blocked'] == true) {
          await client.auth.signOut(); // 차단된 유저는 다시 로그아웃
          if (context.mounted) {
            Navigator.pushReplacementNamed(context, '/login_blocked'); // 차단 안내 화면으로 이동
          }
          return;
        }
      }

      // 통과한 사용자만 splash로 이동
      if (context.mounted) {
        Navigator.pushReplacementNamed(context, '/splash');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('로그인 중 오류 발생: $e')),
        );
      }
    }
  }
}