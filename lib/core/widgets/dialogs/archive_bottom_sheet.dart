import 'dart:async';
import 'package:flutter/material.dart';
import 'package:my_logue/core/themes/app_colors.dart';
import 'package:my_logue/core/widgets/book/book_frame.dart';
import 'package:my_logue/data/services/book_activity_analytics_service.dart';
import 'package:my_logue/data/utils/firebase_analytics_util.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ArchiveBottomSheet extends StatefulWidget {
  final List<Map<String, dynamic>> allBooks; // 모든 책 목록 (최신 상태)
  final Function(List<Map<String, dynamic>>)? onBooksUpdated; // 저장 시에만 호출
  final VoidCallback? onClose; // 완전히 닫을 때만 호출
  final Function(VoidCallback)? onRegisterNotificationCallback; // 알림 콜백 등록
  final VoidCallback? onProfileTabRefresh; // ProfileTab 새로고침 콜백

  const ArchiveBottomSheet({
    super.key,
    required this.allBooks,
    this.onBooksUpdated,
    this.onClose,
    this.onRegisterNotificationCallback,
    this.onProfileTabRefresh,
  });

  @override
  State<ArchiveBottomSheet> createState() => _ArchiveBottomSheetState();
}

class _ArchiveBottomSheetState extends State<ArchiveBottomSheet> {
  final client = Supabase.instance.client;

  // ===== 페이지네이션 상태 =====
  static const int _pageSize = 100;
  int _offset = 0;
  bool _isInitialLoading = true; // 첫 로딩 스피너
  bool _isPageLoading = false; // 다음 페이지 로딩 중
  bool _hasMore = true; // 더 불러올 페이지 존재 여부
  int _totalCount = 0; // 서버 total_count (오프셋 방식에서만 사용)

  // ===== 로컬 상태 =====
  final List<Map<String, dynamic>> _localBooks = []; // 페이지를 쌓아서 보관
  List<String> originalOrder = [];
  bool _hasLocalChanges = false; // 드래그 정렬 후 저장 대기

  // 기존 상태 변수들
  bool _isSaving = false;
  late List<Map<String, dynamic>> updatedBooks; // 화면 내부 작업용(원본 불변)
  final Set<int> _selected = {};

  static const int kMaxSelection = 9;

  // [NEW] 서버 기준 선택 개수 + 바텀시트 내 임시 변화량
  int _serverSelectedCount = 0; // RPC에서 받는 값 (is_archived=false 전체 개수)
  int _deltaSelectedCount = 0;  // 이 시트에서 변경한 결과의 증감량

  // 스크롤 컨트롤러
  late final ScrollController _scrollController;

