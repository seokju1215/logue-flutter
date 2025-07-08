import 'package:supabase_flutter/supabase_flutter.dart';
class InsertProfileUseCase {
  final SupabaseClient client;

  InsertProfileUseCase(this.client);

  Future<void> call({
    required String id,
    required String username,
    required String name,
    required String job,
    required String bio,
    required String avatarUrl,
  }) async {
    await client.from('profiles').insert({
      'id': id,
      'username': username,
      'name': name,
      'job': job,
      'bio': bio,
      'avatar_url' : avatarUrl
    });
  }
}