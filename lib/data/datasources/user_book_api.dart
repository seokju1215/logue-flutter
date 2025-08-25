import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart'; // debugPrint

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
          .eq('is_archived', false)
          .order('order_index', ascending: true);

      final result = response.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)).toList();
      if (result.isNotEmpty) {
        debugPrint('📦 fetchBooks 결과 예시: ${jsonEncode(result.first)}');
      }
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
      final result = response.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)).toList();
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
          .eq('is_archived', true)
          .order('archived_order_index', ascending: true);

      final result = response.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)).toList();
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
      await client
          .from('user_books')
          .update({'is_archived': true})
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

      await client
          .from('user_books')
          .update({'is_archived': false, 'order_index': newOrderIndex})
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
      final currentProfileBooks = await client
          .from('user_books')
          .select('id, order_index')
          .eq('user_id', userId)
          .eq('is_archived', false)
          .order('order_index', ascending: true);

      for (final book in currentProfileBooks) {
        final currentOrderIndex = book['order_index'] as int;
        await client.from('user_books').update({'order_index': currentOrderIndex + 1}).eq('id', book['id']);
      }

      await client
          .from('user_books')
          .update({'is_archived': false, 'order_index': 0})
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
      await client.from('user_books').delete().eq('id', bookId).eq('user_id', userId);
      debugPrint("🗑️ 책 삭제 성공: $bookId");
    } catch (e, stack) {
      debugPrint("❌ 책 삭제 중 오류: $e");
      debugPrint("🔍 스택 트레이스: $stack");
      rethrow;
    }
  }

  /// ✅ RPC: 여러 책의 is_archived / order_index를 "한 번에" 업데이트
  /// Supabase SQL 함수: update_user_books_batch(_items jsonb)
  Future<void> updateBooksBatchRPC(List<Map<String, dynamic>> books) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) throw Exception('로그인된 사용자가 없습니다.');
    if (books.isEmpty) return;

    // RPC에 보낼 최소 키만 추림 (payload는 JSON 직렬화 가능한 값만)
    final payload = books.map((b) => {
      'id': b['id'],
      'is_archived': b['is_archived'],
      'order_index': b['order_index'],
    }).toList();

    try {
      // v2: rpc는 에러 시 예외 throw, 정상이면 data(dynamic)만 반환
      await client.rpc('update_user_books_batch', params: {'_items': payload});
      debugPrint("✅ updateUserBooksBatchRPC 완료 (${payload.length}건)");
    } catch (e, stack) {
      debugPrint("❌ updateUserBooksBatchRPC 오류: $e");
      debugPrint("🔍 스택: $stack");
      rethrow; // 위로 전달
    }
  }

  /// 보관함 순서 일괄 업데이트 (간격 방식만 사용)
  Future<void> updateArchivedOrderBatchRPC(List<Map<String, dynamic>> updates) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) throw Exception('로그인된 사용자가 없습니다.');
    if (updates.isEmpty) return;

    try {
      debugPrint('🚀 보관함 순서 배치 업데이트 시작: ${updates.length}개 책 (간격 방식)');
      
      // 모든 경우에 간격 방식 사용
      final payload = <Map<String, dynamic>>[];
      
      for (int i = 0; i < updates.length; i++) {
        final update = updates[i];
        final id = update['id'];
        
        // prev, next 값 계산 - ArchiveTab에서 전달한 실제 DB 값 사용
        double prev = 0.0;
        double next = 1000.0;
        
        // 이전 책의 실제 archived_order_index 값 사용
        if (update['prev_archived_order_index'] != null) {
          prev = (update['prev_archived_order_index'] as num).toDouble();
        }
        
        // 다음 책의 실제 archived_order_index 값 사용
        if (update['next_archived_order_index'] != null) {
          next = (update['next_archived_order_index'] as num).toDouble();
        }
        
        debugPrint('📚 책 $id: prev=$prev, next=$next');
        
        payload.add({
          'id': id,
          'prev': prev,
          'next': next,
        });
      }
      
      await client.rpc('update_archived_order_index_partial', params: {'_items': payload});
      debugPrint('✅ 간격 방식 업데이트 완료 (${updates.length}건)');
      
    } catch (e, stack) {
      debugPrint('❌ 보관함 순서 배치 업데이트 실패: $e');
      debugPrint('🔍 스택: $stack');
      rethrow;
    }
  }

  /// 보관함에 책을 추가할 때 archived_order_index 관리 (기존 로직 유지)
  Future<void> addBookToArchive(String userBookId) async {
    try {
      // 현재 보관함의 최대 archived_order_index 찾기
      final result = await client
          .from('user_books')
          .select('id, archived_order_index')
          .eq('is_archived', true)
          .order('archived_order_index', ascending: true);

      if (result.isNotEmpty) {
        final book = result.last;
        final currentOrderIndex = (book['archived_order_index'] as num?)?.toDouble() ?? 0.0;
        await client.from('user_books').update({'archived_order_index': currentOrderIndex + 1.0}).eq('id', book['id']);
      }

      // 새로 추가되는 책은 archived_order_index = 0
      await client
          .from('user_books')
          .update({'archived_order_index': 0.0})
          .eq('id', userBookId);
    } catch (e) {
      debugPrint('❌ 보관함에 책 추가 실패: $e');
      rethrow;
    }
  }
}