  // [NEW] 현재 화면에서 보여줄 최종 카운트 = 서버 + 델타
  int get _effectiveSelectedCount => _serverSelectedCount + _deltaSelectedCount;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScrollReachBottom);

    // 외부에서 순서 변경 알림을 받을 수 있도록 콜백 등록
    widget.onRegisterNotificationCallback?.call(_onArchiveOrderChanged);

    // 초기 페이지 로드
    _refreshFromServer().then((_) {
      // [NEW] 서버 선택 개수 가져오기 (페이지 로드와 독립적으로 가져와도 OK)
      _fetchServerSelectedCount();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScrollReachBottom);
    _scrollController.dispose();
    super.dispose();
  }

  /// archive_tab에서 순서 변경 시 즉시 호출되는 콜백
  void _onArchiveOrderChanged() {
    debugPrint('🚀 ArchiveBottomSheet - 외부 순서 변경 알림 받음, 즉시 로컬 업데이트');
    if (!mounted) return;
    
    // 서버 조회 없이 즉시 로컬 데이터로 업데이트
    _updateFromExternalData();
  }

  /// 외부(archive_tab)에서 변경된 데이터로 즉시 업데이트
  void _updateFromExternalData() {
    try {
      // widget.allBooks에서 보관함 책들만 필터링하여 즉시 반영
      final archivedBooks = widget.allBooks
          .where((book) => book['is_archived'] == true)
          .map((book) {
            // archived_order_index를 강제로 double 타입으로 변환
            final item = Map<String, dynamic>.from(book);
            if (item['archived_order_index'] != null) {
              final rawValue = item['archived_order_index'];
              final doubleValue = (rawValue as num).toDouble();
              item['archived_order_index'] = doubleValue;
              debugPrint('🔍 ArchiveBottomSheet 타입 변환: ${item['id']} -> $rawValue (${rawValue.runtimeType}) -> $doubleValue (${doubleValue.runtimeType})');
            }
            return item;
          })
          .toList()
        ..sort((a, b) {
          final aIndex = (a['archived_order_index'] as num?)?.toDouble() ?? 0.0;
          final bIndex = (b['archived_order_index'] as num?)?.toDouble() ?? 0.0;
          return aIndex.compareTo(bIndex);
        });

      debugPrint('🚀 즉시 로컬 업데이트: ${archivedBooks.length}개 보관함 책');

      if (mounted) {
        setState(() {
          _localBooks.clear();
          _localBooks.addAll(archivedBooks);
          
          // 기준 순서 업데이트
          originalOrder = _localBooks.map((b) => b['id'] as String).toList();
          
          // 선택 상태 업데이트
          _updateSelectionFromLocalBooks();
          
          // 총 개수 업데이트
          _totalCount = archivedBooks.length;
          _hasMore = false; // 로컬 데이터이므로 더 불러올 것 없음
          _offset = archivedBooks.length;
          
          // 로딩 상태 해제
          _isInitialLoading = false;
          _isPageLoading = false;
        });
      }

      debugPrint('✅ 즉시 로컬 업데이트 완료: ${_localBooks.length}개 책 표시');
      
      // 백그라운드에서 서버 데이터와 동기화 (사용자는 기다리지 않음)
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _refreshFromServer();
        }
      });
      
    } catch (e) {
      debugPrint('❌ 즉시 로컬 업데이트 실패: $e');
      // 실패 시 기존 방식으로 폴백
      _onArchiveOrderChangedFallback();
    }
  }

  /// 폴백: 기존 서버 조회 방식
  void _onArchiveOrderChangedFallback() {
    debugPrint('🔄 ArchiveBottomSheet - 폴백: 서버에서 데이터 새로고침');
    if (!mounted) return;
    
    setState(() {
      _isInitialLoading = true;
    });
    
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        _refreshFromServer();
      }
    });
  }

  // ========== 서버 호출 ==========

  // [NEW] 서버에서 현재 선택 개수 가져오기 (is_archived=false 전체 개수)
  Future<void> _fetchServerSelectedCount() async {
    try {
      final res = await client.rpc('get_selected_book_count');
      final count = (res is int) ? res : int.tryParse('$res') ?? 0;
      if (!mounted) return;
      setState(() {
        _serverSelectedCount = count;
        // delta는 시트 내 조작값이라 여기서 따로 건드리지 않음
      });
      debugPrint('📥 서버 선택 개수 불러옴: $_serverSelectedCount');
    } catch (e) {
      debugPrint('❌ 서버 선택 개수 불러오기 실패: $e');
    }
  }

  Future<void> _refreshFromServer() async {
    setState(() {
      _isInitialLoading = true;
      _offset = 0;
      _localBooks.clear();
      _hasMore = true;
      _totalCount = 0;
      _hasLocalChanges = false;

      // [NEW] 새 시트 열 때마다 delta는 0으로 초기화 (서버 카운트와 별개)
      _deltaSelectedCount = 0;
    });

    await _loadNextPage(); // 첫 페이지
    if (mounted) {
      setState(() {
        _isInitialLoading = false;
        // 초기 로딩 완료 후 선택 상태 업데이트
        _updateSelectionFromLocalBooks();
      });
    }
  }

  Future<void> _loadNextPage() async {
    if (_isPageLoading || !_hasMore) return;

    // 초기 로딩 중일 때는 _isPageLoading을 설정하지 않음
    if (!_isInitialLoading) {
      setState(() {
        _isPageLoading = true;
      });
    }

    try {
      // 1) RPC로 user_books 페이지 가져오기 (정렬/카운트 포함)
      final rpc = await client.rpc(
        'get_archived_books_page',
        params: {
          'p_limit': _pageSize,
          'p_offset': _offset,
        },
      ) as List<dynamic>;

      final rows = rpc.cast<Map<String, dynamic>>();

      // total_count 추출
      if (rows.isNotEmpty) {
        _totalCount = (rows.first['total_count'] as int?) ?? 0;
      }

      // 2) 현재 페이지의 book 이미지 한번에 조회
      final bookIds = rows
          .map((e) => e['book_id'])
          .where((id) => id != null)
          .toSet()
          .toList();

      Map<String, dynamic> imagesByBookId = {};
      if (bookIds.isNotEmpty) {
        final booksRes = await client
            .from('books')
            .select('id, image')
            .inFilter('id', bookIds);

        for (final b in (booksRes as List)) {
          imagesByBookId[b['id'] as String] = {
            'id': b['id'],
            'image': b['image'],
          };
        }
      }

      // 3) rows + image merge + archived_order_index 타입 보장
      final pageItems = rows.map((e) {
        final bookId = e['book_id'];
        final item = {
          ...e,
          'books': imagesByBookId[bookId] ?? {'id': bookId, 'image': null},
        };
        
        // archived_order_index를 강제로 double 타입으로 변환
        if (item['archived_order_index'] != null) {
          final rawValue = item['archived_order_index'];
          final doubleValue = (rawValue as num).toDouble();
          item['archived_order_index'] = doubleValue;
          debugPrint('🔍 ArchiveBottomSheet _loadNextPage 타입 변환: ${item['id']} -> $rawValue (${rawValue.runtimeType}) -> $doubleValue (${doubleValue.runtimeType})');
        }
        
        return item;
      }).toList();

      // 4) 로컬 리스트에 추가
      if (mounted) {
        setState(() {
          _localBooks.addAll(pageItems);
          _offset += rows.length;
          _hasMore = _offset < _totalCount;
          // 기준 순서 업데이트
          originalOrder = _localBooks.map((b) => b['id'] as String).toList();

          // 초기 로딩 중일 때는 선택 상태 업데이트를 하지 않음 (refreshFromServer에서 처리)
          if (!_isInitialLoading) {
            _updateSelectionFromLocalBooks();
          }
        });
      }
    } catch (e) {
      debugPrint('❌ 페이지 로드 실패: $e');
    } finally {
      if (mounted && !_isInitialLoading) {
        setState(() => _isPageLoading = false);
      }
    }
  }

  void _onScrollReachBottom() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    // 바닥 근처에서 다음 페이지 로드
    if (pos.pixels > pos.maxScrollExtent - 300) {
      _loadNextPage();
    }
  }

  /// _localBooks에서 is_archived가 false인 책들을 자동으로 선택
  void _updateSelectionFromLocalBooks() {
    _selected.clear();
    for (int i = 0; i < _localBooks.length; i++) {
      if (_localBooks[i]['is_archived'] == false) {
        _selected.add(i);
      }
    }
    debugPrint('🔄 자동 선택 업데이트(페이지 범위 내): ${_selected.length}개 선택');
    // 화면에 표시하는 카운트는 _effectiveSelectedCount 사용
  }

  // allBooks에서 보관함 책들만 필터링하여 반환 (기존 로직 유지)
  List<Map<String, dynamic>> _getArchivedBooks() {
    return _localBooks.toList()
      ..sort((a, b) {
        final aIndex = (a['archived_order_index'] as num?)?.toDouble() ?? 0.0;
        final bIndex = (b['archived_order_index'] as num?)?.toDouble() ?? 0.0;
        return aIndex.compareTo(bIndex);
      });
  }

  @override
  void didUpdateWidget(covariant ArchiveBottomSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // allBooks가 변경되었을 때 보관함 책들을 다시 필터링
    if (oldWidget.allBooks != widget.allBooks) {
      debugPrint('🔄 ArchiveBottomSheet - allBooks 변경 감지, 보관함 책들 재필터링');
      _resetFrom(_getArchivedBooks());
    }
  }

  void _resetFrom(List<Map<String, dynamic>> source) {
    // _localBooks가 비어있으면 source를 사용, 아니면 _localBooks를 사용
    final booksToUse = _localBooks.isEmpty ? source : _localBooks;
    updatedBooks = booksToUse.map((m) => Map<String, dynamic>.from(m)).toList();
    
    // 디버깅: _resetFrom에서 받은 데이터 구조 확인
    debugPrint('🔍 _resetFrom - 받은 데이터 구조:');
    for (int i = 0; i < updatedBooks.length; i++) {
      final book = updatedBooks[i];
      debugPrint(
          '🔍  [$i] ID: ${book['id']}, book_id: ${book['book_id']}, is_archived: ${book['is_archived']}');
    }

    // is_archived가 false인 책들을 자동으로 선택
    _updateSelectionFromLocalBooks();
    setState(() {});
  }

  // [NEW] 원본(allBooks)에서 해당 id의 초기 is_archived 값을 얻는 헬퍼
  bool _originalIsArchived(String id) {
    final m = widget.allBooks.firstWhere(
          (b) => b['id'] == id,
      orElse: () => const {},
    );
    if (m.isEmpty) return true; // 기본값: 보관함(true)로 취급
    final v = m['is_archived'];
    return v is bool ? v : true;
  }

  // [NEW] 선택 가능 여부 체크(서버 개수 + delta 기준으로 최대 9 유지)
  bool _canSelectIndex(int index) {
    final current = _localBooks[index];
    final id = current['id'] as String;
    final wasArchivedOriginal = _originalIsArchived(id);
    final isArchivedNow = current['is_archived'] == true;

    // 현재는 보관함이고(=아카이브 true), 탭해서 프로필로 보낼 때(=false)만 카운트 증가 고려
    if (isArchivedNow) {
      // 토글 후 delta 변화 예상치 계산
      int newDelta = _deltaSelectedCount;
      if (wasArchivedOriginal) {
        // 원래도 보관함(true) → 지금 false로 바꾸면 +1
        newDelta += 1;
      } else {
        // 원래 프로필(false)이었는데 현재는 true(이미 -1 적용된 상태) → false로 돌리면 -1을 되돌려 0
        // 즉 delta가 +1 증가
        newDelta += 1;
      }
      final prospective = _serverSelectedCount + newDelta;
      return prospective <= kMaxSelection;
    }
    // 이미 선택 상태(프로필 false)에서 다시 탭하는 건 해제이므로 제한 없음
    return true;
  }

  void _toggleSelect(int index) {
    // 디버깅: 선택 전 데이터 구조 확인
    debugPrint('🔍 _toggleSelect 시작 - index: $index');
    debugPrint(
        '🔍 선택 전 _localBooks[$index]: ID=${_localBooks[index]['id']}, book_id=${_localBooks[index]['book_id']}, is_archived=${_localBooks[index]['is_archived']}');
    
    setState(() {
      final currentIsSelected = _selected.contains(index);
      final current = _localBooks[index];
      final id = current['id'] as String;
      final wasArchivedOriginal = _originalIsArchived(id);

      if (currentIsSelected) {
        // 선택 → 해제 (프로필 → 보관함)
        _selected.remove(index);
        // is_archived true로
        current['is_archived'] = true;

        // delta 조정
        // 원래 보관함(true) 였다면: 원래 true -> 지금 false였던 상태가 해제로 돌아가니 delta -1
        // 원래 프로필(false) 였다면: 원래 false -> 지금 true로 바꿨으니 delta -1 (즉 -1 유지 or 더 내려감)
        // 하지만 여기 상황은 "현재 선택 상태였음(=false)"에서 해제로 가는 케이스:
        //  - 원래 true였다면 이전에 +1 되어 있었는데, 다시 true로 돌아가니 -1
        //  - 원래 false였다면 이번 탭으로 false->true가 되니 -1
        _deltaSelectedCount -= 1;

        // order_index 정리(기존 로직 유지)
        final removedOrderIndex = current['order_index'];
        current['order_index'] = null;
        if (removedOrderIndex != null) {
          for (int i = 0; i < _localBooks.length; i++) {
            if (i == index) continue;
            final oi = _localBooks[i]['order_index'];
            if (oi != null && oi is int && oi > removedOrderIndex) {
              _localBooks[i]['order_index'] = oi - 1;
            }
          }
        }
      } else {
        // 해제 → 선택 (보관함 → 프로필)
        // [NEW] 서버 기준 + delta로 최대 9 체크
        if (!_canSelectIndex(index)) {
          debugPrint('⚠️ 최대 $kMaxSelection 개 제한(서버+delta 기준)에 걸려 선택 불가');
          return;
        }

        _selected.add(index);
        // is_archived false로
        current['is_archived'] = false;

        // delta 조정
        // 원래 보관함(true) → 지금 false: +1
        // 원래 프로필(false)였는데 현재는 true 상태였다면(이전 탭으로 -1이 되어 있던 상태),
        // 다시 false로 돌아가니 delta +1 (즉 0으로 복원)
        _deltaSelectedCount += 1;

        // order_index 정리(기존 로직 유지)
        for (int i = 0; i < _localBooks.length; i++) {
          if (i == index) continue;
          final oi = _localBooks[i]['order_index'];
          if (oi != null && oi is int) {
            _localBooks[i]['order_index'] = oi + 1;
          }
        }
        current['order_index'] = 0;
      }
      
      // 디버깅: 선택 후 데이터 구조 확인
      debugPrint(
          '🔍 선택 후 _localBooks[$index]: ID=${current['id']}, book_id=${current['book_id']}, is_archived=${current['is_archived']}');
      debugPrint('🧮 서버=${_serverSelectedCount}, delta=${_deltaSelectedCount}, 표기=${_effectiveSelectedCount}');
    });
  }

  /// 보관함(true) → 프로필(false)로 바뀐 책들의 user_books.id를 반환하고,
  /// 해당 레코드의 unarchived_at을 now()로 업데이트한다.
  Future<List<String>> _markUnarchivedAndCollectIds() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final newlyUnarchivedBookIds = <String>[];
      final movedBooks = <Map<String, dynamic>>[];

      for (int i = 0; i < _localBooks.length; i++) {
        final current = _localBooks[i];
        final original = widget.allBooks.firstWhere(
              (b) => b['id'] == current['id'],
          orElse: () => {},
        );

        // 원본은 archived(true)였는데 지금은 false(프로필)로 바뀐 경우만 수집
        if (original.isNotEmpty &&
            original['is_archived'] == true &&
            current['is_archived'] == false) {
          newlyUnarchivedBookIds.add(current['id'] as String);
          movedBooks.add(current);
        }
      }

      if (newlyUnarchivedBookIds.isNotEmpty) {
        final nowUtc = DateTime.now().toUtc().toIso8601String();
        await client.from('user_books').update(
            {'unarchived_at': nowUtc}).inFilter('id', newlyUnarchivedBookIds);

        debugPrint(
            '✅ unarchived_at 업데이트 완료: ${newlyUnarchivedBookIds.length}개');

        // Firebase Analytics: 프로필로 이동한 책들 추적
        await _trackBooksMovedToProfile(movedBooks);
      } else {
        debugPrint('ℹ️ 새로 unarchived된 책 없음');
      }

      return newlyUnarchivedBookIds;
    } catch (e) {
      debugPrint('❌ unarchived_at 업데이트 실패: $e');
      return [];
    }
  }

  /// Firebase Analytics: 프로필로 이동한 책들 추적
  Future<void> _trackBooksMovedToProfile(List<Map<String, dynamic>> movedBooks) async {
    try {
      for (final book in movedBooks) {
        final reviewTitle = book['review_title'] as String?;
        final reviewContent = book['review_content'] as String?;
        
        // 보관함 → 프로필 이동 전용 이벤트 전송
        await FirebaseAnalyticsUtil.logBookAddedToProfile(
          bookTitle: book['title'] ?? '',
          bookAuthor: book['author'] ?? '',
          reviewTitle: reviewTitle,
          reviewContent: reviewContent,
        );

        // 통계 서비스에 책 추가 카운트
        await BookActivityAnalyticsService.trackBookAdded();

        // 후기가 있는 경우 후기 작성 카운트도 추가
        if (reviewTitle != null && reviewTitle.isNotEmpty ||
            reviewContent != null && reviewContent.isNotEmpty) {
          // 통계 서비스에 후기 작성 카운트
          await BookActivityAnalyticsService.trackReviewWritten();
        }
      }

      debugPrint('📊 GA 추적 완료: ${movedBooks.length}개 책 프로필로 이동 (add_book_to_profile)');
    } catch (e) {
      debugPrint('❌ GA 추적 실패: $e');
    }
  }

  /// 백그라운드에서 알림 전송 (사용자 대기 없음)
  Future<void> _sendNotificationInBackground(String userId, List<String> userBookIds) async {
    try {
      debugPrint('🔄 백그라운드에서 알림 전송 시작: ${userBookIds.length}개 책');
      
      final resp = await client.functions.invoke(
        'send-notification-v2',
        body: {
          'sender_id': userId,
          'type': 'post',
          'user_book_ids': userBookIds,
        },
      );
      
      if (resp.status != 200) {
        debugPrint('❌ 백그라운드 알림 전송 실패: ${resp.data}');
      } else {
        debugPrint('✅ 백그라운드 알림 전송 성공: ${resp.data}');
      }
    } catch (e) {
      debugPrint('❌ 백그라운드 알림 전송 중 오류: $e');
    }
  }

  /// is_archived가 false로 변경된 책들에 대해 unarchived_at 컬럼을 업데이트
  Future<void> _updateUnarchivedAt() async {
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return;

      // 원본 데이터와 비교해서 새로 is_archived가 false로 바뀐 책들의 ID 목록
      final newlyUnarchivedBookIds = <String>[];
      
      for (int i = 0; i < _localBooks.length; i++) {
        final currentBook = _localBooks[i];
        final originalBook = widget.allBooks.firstWhere(
          (book) => book['id'] == currentBook['id'],
          orElse: () => {},
        );
        
        // 원본에서는 is_archived가 true였는데, 현재는 false로 바뀐 경우
        if (originalBook.isNotEmpty && 
            originalBook['is_archived'] == true && 
            currentBook['is_archived'] == false) {
          newlyUnarchivedBookIds.add(currentBook['id']);
          debugPrint(
              '🔄 새로 unarchived된 책 발견: ID=${currentBook['id']}, book_id=${currentBook['book_id']}');
        }
      }

      if (newlyUnarchivedBookIds.isNotEmpty) {
        // unarchived_at을 현재 timestamp로 업데이트
        final currentTimestamp = DateTime.now().toUtc().toIso8601String();
        
        await client
            .from('user_books')
            .update({'unarchived_at': currentTimestamp}).inFilter(
            'id', newlyUnarchivedBookIds);
        
        debugPrint(
            '✅ unarchived_at 업데이트 완료: ${newlyUnarchivedBookIds.length}개 책');
        debugPrint('📅 업데이트된 timestamp: $currentTimestamp');
        debugPrint('📚 업데이트된 책 ID들: $newlyUnarchivedBookIds');
      } else {
        debugPrint('ℹ️ 새로 unarchived된 책이 없습니다');
      }
    } catch (e) {
      debugPrint('❌ unarchived_at 업데이트 실패: $e');
    }
  }

  List<Widget> _buildShelves({
    required int itemCount,
    required double itemHeight,
    required double runSpacing,
    required double topOffset,
  }) {
    const booksPerRow = 5;
    final rowCount = (itemCount / booksPerRow).ceil();

    return List.generate(rowCount, (i) {
      final shelfTop = topOffset + (itemHeight + 22) * i; // 약간 더 촘촘하게
      return Positioned(
        top: shelfTop,
        left: 0,
        right: 0,
        child: Container(
          height: 5,
          decoration: BoxDecoration(
            color: const Color(0xFFF6F6F6),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 4,
                offset: const Offset(0, 4),
              ),
            ],
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final topCountText = '$_effectiveSelectedCount/$kMaxSelection';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 드래그 핸들
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 3,
              decoration: BoxDecoration(
                color: AppColors.black900,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // 제목/저장/선택 카운트
          Container(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 15),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top:20),
                  child: Center(
                  child: Text(
                    '전체',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.black900,
                      fontWeight: FontWeight.w400,
                      height: 1.1875,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      GestureDetector(
                        onTap: () async {
                          if (_isSaving) return;
                          setState(() => _isSaving = true);

                          try {
                            final userId = client.auth.currentUser?.id;
                            if (userId == null) {
                              throw Exception('로그인이 필요합니다.');
                            }

                            // 1) 보관함 → 프로필로 바뀐 책들 ID 수집 + unarchived_at 업데이트
                            final newlyUnarchivedIds =
                            await _markUnarchivedAndCollectIds();

                            // 2) 상위로 최신 상태 전달 & 시트 닫기 (즉시 실행)
                            final updatedBooks = _localBooks
                                .map((e) => Map<String, dynamic>.from(e))
                                .toList();
                            debugPrint('🚀 ArchiveBottomSheet - 상위로 데이터 전달: ${updatedBooks.length}개 책');
                            widget.onBooksUpdated?.call(updatedBooks);
                            
                            // 🚀 ProfileTab 즉시 새로고침 (약간의 지연 후)
                            Future.delayed(const Duration(milliseconds: 300), () {
                              widget.onProfileTabRefresh?.call();
                            });
                            
                            widget.onClose?.call();
                            if (mounted) Navigator.pop(context, true);

                            // 3) 백그라운드에서 알림 전송 (사용자 대기 없음)
                            if (newlyUnarchivedIds.isNotEmpty) {
                              _sendNotificationInBackground(userId, newlyUnarchivedIds);
                            }
                          } catch (e) {
                            debugPrint('❌ 저장 처리 실패: $e');
                            if (mounted) Navigator.pop(context, false);
                          } finally {
                            if (mounted) setState(() => _isSaving = false);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(13, 20, 13, 10),
                          color: Colors.transparent,
                          child: Text(
                            '저장',
                            style: TextStyle(
                              color: AppColors.blue500,
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                              height: 1.15,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      // [CHANGED] 서버+델타 기준 카운트
                      Text(
                        topCountText,
                        style: TextStyle(
                          color: AppColors.black900,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 상단 카운트
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 10),
                // [CHANGED]
                Text(
                  topCountText,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.black500,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // 그리드
          Expanded(
            child: _isInitialLoading
                ? const Center(
              child: CircularProgressIndicator(color: AppColors.black900),
            )
                : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0)
                  .copyWith(top: 21, bottom: 21),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const crossAxisCount = 5;
                  const crossAxisSpacing = 11.7;
                  const runSpacing = 35.0;
                  const itemAspectRatio = 98 / 145;
                  const topOffsetForShelf = 90.0;

                  final totalSpacing =
                      crossAxisSpacing * (crossAxisCount - 1);
                  final itemWidth =
                      (constraints.maxWidth - totalSpacing) /
                          crossAxisCount;
                  final itemHeight = itemWidth / itemAspectRatio;

                  final rows =
                  (_localBooks.length / crossAxisCount).ceil();
                  final gridHeight =
                      rows * itemHeight + (rows - 1) * runSpacing;

                  return Scrollbar(
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      padding: EdgeInsets.zero,
                      child: SizedBox(
                        height: gridHeight + topOffsetForShelf,
                        width: double.infinity,
                        child: Stack(
                          children: [
                            ..._buildShelves(
                              itemCount: _localBooks.length,
                              itemHeight: itemHeight,
                              runSpacing: runSpacing,
                              topOffset: topOffsetForShelf,
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 22),
                              child: GridView.builder(
                                physics:
                                const NeverScrollableScrollPhysics(),
                                shrinkWrap: true,
                                itemCount: _localBooks.length,
                                gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  crossAxisSpacing: crossAxisSpacing,
                                  mainAxisSpacing: runSpacing,
                                  childAspectRatio: itemAspectRatio,
                                ),
                                itemBuilder: (context, index) {
                                  final book = _localBooks[index];
                                  final imageUrl = book['books']
                                  ?['image'] ??
                                      'https://via.placeholder.com/150';
                                  final isSelected =
                                  _selected.contains(index);

                                  return GestureDetector(
                                    onTap: () => _toggleSelect(index),
                                    child: Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        ClipRRect(
                                          borderRadius:
                                          BorderRadius.circular(0),
                                          child: ColorFiltered(
                                            colorFilter: isSelected
                                                ? ColorFilter.mode(
                                              Colors.black
                                                  .withOpacity(0.6),
                                              BlendMode.darken,
                                            )
                                                : const ColorFilter.mode(
                                              Colors.transparent,
                                              BlendMode.srcOver,
                                            ),
                                            child: BookFrame(
                                                imageUrl: imageUrl),
                                          ),
                                        ),
                                        Align(
                                          alignment: Alignment.topRight,
                                          child: Container(
                                            margin: const EdgeInsets.only(
                                                right: 3.24, top: 3),
                                            width: 18,
                                            height: 18,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: isSelected
                                                    ? AppColors.blue500
                                                    : AppColors.black300,
                                                width:
                                                isSelected ? 2 : 1.5,
                                              ),
                                            ),
                                            child: AnimatedContainer(
                                              duration: const Duration(
                                                  milliseconds: 50),
                                              margin:
                                              const EdgeInsets.all(2),
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: isSelected
                                                    ? AppColors.blue500
                                                    : Colors.transparent,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // 페이지 하단 로딩 인디케이터
          if (_isPageLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.black900),
              ),
            ),
          if (!_hasMore && !_isPageLoading) const SizedBox(height: 16),
        ],
      ),
    );
  }
}