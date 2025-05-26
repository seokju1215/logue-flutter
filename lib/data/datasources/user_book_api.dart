import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart'; // debugPrint를 위해 필요

class UserBookApi {
  final SupabaseClient client;

  UserBookApi(this.client);

  Future<List<Map<String, dynamic>>> fetchBooks(String userId) async {
    debugPrint("📡 fetchBooks 호출됨, userId: $userId");

    try {
      final response = await client
          .from('user_books')
          .select('*, profiles!fk_user_profile(username, avatar_url)')
          .eq('user_id', userId)
          .order('order_index', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e, stack) {
      debugPrint("❌ Supabase 쿼리 실패: $e");
      debugPrint("🔍 스택 트레이스: $stack");
      return [];
    }
  }

  Future<void> deleteBook(String bookId) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) throw Exception('로그인된 사용자가 없습니다.');

    try {
      final response = await client
          .from('user_books')
          .delete()
          .eq('id', bookId)
          .eq('user_id', userId); // 본인만 삭제 가능

      if (response != null && response.error != null) {
        throw Exception('삭제 실패: ${response.error!.message}');
      }

      debugPrint("🗑️ 책 삭제 성공: $bookId");
    } catch (e, stack) {
      debugPrint("❌ 책 삭제 중 오류: $e");
      debugPrint("🔍 스택 트레이스: $stack");
      rethrow;
    }
  }
}