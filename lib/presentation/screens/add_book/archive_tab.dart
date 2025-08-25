import 'dart:async';
import 'package:flutter/material.dart';
import 'package:my_logue/core/themes/app_colors.dart';
import 'package:my_logue/presentation/screens/add_book/search_book_screen.dart';
import 'package:my_logue/presentation/screens/post/single_post_screen.dart';
import 'package:reorderables/reorderables.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/themes/stroke_text_style.dart';
import '../../../core/widgets/book/book_frame.dart';
import '../../../core/widgets/dialogs/AnnouncementDialog.dart';
import '../../../data/datasources/user_book_api.dart';
import '../../../core/services/book_data_service.dart';

class ArchiveTab extends StatefulWidget {
  /// NOTE: 이제 BookDataService를 사용하므로 allBooks는 선택사항이지만
  /// 기존 상위 코드 호환을 위해 남겨둠. (처음 렌더 속도 개선용 seed로도 사용 가능)
  final List<Map<String, dynamic>> allBooks;
  final VoidCallback onRefresh;
  final VoidCallback? onBookAdded;
  final Function(List<Map<String, dynamic>>)? onBooksChanged;
  final BookDataService? bookDataService; // BookDataService 인스턴스

  final GlobalKey<NavigatorState>? navigatorKey;
  final VoidCallback? onFocusMe;
  final VoidCallback? onArchiveOrderChanged; // 보관함 순서 변경 시 즉시 알림

  const ArchiveTab({
    Key? key,
    required this.allBooks,
    required this.onRefresh,
    this.onBookAdded,
    this.onBooksChanged,
    this.bookDataService,

    this.navigatorKey,
    this.onFocusMe,
    this.onArchiveOrderChanged,
  }) : super(key: key);

  @override
  State<ArchiveTab> createState() => _ArchiveTabState();
}

class _ArchiveTabState extends State<ArchiveTab> {
  final client = Supabase.instance.client;
  late final BookDataService _bookDataService; // BookDataService 인스턴스

  // ===== 페이지네이션 상태 =====
  static const int _pageSize = 200;
  int _offset = 0;
  bool _isInitialLoading = true;   // 첫 로딩 스피너
  bool _isPageLoading = false;     // 다음 페이지 로딩 중
  bool _hasMore = true;            // 더 불러올 페이지 존재 여부
  int _totalCount = 0;             // 서버 total_count (오프셋 방식에서만 사용)

  // ===== 로컬 상태 =====
  final List<Map<String, dynamic>> _localBooks = []; // 페이지를 쌓아서 보관
  List<String> originalOrder = [];
  bool _hasLocalChanges = false;   // 드래그 정렬 후 저장 대기
  bool _isSavingOrder = false;     // 순서 변경 저장 중 상태
  Future<void> _fetchTotalCount() async {
    try {
      final uid = client.auth.currentUser?.id;
      if (uid == null) return;

      final res = await client.rpc('get_archived_books_count', params: {
        'p_user_id': uid
      });

      int count;
      if (res == null) {
        count = 0;
      } else if (res is int) {
        count = res;
      } else if (res is num) {
        count = res.toInt();
      } else if (res is Map && res.values.isNotEmpty) {
        // 드물게 {"get_archived_books_count": 123} 형태일 수도 있음
        final v = res.values.first;
        count = (v is num) ? v.toInt() : 0;
      } else {
        count = 0;
      }

      if (mounted) {
        setState(() => _totalCount = count);
      }
    } catch (e) {
      debugPrint('❌ 총 권수 가져오기 실패: $e');
    }
  }

  // UI 상태
  bool _isUpdatingBooks = false;

