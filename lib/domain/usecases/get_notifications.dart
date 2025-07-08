import 'package:supabase_flutter/supabase_flutter.dart';

class GetNotifications {
  final SupabaseClient client;

  GetNotifications(this.client);

  Future<List<Map<String, dynamic>>> call(String userId) async {
    final response = await client
        .from('notifications')
        .select('id, type, book_id, created_at, is_read, sender_id, sender:profiles!sender_id(id, username, avatar_url)')
        .eq('recipient_id', userId)
        .order('created_at', ascending: false);

    if (response is List) {
      return response.map((e) => e as Map<String, dynamic>).toList();
    } else {
      throw Exception('알림 데이터를 불러오는데 실패했습니다');
    }
  }
}