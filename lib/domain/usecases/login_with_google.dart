import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logue/data/repositories/agreement_repository.dart';

class LoginWithGoogle {
  final SupabaseClient client;

  LoginWithGoogle(this.client);

  Future<void> call(BuildContext context) async {
    try {
      // ✅ 기존 세션 무효화 (예전 세션이 꼬인 경우 방지)
      await client.auth.signOut();

      // ✅ 로그인 시도
      await client.auth.signInWithOAuth(
        Provider.google,
        redirectTo: 'dev.seokju.logue://login-callback',
      );

      // ✅ onAuthStateChange로 로그인 후 처리
      Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
        final event = data.event;
        final session = data.session;

        if (event == AuthChangeEvent.signedIn && session != null) {
          final user = session.user;

          final hasAgreed = await AgreementRepository().hasAgreedTerms(user.id);
          if (!hasAgreed) {
            if (context.mounted) {
              Navigator.pushReplacementNamed(context, '/terms');
            }
            return;
          }

          final books = await client
              .from('user_books')
              .select('id')
              .eq('user_id', user.id);

          if (context.mounted) {
            if (books.length < 3) {
              Navigator.pushReplacementNamed(context, '/select-3books');
            } else {
              Navigator.pushReplacementNamed(context, '/home');
            }
          }
        }
      });
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('로그인 중 오류 발생: $e')),
        );
      }
    }
  }
}