  // 스크롤/자동 스크롤
  late final ScrollController _scrollController;
  bool _isDragging = false;
  Offset? _dragPosition;
  Timer? _autoScrollTimer;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScrollReachBottom);
    
    // BookDataService 초기화
    _bookDataService = widget.bookDataService ?? BookDataService();
    
    // 초기 페이지 로드
    _refreshFromServer();
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _dragCompleteTimer?.cancel(); // 드래그 완료 타이머 정리
    _scrollController.removeListener(_onScrollReachBottom);
    _scrollController.dispose();
    super.dispose();
  }

  // ========== 서버 호출 ==========

  Future<void> _refreshFromServer() async {
    setState(() {
      _isInitialLoading = true;
      _offset = 0;
      _localBooks.clear(); // 기존 데이터 완전히 지우기
      _hasMore = true;
      _totalCount = 0;
      _hasLocalChanges = false;
    });

    // BookDataService의 데이터를 우선적으로 사용
    if (widget.bookDataService != null) {
      await widget.bookDataService!.loadAllBooks();
      final archivedBooks = widget.bookDataService!.archivedBooks;
      
      if (mounted) {
        setState(() {
          _localBooks.addAll(archivedBooks);
          _totalCount = archivedBooks.length;
          _hasMore = false;
          originalOrder = _localBooks.map((b) => b['id'] as String).toList();
          _isInitialLoading = false;
        });
        debugPrint('✅ BookDataService에서 보관함 데이터 로드 완료: ${archivedBooks.length}권');
        return;
      }
    }
    
    // BookDataService가 없거나 실패한 경우 기존 RPC 함수 사용
    await _loadNextPage();
    
    if (mounted) {
      setState(() {
        _isInitialLoading = false;
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
        
        // archived_order_index를 강제로 double 타입으로 변환 (소수점 값 보존)
        if (item['archived_order_index'] != null) {
          final rawValue = item['archived_order_index'];
          final rawType = rawValue.runtimeType;
          
          // 더 강력한 타입 변환 및 소수점 값 보존
          double finalValue;
          if (rawValue is int) {
            // int인 경우 double로 변환
            finalValue = rawValue.toDouble();
            debugPrint('🔍 int -> double 변환: ${item['id']} -> $rawValue (int) -> $finalValue (double)');
          } else if (rawValue is double) {
            // 이미 double인 경우 그대로 사용
            finalValue = rawValue;
            debugPrint('🔍 이미 double: ${item['id']} -> $rawValue (double)');
          } else if (rawValue is num) {
            // num인 경우 double로 변환
            finalValue = rawValue.toDouble();
            debugPrint('🔍 num -> double 변환: ${item['id']} -> $rawValue ($rawType) -> $finalValue (double)');
          } else {
            // 기타 타입인 경우 문자열로 변환 후 double로 파싱
            try {
              finalValue = double.parse(rawValue.toString());
              debugPrint('🔍 문자열 파싱 -> double: ${item['id']} -> $rawValue ($rawType) -> $finalValue (double)');
            } catch (e) {
              // 파싱 실패 시 기본값 사용
              finalValue = 0.0;
              debugPrint('⚠️ 파싱 실패, 기본값 사용: ${item['id']} -> $rawValue ($rawType) -> $finalValue (double)');
            }
          }
          
          item['archived_order_index'] = finalValue;
          debugPrint('✅ 최종 타입 변환 완료: ${item['id']} -> $finalValue (${finalValue.runtimeType})');
        }
        
        return item;
      }).toList();

      // 4) 로컬 리스트에 추가 (기존 archived_order_index 값 보존)
      if (mounted) {
        setState(() {
          // 새 데이터만 추가 (중복 방지)
          for (final newBook in pageItems) {
            // 이미 존재하는 책인지 확인
            final existingIndex = _localBooks.indexWhere(
              (book) => book['id'] == newBook['id'],
            );
            
            if (existingIndex == -1) {
              // 새 책이면 추가
              _localBooks.add(newBook);
            } else {
              // 기존 책이면 archived_order_index 값만 업데이트 (소수점 보존)
              final existingBook = _localBooks[existingIndex];
              if (existingBook['archived_order_index'] != null && 
                  existingBook['archived_order_index'] is double) {
                newBook['archived_order_index'] = existingBook['archived_order_index'];
                debugPrint('🔄 archived_order_index 값 보존: ${newBook['id']} -> ${existingBook['archived_order_index']}');
              }
              // 기존 책을 새 데이터로 교체
              _localBooks[existingIndex] = newBook;
            }
          }
          
          // archived_order_index 순서대로 정렬
          _localBooks.sort((a, b) {
            final aIndex = (a['archived_order_index'] as num?)?.toDouble() ?? 0.0;
            final bIndex = (b['archived_order_index'] as num?)?.toDouble() ?? 0.0;
            return aIndex.compareTo(bIndex);
          });
          
          _offset += rows.length;
          _hasMore = _offset < _totalCount;
          // 기준 순서 업데이트
          originalOrder = _localBooks.map((b) => b['id'] as String).toList();
          
          // BookDataService와 동기화
          _syncWithBookDataService();
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
  
  /// BookDataService와 데이터 동기화
  void _syncWithBookDataService() {
    try {
      // BookDataService의 archivedBooks를 현재 로컬 데이터로 업데이트
      final bookDataService = widget.bookDataService;
      if (bookDataService != null) {
        // BookDataService의 _archivedBooks를 직접 업데이트 (private 필드이므로 reflection 사용 불가)
        // 대신 BookDataService의 refresh 메서드를 호출하여 동기화
        bookDataService.refresh();
        debugPrint('🔄 BookDataService와 데이터 동기화 완료');
      }
    } catch (e) {
      debugPrint('⚠️ BookDataService 동기화 실패: $e');
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

  // ========== 드래그 처리 (드래그 완료 즉시 저장) ==========

  bool _isDraggingActive = false; // 드래그 진행 중 여부
  Timer? _dragCompleteTimer; // 드래그 완료 감지 타이머
  
  // 이동한 책 정보 저장
  Map<String, dynamic>? _movedBook;
  int? _oldIndex;
  int? _newIndex;

  void _onReorder(int oldIndex, int newIndex) {
    if (oldIndex == newIndex) return;

    debugPrint('🔄 _onReorder - 이동 전 archived_order_index: ${_localBooks[oldIndex]['archived_order_index']}');
    
    // 이동할 책 정보 저장
    final movedBook = Map<String, dynamic>.from(_localBooks[oldIndex]);
    final movedBookId = movedBook['id'] as String;
    
    debugPrint('🔄 _onReorder - 배열 조작 전:');
    debugPrint('  위치 $oldIndex: ${movedBook['id']} -> archived_order_index: ${movedBook['archived_order_index']} (이동할 책)');
    
    // 배열에서 제거
    _localBooks.removeAt(oldIndex);
    
    // 새 위치에 삽입
    _localBooks.insert(newIndex, movedBook);
    
    // 이동된 책의 archived_order_index 계산 (double 타입 명시)
    double newValue = 0.0;
    if (newIndex == 0) {
      // 맨 앞으로 이동: 첫 번째 책보다 작은 값
      final firstBookIndex = (_localBooks[1]['archived_order_index'] as num?)?.toDouble() ?? 0.0;
      newValue = (firstBookIndex - 1.0).toDouble();
      debugPrint('🔍 맨 앞 이동: firstBookIndex=$firstBookIndex, newValue=$newValue (타입: ${newValue.runtimeType})');
    } else if (newIndex == _localBooks.length - 1) {
      // 맨 뒤로 이동: 마지막 책보다 큰 값
      final lastBookIndex = (_localBooks[newIndex - 1]['archived_order_index'] as num?)?.toDouble() ?? 0.0;
      newValue = (lastBookIndex + 1.0).toDouble();
      debugPrint('🔍 맨 뒤 이동: lastBookIndex=$lastBookIndex, newValue=$newValue (타입: ${newValue.runtimeType})');
    } else {
      // 중간에 삽입: 이전/다음 책의 중간값을 더 정밀하게 계산
      final prevBookIndex = (_localBooks[newIndex - 1]['archived_order_index'] as num?)?.toDouble() ?? 0.0;
      final nextBookIndex = (_localBooks[newIndex + 1]['archived_order_index'] as num?)?.toDouble() ?? 0.0;
      
      // 더 정밀한 중간값 계산
      if (prevBookIndex == nextBookIndex) {
        // 같은 값이면 0.5 추가 (double 타입 보장)
        newValue = prevBookIndex + 0.5;
        debugPrint('🔍 같은 값 처리: prev=$prevBookIndex, next=$nextBookIndex, newValue=$newValue (타입: ${newValue.runtimeType})');
      } else {
        // 다른 값이면 정확한 중간값 계산
        newValue = (prevBookIndex + nextBookIndex) / 2.0;
        
        // 만약 중간값이 정수라면 더 정밀하게 조정
        if (newValue == newValue.roundToDouble()) {
          // 이전 값과의 차이를 계산하여 더 작은 단위로 조정
          final diff = (nextBookIndex - prevBookIndex).abs();
          if (diff > 1.0) {
            newValue = prevBookIndex + (diff / 4.0); // 1/4 지점
          } else {
            newValue = prevBookIndex + 0.25; // 0.25 단위로 조정
          }
        }
        debugPrint('🔍 다른 값 처리: prev=$prevBookIndex, next=$nextBookIndex, newValue=$newValue (타입: ${newValue.runtimeType})');
      }
      
      debugPrint('🔍 정밀한 중간값 계산: prev=$prevBookIndex, next=$nextBookIndex, newValue=$newValue');
    }
    
    // 이동된 책의 archived_order_index 업데이트 (double 타입 보장)
    // newValue가 double 타입인지 확인하고 강제로 double로 설정
    final finalValue = newValue.toDouble();
    movedBook['archived_order_index'] = finalValue;
    _localBooks[newIndex] = movedBook;
    
    debugPrint('🔍 타입 보장: newValue=$newValue (${newValue.runtimeType}) -> finalValue=$finalValue (${finalValue.runtimeType})');
    
    debugPrint('🔄 _onReorder - 배열 조작 후:');
    debugPrint('  위치 $newIndex: ${movedBook['id']} -> archived_order_index: ${movedBook['archived_order_index']} (이동된 책)');
    
    // 상태 업데이트
    setState(() {
      _hasLocalChanges = true;
      _movedBook = movedBook;
      _oldIndex = oldIndex;
      _newIndex = newIndex;
    });
    
    debugPrint('🔄 _onReorder 후 배열 상태:');
    for (int i = 0; i < _localBooks.length; i++) {
      final book = _localBooks[i];
      final isMoved = book['id'] == movedBookId;
      final orderIndex = book['archived_order_index'];
      debugPrint('  위치 $i: ${book['id']} -> archived_order_index: $orderIndex (타입: ${orderIndex.runtimeType})${isMoved ? ' (이동된 책)' : ''}');
    }
    
    // 즉시 저장
    _saveOrderImmediately();
  }

  /// 드래그 완료 시 즉시 저장 (간격 방식)
  Future<void> _saveOrderImmediately() async {
    if (_movedBook == null) {
      debugPrint('⚠️ _movedBook이 null이므로 저장 건너뜀');
      return;
    }

    debugPrint('🔄 순서 변경 즉시 저장 시작 (간격 방식) - 이동한 책: ${_movedBook!['id']}');
    
    // 현재 위치에서 이동된 책 찾기
    final newPosition = _localBooks.indexWhere((book) => book['id'] == _movedBook!['id']);
    if (newPosition == -1) {
      debugPrint('❌ 이동된 책을 찾을 수 없음');
      return;
    }

    // 이동된 책의 새로운 archived_order_index 값 (double 타입 보장)
    final rawValue = _movedBook!['archived_order_index'];
    final newValue = (rawValue as num).toDouble();
    
    debugPrint('📚 책 ${_movedBook!['id']}: newPosition=$newPosition, rawValue=$rawValue (${rawValue.runtimeType}), newValue=$newValue (${newValue.runtimeType})');
    
    try {
      // 이동된 책만 업데이트
      final oldValue = _movedBook!['archived_order_index'];
      
      await client
          .from('user_books')
          .update({'archived_order_index': newValue})
          .eq('id', _movedBook!['id']);
      
      debugPrint('📚 책 ${_movedBook!['id']}: archived_order_index ${oldValue} → ${newValue}');
      
      // 로컬 상태 업데이트 (double 타입 보장)
      final bookIndex = _localBooks.indexWhere((book) => book['id'] == _movedBook!['id']);
      if (bookIndex != -1) {
        final finalValue = newValue.toDouble();
        _localBooks[bookIndex]['archived_order_index'] = finalValue;
        debugPrint('📚 _localBooks 배열 업데이트: 위치 $bookIndex, archived_order_index: $finalValue (타입: ${finalValue.runtimeType})');
      }
      
      debugPrint('💾 DB 직접 업데이트 완료: 1개 책');
      
      // 변경사항 초기화
      setState(() {
        _hasLocalChanges = false;
        _movedBook = null;
        _oldIndex = null;
        _newIndex = null;
      });
      
      // 콜백 호출
      widget.onBooksChanged?.call(List<Map<String, dynamic>>.from(_localBooks));
      
      debugPrint('✅ 순서 변경 즉시 저장 완료: 1개 업데이트');
      
    } catch (e) {
      debugPrint('❌ 순서 저장 실패: $e');
    }
  }

  /// 탭을 떠날 때/저장 버튼 등에서 호출하면 서버에 일괄 반영 (간격 방식)
  Future<void> flushPendingChanges() async {
    if (!_hasLocalChanges) {
      debugPrint('🔄 flushPendingChanges: 변경사항 없음 (이미 즉시 저장됨)');
      return;
    }

    try {
      debugPrint('🔄 flushPendingChanges 시작 (간격 방식): ${_localBooks.length}개 책');
      
      // 변경된 순서만 추출하여 업데이트 (최적화)
      final updates = <Map<String, dynamic>>[];
      final currentOrder = _localBooks.map((b) => b['id'] as String).toList();

      for (int i = 0; i < _localBooks.length; i++) {
        final id = _localBooks[i]['id'];
        final originalIndex = originalOrder.indexOf(id);

        // 원래 순서와 다르거나, 원래 목록에 없던 새 책인 경우
        if (originalIndex != i) {
          // 현재 책이 이동할 새로운 위치
          final newPosition = i;
          
          // 이전 책과 다음 책의 archived_order_index 값
          double prev = 0.0;
          double next = 1000.0;
          
          if (newPosition > 0) {
            // 이전 책: newPosition-1 위치의 책
            prev = (_localBooks[newPosition - 1]['archived_order_index'] as num).toDouble();
            debugPrint('📚 책 $id: prev 찾음 - ${_localBooks[newPosition - 1]['id']} (위치: ${newPosition - 1}, 값: $prev)');
          }
          
          if (newPosition < _localBooks.length - 1) {
            // 다음 책: newPosition+1 위치의 책  
            next = (_localBooks[newPosition + 1]['archived_order_index'] as num).toDouble();
            debugPrint('📚 책 $id: next 찾음 - ${_localBooks[newPosition + 1]['id']} (위치: ${newPosition + 1}, 값: $next)');
          }
          
          // 새로운 값 = (prev + next) / 2.0 (double 타입 보장)
          final newValue = ((prev + next) / 2.0).toDouble();
          
          updates.add({
            'id': id,
            'archived_order_index': newValue, // double 타입 보장
          });

        }
      }


      // 🚀 직접 Supabase 백업 업데이트
      if (updates.isNotEmpty) {
        for (final update in updates) {
          final oldValue = _localBooks.firstWhere((book) => book['id'] == update['id'])['archived_order_index'];
          final newValue = update['archived_order_index'];
          
          await client
              .from('user_books')
              .update({'archived_order_index': newValue})
              .eq('id', update['id']);
              
          debugPrint('📚 책 ${update['id']}: archived_order_index ${oldValue} (${oldValue.runtimeType}) → ${newValue} (${newValue.runtimeType})');
        }
      }

      _hasLocalChanges = false;
      originalOrder = _localBooks.map((b) => b['id'] as String).toList();

      debugPrint('✅ flushPendingChanges 완료: ${updates.length}개 업데이트');

      // 상위 새로고침
      widget.onRefresh();
    } catch (e) {
      debugPrint('❌ flush 실패: $e');
    }
  }

  // ========== 자동 스크롤 (드래그 시) ==========

  void _startAutoScroll() {
    _isDragging = true;
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!_isDragging || _dragPosition == null) {
        timer.cancel();
        return;
      }
      _performAutoScroll();
    });
  }

  void _performAutoScroll() {
    if (!mounted || !_scrollController.hasClients) return;

    final screenHeight = MediaQuery.of(context).size.height;
    final scrollOffset = _scrollController.offset;
    final maxScroll = _scrollController.position.maxScrollExtent;

    if (_dragPosition!.dy < 120 && scrollOffset > 115) {
      _scrollController.animateTo(
        (scrollOffset - 35).clamp(0.0, maxScroll),
        duration: const Duration(milliseconds: 80),
        curve: Curves.easeOut,
      );
    } else if (_dragPosition!.dy > screenHeight - 66 &&
        scrollOffset < maxScroll - 56) {
      _scrollController.animateTo(
        (scrollOffset + 35).clamp(0.0, maxScroll),
        duration: const Duration(milliseconds: 80),
        curve: Curves.easeOut,
      );
    }
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _isDragging = false;
    _dragPosition = null;
  }

  // ========== 유틸/선반 ==========

  List<Widget> _buildShelves(int bookCount, double itemHeight) {
    const booksPerRow = 5;
    final shelfCount = (bookCount / booksPerRow).ceil();

    return List.generate(shelfCount, (i) {
      final shelfY = 90 + (itemHeight + 35) * i;
      return Positioned(
        top: shelfY,
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

  ButtonStyle _outlinedStyle(BuildContext context) {
    return ButtonStyle(
      foregroundColor: MaterialStateProperty.all(AppColors.black900),
      backgroundColor: MaterialStateProperty.all(Colors.white),
      overlayColor: MaterialStateProperty.resolveWith<Color?>(
            (states) =>
        states.contains(MaterialState.pressed) ? AppColors.black100 : null,
      ),
      side: MaterialStateProperty.all(
        const BorderSide(color: AppColors.black500, width: 1),
      ),
      shape: MaterialStateProperty.all(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      padding: MaterialStateProperty.all(
        const EdgeInsets.symmetric(horizontal: 9),
      ),
      minimumSize: MaterialStateProperty.all(const Size(0, 34)),
      textStyle: MaterialStateProperty.all(
        const TextStyle(fontSize: 12, fontWeight: FontWeight.w400, height: 1.0),
      ),
    );
  }

  // ========== UI ==========

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (_isInitialLoading)
          const Center(
            child: CircularProgressIndicator(color: AppColors.black900),
          )
        else
          SingleChildScrollView(
            controller: _scrollController,
            primary: false,
            padding: const EdgeInsets.fromLTRB(0, 21, 0, 21),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 헤더
                const Padding(
                  padding: EdgeInsets.only(left: 22),
                  child: _HeaderText(),
                ),
                const SizedBox(height: 13),

                

                // 상단 버튼
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 21),
                  child: Row(
                    children: [
                      const Expanded(child: SizedBox()),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            if (_totalCount >= 1000) {
                              showDialog(
                                context: context,
                                barrierDismissible: true,
                                builder: (BuildContext context) {
                                  return const AnnouncementDialog(
                                    title: '안내',
                                    body:
                                    '현재 보관함에 추가 가능한\n책의 한도는 1,000권이에요.\n더 많은 책을 추가하실 수 있도록\n빠른 시일 내로 확장해드릴게요!!\n독서를 좋아해 주셔서 감사합니다.',
                                  );
                                },
                              );
                              return;
                            }

                            setState(() => _isUpdatingBooks = true);
                            widget.onBookAdded?.call();

                            try {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                  const SearchBookScreen(fromTab: 'archive'),
                                ),
                              );
                              widget.onFocusMe?.call();

                              if (!mounted) return;
                              setState(() => _isUpdatingBooks = false);

                              if (result == true) {
                                // 서버 데이터 리프레시
                                await _refreshFromServer();
                              }
                            } catch (e) {
                              if (!mounted) return;
                              setState(() => _isUpdatingBooks = false);
                              debugPrint('❌ 책 추가 중 오류: $e');
                            }
                          },
                          style: _outlinedStyle(context),
                          child: const Text(
                            '책 추가 +',
                            style: TextStyle(
                                fontSize: 13,
                                color: AppColors.black900,
                                height: 1.25),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 안내 + 카운트
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '책을 눌러 후기를 수정하거나\n책을 길게 눌러 위치를 변경할 수 있어요.',
                        style:
                        TextStyle(fontSize: 12, color: AppColors.black500),
                      ),
                      Column(
                        children: [
                          const Text('',
                              style: TextStyle(
                                  fontSize: 12, color: AppColors.black500)),
                          Text(
                            '${_totalCount}권',
                            style: const TextStyle(
                                fontSize: 13, color: AppColors.black500),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 15),

                // 그리드 + 선반
                LayoutBuilder(
                  builder: (context, constraints) {
                    const crossAxisCount = 5;
                    const crossAxisSpacing = 11.7;
                    const itemAspectRatio = 98 / 145;
                    const bookPadding = 22.0;

                    final availableWidth =
                        constraints.maxWidth - (bookPadding * 2);
                    final totalSpacing =
                        crossAxisSpacing * (crossAxisCount - 1);
                    final itemWidth =
                        (availableWidth - totalSpacing) / crossAxisCount;
                    final itemHeight = itemWidth / itemAspectRatio;

                    return Stack(
                      children: [
                        // 드래그 자동 스크롤용 리스너
                        SizedBox(
                          width: double.infinity,
                          child: Padding(
                            padding:
                            const EdgeInsets.fromLTRB(22, 0, 22, 10),
                            child: Listener(
                              onPointerDown: (e) {
                                _isDragging = true;
                                _dragPosition = e.position;
                                _startAutoScroll();
                              },
                              onPointerMove: (e) {
                                if (_isDragging) _dragPosition = e.position;
                              },
                              onPointerUp: (_) => _stopAutoScroll(),
                              onPointerCancel: (_) => _stopAutoScroll(),
                              child: ReorderableWrap(
                                spacing: crossAxisSpacing,
                                runSpacing: 35,
                                needsLongPressDraggable: true,
                                onReorder: _onReorder,
                                buildDraggableFeedback:
                                    (context, c, child) {
                                  return Material(
                                    elevation: 8.0,
                                    color: Colors.transparent,
                                    child: child,
                                  );
                                },
                                children: _localBooks.map((book) {
                                  return GestureDetector(
                                    onTap: () async {
                                      final nav =
                                          widget.navigatorKey?.currentState;
                                      final screen = SinglePostScreen(
                                        bookId: book['book_id'] ?? '',
                                        userBookId: book['id'],
                                        userId:
                                        client.auth.currentUser?.id,
                                      );
                                      final result = nav != null
                                          ? await nav.push(MaterialPageRoute(
                                          builder: (_) => screen))
                                          : await Navigator.of(context).push(
                                          MaterialPageRoute(
                                              builder: (_) => screen));
                                      if (result == true) {
                                        await _refreshFromServer();
                                      }
                                    },
                                    child: SizedBox(
                                      key: ValueKey(book['id']),
                                      width: itemWidth,
                                      height: itemHeight,
                                      child: ClipRRect(
                                        borderRadius:
                                        BorderRadius.circular(0),
                                        child: BookFrame(
                                          imageUrl: (book['books']
                                          ?['image']) ??
                                              'https://via.placeholder.com150',
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ),

                        // 선반
                        ..._buildShelves(_localBooks.length, itemHeight),
                      ],
                    );
                  },
                ),

                // 페이지 하단 로딩 인디케이터
                if (_isPageLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: CircularProgressIndicator(
                          color: AppColors.black900),
                    ),
                  ),
                if (!_hasMore && !_isPageLoading)
                  const SizedBox(height: 16),
              ],
            ),
          ),

        if (_isUpdatingBooks)
          Container(
            color: Colors.black.withOpacity(0.7),
            child: const Center(
              child: CircularProgressIndicator(
                valueColor:
                AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 3,
              ),
            ),
          ),
      ],
    );
  }
}

class _HeaderText extends StatelessWidget {
  const _HeaderText();

  @override
  Widget build(BuildContext context) {
    return StrokeTextStyle.createStrokeText(
      text: "읽었던 책들을 보관함에 정리해보세요.",
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: AppColors.black900,
    );
  }
}