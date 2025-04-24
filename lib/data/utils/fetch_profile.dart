import 'package:supabase_flutter/supabase_flutter.dart';

Future<Map<String, dynamic>?> fetchCurrentUserProfile() async {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;

  if (user == null) return null;

  final data = await client
      .from('profiles')
      .select()
      .eq('id', user.id)
      .maybeSingle();

  return data;
}