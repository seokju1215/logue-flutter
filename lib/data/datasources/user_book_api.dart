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
          .select('*') // 명시적으로 * 선택
          .eq('user_id', userId);

      return List<Map<String, dynamic>>.from(response);
    } catch (e, stack) {
      debugPrint("❌ Supabase 쿼리 실패: $e");
      debugPrint("🔍 스택 트레이스: $stack");
      return [];
    }
  }
}