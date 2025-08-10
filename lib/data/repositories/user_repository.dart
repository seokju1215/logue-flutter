import 'package:supabase_flutter/supabase_flutter.dart';

class UserRepository {
  final SupabaseClient client;

  UserRepository(this.client);

  Future<List<Map<String, dynamic>>> getUsersWithSameBooks() async {
    try {
      final userId = client.auth.currentUser?.id;
      if (userId == null) return [];

      final response = await client
          .rpc('get_users_with_same_books', params: {
            'target_user_id': userId,
          });

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ 인생책이 겹치는 사람 조회 실패: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getRecentActiveUsers() async {
    try {
      final userId = client.auth.currentUser?.id;
      if (userId == null) return [];

      final response = await client
          .rpc('get_recent_active_users');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ 최근 활성 유저 조회 실패: $e');
      return [];
    }
  }
}