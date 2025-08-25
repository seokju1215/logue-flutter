import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'add_book_screen.dart';

class AddBookView extends StatefulWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  final bool isLimitReached;
  final Function(bool)? onLoadingStateChanged; // 로딩 상태 변경 콜백

  const AddBookView({
    super.key,
    required this.navigatorKey,
    this.isLimitReached = false,
    this.onLoadingStateChanged,
  });

  @override
  State<AddBookView> createState() => AddBookViewState();
}

class AddBookViewState extends State<AddBookView> with AutomaticKeepAliveClientMixin {
  // 공통 데이터 관리 (바텀 네비게이션으로 이동 후 복귀해도 유지)
  List<Map<String, dynamic>> _persistentAllBooks = [];
  bool _hasInitializedData = false;
  bool _isRefreshing = false;

  @override
  bool get wantKeepAlive => true; // 화면 상태 유지

  /// 처음 한 번만 데이터 로드
  Future<void> _initializeDataOnce() async {
    if (_hasInitializedData || _isRefreshing) return;
    
    debugPrint('📚 AddBookView - 처음 데이터 초기화');
    _isRefreshing = true;
    
    try {
      await _fetchAllBooksFromServer();
      _hasInitializedData = true;
      debugPrint('✅ AddBookView - 데이터 초기화 완료: ${_persistentAllBooks.length}개 책');
    } catch (e) {
      debugPrint('❌ AddBookView - 데이터 초기화 실패: $e');
    } finally {
      _isRefreshing = false;
    }
  }

  /// 서버에서 모든 책 데이터 가져오기
  Future<void> _fetchAllBooksFromServer() async {
    final client = Supabase.instance.client;
    final uid = client.auth.currentUser?.id;
    if (uid == null) return;

    try {
      // 기존 데이터를 임시로 저장 (소수점 값 보존용)
      final existingBooks = List<Map<String, dynamic>>.from(_persistentAllBooks);
      debugPrint('🔄 서버 데이터 요청 전 기존 데이터: ${existingBooks.length}개 책');
      
      // 기존 소수점 값들 로깅
      for (final book in existingBooks) {
        if (book['archived_order_index'] != null && 
            book['archived_order_index'] is double &&
            book['archived_order_index'] != (book['archived_order_index'] as double).roundToDouble()) {
          debugPrint('🔍 기존 소수점 값: ${book['id']} -> ${book['archived_order_index']}');
        }
      }
      
      final response = await client
          .from('user_books')
          .select('''
            id, book_id, is_archived, order_index, archived_order_index, created_at,
            books(id, image)
          ''')
          .eq('user_id', uid)
          .order('created_at', ascending: false);

      if (mounted) {
        final books = (response as List<dynamic>).cast<Map<String, dynamic>>();
        debugPrint('🔄 서버에서 받은 데이터: ${books.length}개 책');
        
        // 첫 번째 책의 전체 구조와 타입 로깅
        if (books.isNotEmpty) {
          final firstBook = books.first;
          debugPrint('🔍 첫 번째 책 전체 구조:');
          for (final entry in firstBook.entries) {
            final value = entry.value;
            final type = value?.runtimeType;
            debugPrint('  ${entry.key}: $value (타입: $type)');
          }
        }
        
        // archived_order_index를 double로 변환
        for (final book in books) {
          if (book['archived_order_index'] != null) {
            // 서버에서 받은 값의 타입과 값 로깅
            final rawValue = book['archived_order_index'];
            final rawType = rawValue.runtimeType;
            debugPrint('🔍 서버 데이터 타입 확인: ${book['id']} -> 값: $rawValue, 타입: $rawType');
            
            // 강제로 double로 변환
            final serverValue = (rawValue as num).toDouble();
            book['archived_order_index'] = serverValue;
            debugPrint('  ✅ 타입 변환 완료: $rawValue ($rawType) -> $serverValue (double)');
          }
        }
        
        debugPrint('🔄 서버 데이터로 완전 교체 완료');
        
        setState(() {
          _persistentAllBooks = books;
        });
        debugPrint('🔄 AddBookView - 서버에서 데이터 업데이트: ${_persistentAllBooks.length}개 책');
      }
    } catch (e) {
      debugPrint('❌ AddBookView - 서버 데이터 가져오기 실패: $e');
    }
  }

  /// 데이터 강제 새로고침 (수동)
  Future<void> refreshData() async {
    debugPrint('🔄 AddBookView - 수동 새로고침 시작');
    await _fetchAllBooksFromServer();
  }

  /// 로컬 데이터 업데이트 (archive_tab에서 순서 변경 시)
  void updateLocalBooks(List<Map<String, dynamic>> updatedBooks) {
    debugPrint('🔄 AddBookView - 로컬 데이터 업데이트: ${updatedBooks.length}개 책');
    
    // 책 추가 시에는 완전히 새로고침 (기존 데이터 기억하지 않음)
    if (updatedBooks.length > _persistentAllBooks.length) {
      debugPrint('🔄 책 추가 감지: 완전 새로고침 실행');
      _fetchAllBooksFromServer();
      return;
    }
    
    // 순서 변경 시에만 로컬 업데이트
    if (mounted) {
      setState(() {
        for (final updatedBook in updatedBooks) {
          final index = _persistentAllBooks.indexWhere((book) => book['id'] == updatedBook['id']);
          if (index != -1) {
            final newValue = (updatedBook['archived_order_index'] as num?)?.toDouble();
            if (newValue != null) {
              _persistentAllBooks[index]['archived_order_index'] = newValue;
              debugPrint('🔄 archived_order_index 업데이트: ${updatedBook['id']} -> $newValue');
            }
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin 때문에 필요
    
    return Navigator(
      key: widget.navigatorKey,
      onGenerateRoute: (settings) {
        // 처음 한 번만 데이터 초기화
        if (!_hasInitializedData && !_isRefreshing) {
          _initializeDataOnce();
        }
        
        return MaterialPageRoute(
          builder: (_) => AddBookScreen(
            isLimitReached: widget.isLimitReached,
            navigatorKey: widget.navigatorKey,
            onLoadingStateChanged: widget.onLoadingStateChanged,
            // 지속적인 데이터와 콜백 전달
            persistentAllBooks: _persistentAllBooks,
            hasInitializedData: _hasInitializedData,
            onRefreshData: refreshData,
            onUpdateLocalBooks: updateLocalBooks,
          ),
        );
      },
    );
  }
} 