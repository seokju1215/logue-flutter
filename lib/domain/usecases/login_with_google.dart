import 'package:supabase_flutter/supabase_flutter.dart';

class LoginWithGoogle {
  final SupabaseClient client;

  LoginWithGoogle(this.client);

  Future<bool> call() async {
    return await client.auth.signInWithOAuth(
      Provider.google,
      redirectTo: 'io.supabase.flutter://login-callback',
    );
  }
}