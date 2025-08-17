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

  /// 여러 책의 is_archived와 order_index를 일괄 업데이트
  Future<void> updateBooksBatch(List<Map<String, dynamic>> books) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) throw Exception('로그인된 사용자가 없습니다.');

    debugPrint("🔍 updateBooksBatch 시작: ${books.length}개 책 업데이트");

    try {
      // 각 책에 대해 개별적으로 업데이트
      for (int i = 0; i < books.length; i++) {
        final book = books[i];
        final userBookId = book['id'] as String;
        final isArchived = book['is_archived'] as bool;
        final orderIndex = book['order_index'] as int?;

        debugPrint("📦 [$i] 책 업데이트: ID=$userBookId, is_archived=$isArchived, order_index=$orderIndex");

        if (isArchived) {
          // 보관함으로 이동: order_index 제거 (archived_order_index는 건드리지 않음)
          debugPrint("📦 [$i] 보관함으로 이동: order_index 제거");
          await client
              .from('user_books')
              .update({
                'is_archived': true,
                'order_index': null,
              })
              .eq('id', userBookId)
              .eq('user_id', userId);
          debugPrint("📦 [$i] 보관함 이동 완료");
        } else {
          // 프로필로 이동: order_index 설정 (archived_order_index는 건드리지 않음)
          if (orderIndex != null) {
            debugPrint("📦 [$i] 프로필로 이동: order_index=$orderIndex 설정");
            await client
                .from('user_books')
                .update({
                  'is_archived': false,
                  'order_index': orderIndex,
                })
                .eq('id', userBookId)
                .eq('user_id', userId);
            debugPrint("📦 [$i] 프로필 이동 완료");
          } else {
            debugPrint("📦 [$i] order_index가 null이므로 업데이트 건너뜀");
          }
        }
      }

      debugPrint("✅ updateBooksBatch 완료");
    } catch (e, stack) {
      debugPrint("❌ updateBooksBatch 중 오류: $e");
      debugPrint("🔍 스택 트레이스: $stack");
      rethrow;
    }
  }

  /// 보관함에 책을 추가할 때 archived_order_index 관리
  Future<void> addBookToArchive(String bookId) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) throw Exception('로그인된 사용자가 없습니다.');

    debugPrint("🔍 addBookToArchive 시작: bookId=$bookId, userId=$userId");

    try {
      // 1. 현재 보관함에 있는 책들의 archived_order_index를 1씩 증가
      final currentArchiveBooks = await client
          .from('user_books')
          .select('id, archived_order_index')
          .eq('user_id', userId)
          .order('archived_order_index', ascending: true);

      debugPrint("📦 현재 보관함 책 개수: ${currentArchiveBooks.length}");

      // 2. 각 보관함 책의 archived_order_index를 1씩 증가
      for (final book in currentArchiveBooks) {
        final currentOrderIndex = book['archived_order_index'] as int? ?? 0;
        debugPrint("📦 보관함 책 ${book['id']}의 archived_order_index를 ${currentOrderIndex}에서 ${currentOrderIndex + 1}로 변경");
        await client
            .from('user_books')
            .update({'archived_order_index': currentOrderIndex + 1})
            .eq('id', book['id']);
      }

      // 3. 새로 추가된 책을 archived_order_index = 0으로 설정
      debugPrint("📦 책 $bookId를 보관함에 추가 (archived_order_index=0)");
      await client
          .from('user_books')
          .update({
            'archived_order_index': 0,
          })
          .eq('id', bookId)
          .eq('user_id', userId);

      debugPrint("✅ 책 보관함 추가 성공: $bookId");
    } catch (e, stack) {
      debugPrint("❌ 책 보관함 추가 중 오류: $e");
      debugPrint("🔍 스택 트레이스: $stack");
      rethrow;
    }
  }

  /// 팔로워들에게 책 추가 알림 보내기 (send-notification-v2 edge function 사용)
  Future<void> notifyFollowersAboutNewBook(String userId, String? userBookId) async {
    debugPrint("🔍 notifyFollowersAboutNewBook 시작: userId=$userId, userBookId=$userBookId");

    try {
      // 1. 해당 사용자를 팔로우하는 사용자들 가져오기
      debugPrint("🔍 팔로워 조회 시작");
      final followers = await client
          .from('follows')
          .select('follower_id')
          .eq('following_id', userId);

      if (followers.isEmpty) {
        debugPrint("📦 팔로워가 없음");
        return;
      }

      debugPrint("📦 팔로워 수: ${followers.length}");
      debugPrint("📦 팔로워 목록: ${followers.map((f) => f['follower_id']).toList()}");

      // 2. 각 팔로워에게 send-notification-v2 edge function으로 알림 보내기
      for (int i = 0; i < followers.length; i++) {
        final follower = followers[i];
        final followerId = follower['follower_id'] as String;
        
        debugPrint("📦 [$i] 팔로워 $followerId에게 알림 전송 시도");
        
        try {
          final requestBody = {
            'recipient_id': followerId,
            'sender_id': userId,
            'type': 'post',
            'book_id': userBookId, // user_books 테이블의 ID
          };
          debugPrint("📦 [$i] Edge function 요청: $requestBody");
          
          final response = await client.functions.invoke('send-notification-v2', body: requestBody);

          if (response.status == 200) {
            final responseData = response.data as Map<String, dynamic>?;
            debugPrint("📦 [$i] 팔로워 $followerId에게 알림 전송 완료: status=${response.status}, data=$responseData");
          } else {
            debugPrint("❌ [$i] 팔로워 $followerId에게 알림 전송 실패: status=${response.status}, data=${response.data}");
          }
        } catch (e) {
          debugPrint("❌ [$i] 팔로워 $followerId에게 알림 전송 중 오류: $e");
        }
      }

      debugPrint("✅ 팔로워 알림 전송 완료");
    } catch (e, stack) {
      debugPrint("❌ 팔로워 알림 전송 중 오류: $e");
      debugPrint("🔍 스택 트레이스: $stack");
      rethrow;
    }
  }
}