import 'dart:convert';
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
          .select('*, books(isbn,image), profiles!fk_user_profile(username, avatar_url)')
          .eq('user_id', userId)
          .eq('is_archived', false) // 보관되지 않은 책만 가져오기
          .order('order_index', ascending: true);

      final result = response.map<Map<String, dynamic>>((e) {
        return Map<String, dynamic>.from(e);
      }).toList();

      debugPrint('📦 fetchBooks 결과 예시: ${jsonEncode(result.first)}');

      return result;
    } catch (e, stack) {
      debugPrint("❌ Supabase 쿼리 실패: $e");
      debugPrint("🔍 스택 트레이스: $stack");
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> searchBooksFromDB(String query) async {
    debugPrint("📡 searchBooksFromDB 호출됨, query: $query");

    try {
      final response = await client
          .from('books')
          .select('*')
          .or('title.ilike.%$query%,author.ilike.%$query%')
          .limit(20);

      final result = response.map<Map<String, dynamic>>((e) {
        return Map<String, dynamic>.from(e);
      }).toList();

      debugPrint('📦 searchBooksFromDB 결과 개수: ${result.length}');

      return result;
    } catch (e, stack) {
      debugPrint("❌ DB 책 검색 실패: $e");
      debugPrint("🔍 스택 트레이스: $stack");
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchArchivedBooks(String userId) async {
    debugPrint("📡 fetchArchivedBooks 호출됨, userId: $userId");

    try {
      final response = await client
          .from('user_books')
          .select('*, books(isbn,image), profiles!fk_user_profile(username, avatar_url)')
          .eq('user_id', userId)
          .eq('is_archived', true) // 보관된 책만 가져오기
          .order('archived_order_index', ascending: true);

      final result = response.map<Map<String, dynamic>>((e) {
        return Map<String, dynamic>.from(e);
      }).toList();

      debugPrint('📦 fetchArchivedBooks 결과 개수: ${result.length}');

      return result;
    } catch (e, stack) {
      debugPrint("❌ Supabase 쿼리 실패: $e");
      debugPrint("🔍 스택 트레이스: $stack");
      return [];
    }
  }

  Future<void> archiveBook(String bookId) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) throw Exception('로그인된 사용자가 없습니다.');

    try {

      // 책을 보관함으로 이동
      await client
          .from('user_books')
          .update({
            'is_archived': true,
          })
          .eq('id', bookId)
          .eq('user_id', userId);

      debugPrint("📦 책 보관 성공: $bookId");
    } catch (e, stack) {
      debugPrint("❌ 책 보관 중 오류: $e");
      debugPrint("🔍 스택 트레이스: $stack");
      rethrow;
    }
  }

  Future<void> unarchiveBook(String bookId) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) throw Exception('로그인된 사용자가 없습니다.');

    try {
      // 보관되지 않은 책의 최대 order_index 가져오기
      final maxOrderResult = await client
          .from('user_books')
          .select('order_index')
          .eq('user_id', userId)
          .eq('is_archived', false)
          .order('order_index', ascending: false)
          .limit(1);

      int newOrderIndex = 0;
      if (maxOrderResult.isNotEmpty) {
        newOrderIndex = (maxOrderResult.first['order_index'] as int?) ?? 0;
        newOrderIndex++;
      }

      // 책을 보관함에서 복원
      await client
          .from('user_books')
          .update({
            'is_archived': false,
            'order_index': newOrderIndex,
          })
          .eq('id', bookId)
          .eq('user_id', userId);

      debugPrint("📦 책 보관 해제 성공: $bookId");
    } catch (e, stack) {
      debugPrint("❌ 책 보관 해제 중 오류: $e");
      debugPrint("🔍 스택 트레이스: $stack");
      rethrow;
    }
  }

  Future<void> moveToProfile(String bookId) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) throw Exception('로그인된 사용자가 없습니다.');

    debugPrint("🔍 moveToProfile 시작: bookId=$bookId, userId=$userId");

    try {
      // 1. 현재 프로필 포스트들을 가져와서 order_index를 1씩 증가
      final currentProfileBooks = await client
          .from('user_books')
          .select('id, order_index')
          .eq('user_id', userId)
          .eq('is_archived', false)
          .order('order_index', ascending: true);

      debugPrint("📦 현재 프로필 포스트 개수: ${currentProfileBooks.length}");

      // 2. 각 프로필 포스트의 order_index를 1씩 증가
      for (final book in currentProfileBooks) {
        final currentOrderIndex = book['order_index'] as int;
        debugPrint("📦 포스트 ${book['id']}의 order_index를 ${currentOrderIndex}에서 ${currentOrderIndex + 1}로 변경");
        await client
            .from('user_books')
            .update({'order_index': currentOrderIndex + 1})
            .eq('id', book['id']);
      }

      // 3. 해당 책을 프로필로 이동 (is_archived = false, order_index = 0)
      debugPrint("📦 책 $bookId를 프로필로 이동 (is_archived=false, order_index=0)");
      await client
          .from('user_books')
          .update({
            'is_archived': false,
            'order_index': 0,
          })
          .eq('id', bookId)
          .eq('user_id', userId);

      debugPrint("✅ 책 프로필 이동 성공: $bookId");
    } catch (e, stack) {
      debugPrint("❌ 책 프로필 이동 중 오류: $e");
      debugPrint("🔍 스택 트레이스: $stack");
      rethrow;
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

      debugPrint("🗑️ 책 삭제 성공: $bookId");
    } catch (e, stack) {
      debugPrint("❌ 책 삭제 중 오류: $e");
      debugPrint("🔍 스택 트레이스: $stack");
      rethrow;
    }
  }
}