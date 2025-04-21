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

    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('로그인 중 오류 발생: $e')),
        );
      }
    }
  }
}