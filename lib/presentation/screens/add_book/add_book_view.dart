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
      final response = await client
          .from('user_books')
          .select('''
            id, book_id, is_archived, order_index, archived_order_index, created_at,
            books(id, image)
          ''')
          .eq('user_id', uid)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _persistentAllBooks = (response as List<dynamic>).cast<Map<String, dynamic>>();
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
    if (mounted) {
      setState(() {
        // 기존 _persistentAllBooks에서 업데이트된 책들의 순서 정보 반영
        for (final updatedBook in updatedBooks) {
          final index = _persistentAllBooks.indexWhere((book) => book['id'] == updatedBook['id']);
          if (index != -1) {
            _persistentAllBooks[index]['archived_order_index'] = updatedBook['archived_order_index'];
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