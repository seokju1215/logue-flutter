import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:my_logue/presentation/screens/signup/login_screen.dart';

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

      // 정지 회원 확인
      final user = client.auth.currentUser;
      if (user != null) {
        final profile = await client
            .from('profiles')
            .select('is_suspended')
            .eq('id', user.id)
            .maybeSingle();

        if (profile != null && profile.isNotEmpty) {
          final isSuspended = profile['is_suspended'] as bool? ?? false;
          if (isSuspended) {
            // 정지 회원이면 로그아웃하고 로그인 화면으로 이동
            await client.auth.signOut();
            if (!context.mounted) return;
            Navigator.of(context).popUntil((route) => route.isFirst);
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => const LoginScreen(suspended: true),
              ),
            );
            return;
          }
        }
      }

      // 네비게이션 스택 완전 초기화 (popUntil 후 pushNamedAndRemoveUntil)
      Navigator.of(context).popUntil((route) => route.isFirst);
      Navigator.pushNamedAndRemoveUntil(context, '/splash', (route) => false);
    } catch (e) {
      // 사용자가 인증 창을 닫은 경우는 조용히 무시
    }
  }
}