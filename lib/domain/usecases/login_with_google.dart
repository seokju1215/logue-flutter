import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginWithGoogle {
  final SupabaseClient client;

  LoginWithGoogle(this.client);

  Future<bool> call() async {
    try {
      final redirectUri = 'dev.seokju.logue://login-callback';

      final supabaseUrl = Supabase.instance.client.supabaseUrl;
      final authUrl = Uri.parse(
          '$supabaseUrl/auth/v1/authorize'
              '?provider=google'
              '&redirect_to=$redirectUri'
              '&flow_type=pkce'
              '&response_type=code'
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
      final accessToken = fragmentParams['access_token'];

      if (code != null) {
        await client.auth.exchangeCodeForSession(code);
        return true;
      } else if (accessToken != null) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }
}