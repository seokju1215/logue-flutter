import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BookDataService extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;
  
  List<Map<String, dynamic>> _allBooks = [];
  List<Map<String, dynamic>> _profileBooks = [];
  List<Map<String, dynamic>> _archivedBooks = [];
  
  bool _isLoading = false;
  bool _isUpdating = false;
  
  // Getters
  List<Map<String, dynamic>> get allBooks => _allBooks;
  List<Map<String, dynamic>> get profileBooks => _profileBooks;
  List<Map<String, dynamic>> get archivedBooks => _archivedBooks;
  bool get isLoading => _isLoading;
  bool get isUpdating => _isUpdating;
  
  // 프로필 책 개수 (9개 제한)
  int get profileBookCount => _profileBooks.length;
  bool get isProfileLimitReached => profileBookCount >= 9;
  
  // 보관함 책 개수 (1000개 제한)
  int get archivedBookCount => _archivedBooks.length;
  bool get isArchivedLimitReached => archivedBookCount >= 1000;
  
  /// 모든 책 데이터 로드
  Future<void> loadAllBooks() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    
    _setLoading(true);
    
    try {
      final data = await _client
          .from('user_books')
          .select('id, user_id, order_index, archived_order_index, is_archived, book_id, books(id, image)')
          .eq('user_id', userId);
      
      _allBooks = List<Map<String, dynamic>>.from(data);
      _updateFilteredBooks();
      
      debugPrint('🔍 BookDataService - 로드된 책 개수: ${_allBooks.length}');
    } catch (e) {
      debugPrint('❌ BookDataService - 책 로드 실패: $e');
    } finally {
      _setLoading(false);
    }
  }
  
  /// 프로필과 보관함 책 목록 업데이트
  void _updateFilteredBooks() {
    _profileBooks = _allBooks
        .where((book) => book['is_archived'] == false)
        .toList()
      ..sort((a, b) => (a['order_index'] ?? 0).compareTo(b['order_index'] ?? 0));
    
    _archivedBooks = _allBooks
        .where((book) => book['is_archived'] == true)
        .toList()
      ..sort((a, b) => (a['archived_order_index'] ?? 0).compareTo(b['archived_order_index'] ?? 0));
    
    debugPrint('🔍 BookDataService - 프로필 책: ${_profileBooks.length}권, 보관함 책: ${_archivedBooks.length}권');
  }
  
  /// 프로필 책 순서 변경
  Future<void> updateProfileBookOrder(List<Map<String, dynamic>> newOrder) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    
    _setUpdating(true);
    
    try {
      for (int i = 0; i < newOrder.length; i++) {
        final bookId = newOrder[i]['id'];
        await _client
            .from('user_books')
            .update({'order_index': i})
            .eq('id', bookId);
      }
      
      // 로컬 데이터 업데이트
      _profileBooks = List.from(newOrder);
      _updateAllBooksFromProfile();
      
      debugPrint('✅ BookDataService - 프로필 책 순서 업데이트 완료');
    } catch (e) {
      debugPrint('❌ BookDataService - 프로필 책 순서 업데이트 실패: $e');
    } finally {
      _setUpdating(false);
    }
  }
  
  /// 보관함 책 순서 변경
  Future<void> updateArchivedBookOrder(List<Map<String, dynamic>> newOrder) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    
    _setUpdating(true);
    
    try {
      for (int i = 0; i < newOrder.length; i++) {
        final bookId = newOrder[i]['id'];
        await _client
            .from('user_books')
            .update({'archived_order_index': i.toDouble()})
            .eq('id', bookId);
      }
      
      // 로컬 데이터 업데이트
      _archivedBooks = List.from(newOrder);
      _updateAllBooksFromArchived();
      
      debugPrint('✅ BookDataService - 보관함 책 순서 업데이트 완료');
    } catch (e) {
      debugPrint('❌ BookDataService - 보관함 책 순서 업데이트 실패: $e');
    } finally {
      _setUpdating(false);
    }
  }
  
  /// ArchiveBottomSheet에서 책 상태 변경 (프로필 ↔ 보관함)
  Future<void> updateBooksFromArchiveBottomSheet(List<Map<String, dynamic>> updatedBooks) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    
    _setUpdating(true);
    
    try {
      // 일괄 업데이트
      for (final book in updatedBooks) {
        final bookId = book['id'];
        final isArchived = book['is_archived'] as bool;
        final orderIndex = book['order_index'] as int? ?? 0;
        // archived_order_index 설정
        final archivedOrderIndex = (book['archived_order_index'] as num?)?.toDouble() ?? 0.0;
        final nextArchivedOrderIndex = archivedOrderIndex + 1.0;
        
        await _client
            .from('user_books')
            .update({
              'is_archived': isArchived,
              'order_index': isArchived ? null : orderIndex,
              'archived_order_index': isArchived ? nextArchivedOrderIndex : null,
            })
            .eq('id', bookId);
      }
      
      // 로컬 데이터 새로고침
      await loadAllBooks();
      
      debugPrint('✅ BookDataService - ArchiveBottomSheet 업데이트 완료');
    } catch (e) {
      debugPrint('❌ BookDataService - ArchiveBottomSheet 업데이트 실패: $e');
      rethrow;
    } finally {
      _setUpdating(false);
    }
  }
  
  /// 프로필 책 추가 (보관함 → 프로필)
  Future<bool> addBookToProfile(String userBookId) async {
    if (isProfileLimitReached) {
      debugPrint('⚠️ BookDataService - 프로필 책 한도 도달 (9권)');
      return false;
    }
    
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;
    
    _setUpdating(true);
    
    try {
      // 보관함에서 프로필로 이동
      final nextOrderIndex = _profileBooks.length;
      
      await _client
          .from('user_books')
          .update({
            'is_archived': false,
            'order_index': nextOrderIndex,
            'archived_order_index': null,
          })
          .eq('id', userBookId)
          .eq('user_id', userId);
      
      // 로컬 데이터 새로고침
      await loadAllBooks();
      
      debugPrint('✅ BookDataService - 책을 프로필에 추가 완료: $userBookId');
      return true;
    } catch (e) {
      debugPrint('❌ BookDataService - 책을 프로필에 추가 실패: $e');
      return false;
    } finally {
      _setUpdating(false);
    }
  }
  
  /// 보관함 책 추가 (프로필 → 보관함)
  Future<bool> addBookToArchive(String userBookId) async {
    if (isArchivedLimitReached) {
      debugPrint('⚠️ BookDataService - 보관함 책 한도 도달 (1000권)');
      return false;
    }
    
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;
    
    _setUpdating(true);
    
    try {
      // 프로필에서 보관함으로 이동
      final nextArchivedOrderIndex = _archivedBooks.length;
      
      await _client
          .from('user_books')
          .update({
            'is_archived': true,
            'order_index': null,
            'archived_order_index': nextArchivedOrderIndex,
          })
          .eq('id', userBookId)
          .eq('user_id', userId);
      
      // 로컬 데이터 새로고침
      await loadAllBooks();
      
      debugPrint('✅ BookDataService - 책을 보관함에 추가 완료: $userBookId');
      return true;
    } catch (e) {
      debugPrint('❌ BookDataService - 책을 보관함에 추가 실패: $e');
      return false;
    } finally {
      _setUpdating(false);
    }
  }
  
  /// 프로필에서 보관함으로 이동한 책들의 order_index 정리
  void _updateAllBooksFromProfile() {
    for (int i = 0; i < _profileBooks.length; i++) {
      final bookId = _profileBooks[i]['id'];
      final bookIndex = _allBooks.indexWhere((book) => book['id'] == bookId);
      if (bookIndex != -1) {
        _allBooks[bookIndex]['order_index'] = i;
      }
    }
  }
  
  /// 보관함에서 프로필로 이동한 책들의 archived_order_index 정리
  Future<void> _reorderArchivedBooks() async {
    final archivedBooks = _allBooks
        .where((book) => book['is_archived'] == true)
        .toList()
      ..sort((a, b) {
        final aIndex = (a['archived_order_index'] as num?)?.toDouble() ?? 0.0;
        final bIndex = (b['archived_order_index'] as num?)?.toDouble() ?? 0.0;
        return aIndex.compareTo(bIndex);
      });

    for (int i = 0; i < archivedBooks.length; i++) {
      final bookIndex = _allBooks.indexWhere((book) => book['id'] == archivedBooks[i]['id']);
      if (bookIndex != -1) {
        _allBooks[bookIndex]['archived_order_index'] = i.toDouble();
      }
    }
  }

  /// 보관함 책 순서 변경 후 _allBooks 리스트 업데이트
  void _updateAllBooksFromArchived() {
    for (int i = 0; i < _archivedBooks.length; i++) {
      final bookId = _archivedBooks[i]['id'];
      final bookIndex = _allBooks.indexWhere((book) => book['id'] == bookId);
      if (bookIndex != -1) {
        _allBooks[bookIndex]['archived_order_index'] = i.toDouble();
      }
    }
  }
  
  /// 보관함 순서 업데이트
  Future<void> _updateBookOrder() async {
    final archivedBooks = _allBooks
        .where((book) => book['is_archived'] == true)
        .toList()
      ..sort((a, b) {
        final aIndex = (a['archived_order_index'] as num?)?.toDouble() ?? 0.0;
        final bIndex = (b['archived_order_index'] as num?)?.toDouble() ?? 0.0;
        return aIndex.compareTo(bIndex);
      });

    for (int i = 0; i < archivedBooks.length; i++) {
      final bookId = archivedBooks[i]['id'];
      await _client
          .from('user_books')
          .update({'archived_order_index': i.toDouble()})
          .eq('id', bookId);
    }
  }
  
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
  
  void _setUpdating(bool updating) {
    _isUpdating = updating;
    notifyListeners();
  }
  
  /// 데이터 새로고침
  Future<void> refresh() async {
    await loadAllBooks();
  }
  
  /// 특정 책 찾기
  Map<String, dynamic>? findBook(String userBookId) {
    try {
      return _allBooks.firstWhere((book) => book['id'] == userBookId);
    } catch (e) {
      return null;
    }
  }
  
  /// 책이 프로필에 있는지 확인
  bool isBookInProfile(String userBookId) {
    return _profileBooks.any((book) => book['id'] == userBookId);
  }
  
  /// 책이 보관함에 있는지 확인
  bool isBookInArchive(String userBookId) {
    return _archivedBooks.any((book) => book['id'] == userBookId);
  }
} 