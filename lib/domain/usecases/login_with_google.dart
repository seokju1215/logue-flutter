import 'package:flutter/material.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logue/data/repositories/agreement_repository.dart';

class LoginWithGoogle {
  final SupabaseClient client;

  LoginWithGoogle(this.client);

  Future<void> call(BuildContext context) async {
    try {
      final redirectUri = 'dev.seokju.logue://login-callback';
      final supabaseUrl = client.supabaseUrl;
      final authUrl = Uri.parse(
        '$supabaseUrl/auth/v1/authorize'
            '?provider=google'
            '&redirect_to=$redirectUri'
            '&flow_type=pkce'
            '&response_type=code',
      ).toString();

      final result = await FlutterWebAuth2.authenticate(
        url: authUrl,
        callbackUrlScheme: 'dev.seokju.logue',
      );

      final uri = Uri.parse(result);

      Map<String, String> fragmentParams = {};
      if (uri.fragment.isNotEmpty) {
        fragmentParams = Uri.splitQueryString(uri.fragment);
      }

      final code = uri.queryParameters['code'] ?? fragmentParams['code'];

      if (code != null) {
        await client.auth.exchangeCodeForSession(code);
      }

      final user = client.auth.currentUser;

      if (user != null) {
        // 약관 동의 여부 확인
        final hasAgreed = await AgreementRepository().hasAgreedTerms(user.id);
        if (!hasAgreed) {
          if (context.mounted) {
            Navigator.pushReplacementNamed(context, '/terms');
          }
          return;
        }

        // 책 3권 선택 여부 확인
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
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인 실패')),
        );
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