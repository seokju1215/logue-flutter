import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:my_logue/presentation/screens/signup/login_screen.dart';

class LoginWithApple {
  final SupabaseClient client;

  LoginWithApple(this.client);

  Future<void> call(BuildContext context) async {
  try {
    debugPrint('🔐 Apple 로그인 시작');

    await client.auth.signOut();
    debugPrint('🔐 기존 세션 로그아웃 완료');

    final supabaseUrl = dotenv.env['SUPABASE_URL']!;
    final redirectTo = Uri.encodeComponent('dev.seokju.logue://login-callback');

    final authUrl =
        '$supabaseUrl/auth/v1/authorize?provider=apple&redirect_to=$redirectTo';

    debugPrint('🔐 Apple 로그인 URL: $authUrl');

    final result = await FlutterWebAuth2.authenticate(
      url: authUrl,
      callbackUrlScheme: 'dev.seokju.logue',
    );

    debugPrint('🔐 Apple 로그인 결과: $result');

    final uri = Uri.parse(result);
         // Apple 로그인은 fragment에 access_token을 반환
     final fragment = uri.fragment;
     if (fragment.isEmpty) {
       throw Exception('OAuth 응답에 토큰 정보가 없습니다.');
     }
 
     final params = Uri.splitQueryString(fragment);
     final accessToken = params['access_token'];
     final refreshToken = params['refresh_token'];
 
     if (accessToken == null || refreshToken == null) {
       throw Exception('토큰이 누락되었습니다.');
     }
 
     // refresh_token으로 세션 설정
     await client.auth.setSession(refreshToken);

    final session = client.auth.currentSession;
    if (session == null) {
      throw Exception('세션 생성 실패');
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
          debugPrint('🚫 Apple 로그인 - 정지 회원 확인됨: ${user.id}');
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

    Navigator.of(context).popUntil((route) => route.isFirst);
    Navigator.pushNamedAndRemoveUntil(context, '/splash', (route) => false);
  } catch (e) {
    debugPrint('❌ Apple 로그인 실패: $e');
  }
}
}