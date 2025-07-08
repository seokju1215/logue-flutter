import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class LoginWithGoogle {
  final SupabaseClient client;

  LoginWithGoogle(this.client);

  Future<void> call(BuildContext context) async {
    try {
      await client.auth.signOut();

      final supabaseUrl = dotenv.env['SUPABASE_URL']!;
      final redirectTo = Uri.encodeComponent('dev.seokju.logue://login-callback');

      final authUrl =
          '$supabaseUrl/auth/v1/authorize?provider=google&redirect_to=$redirectTo';

      final result = await FlutterWebAuth2.authenticate(
        url: authUrl,
        callbackUrlScheme: 'dev.seokju.logue',
      );

      final uri = Uri.parse(result);

      // Fragment 파싱
      final fragment = uri.fragment;
      if (fragment.isEmpty) {
        throw Exception('OAuth 응답에 토큰 정보가 없습니다.');
      }

      final params = Uri.splitQueryString(fragment);

      final refreshToken = params['refresh_token'];

      if (refreshToken == null) {
        throw Exception('refresh_token이 누락되었습니다.');
      }

      // refresh_token으로 세션 설정
      await client.auth.setSession(refreshToken);

      // 세션 확인
      final session = client.auth.currentSession;
      if (session == null) {
        throw Exception('로그인에 실패했습니다.');
      }

      // 네비게이션 스택 완전 초기화 (popUntil 후 pushNamedAndRemoveUntil)
      Navigator.of(context).popUntil((route) => route.isFirst);
      Navigator.pushNamedAndRemoveUntil(context, '/splash', (route) => false);
    } catch (e) {
      // 사용자가 인증 창을 닫은 경우는 조용히 무시
    }
  }
}