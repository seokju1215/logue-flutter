import 'dart:async';
import 'package:flutter/material.dart';
import 'package:my_logue/core/themes/app_colors.dart';
import 'package:my_logue/core/widgets/book/book_frame.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ArchiveBottomSheet extends StatefulWidget {
  final List<Map<String, dynamic>> allBooks; // 모든 책 목록 (최신 상태)
  final Function(List<Map<String, dynamic>>)? onBooksUpdated; // 저장 시에만 호출
  final VoidCallback? onClose; // 완전히 닫을 때만 호출

  const ArchiveBottomSheet({
    super.key,
    required this.allBooks,
    this.onBooksUpdated,
    this.onClose,
  });

  @override
  State<ArchiveBottomSheet> createState() => _ArchiveBottomSheetState();
}

class _ArchiveBottomSheetState extends State<ArchiveBottomSheet> {
  final client = Supabase.instance.client;

  // ===== 페이지네이션 상태 =====
  static const int _pageSize = 200;
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
  int selectedBookCount = 0;

  // 스크롤 컨트롤러
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScrollReachBottom);

    // 초기 페이지 로드
    _refreshFromServer();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScrollReachBottom);
    _scrollController.dispose();
    super.dispose();
  }

  // ========== 서버 호출 ==========

  Future<void> _refreshFromServer() async {
    setState(() {
      _isInitialLoading = true;
      _offset = 0;
      _localBooks.clear();
      _hasMore = true;
      _totalCount = 0;
      _hasLocalChanges = false;
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

      // 3) rows + image merge
      final pageItems = rows.map((e) {
        final bookId = e['book_id'];
        return {
          ...e,
          'books': imagesByBookId[bookId] ?? {'id': bookId, 'image': null},
        };
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
    selectedBookCount = _selected.length;
    debugPrint('🔄 자동 선택 업데이트: ${selectedBookCount}개 책이 선택됨');
  }

  // allBooks에서 보관함 책들만 필터링하여 반환 (기존 로직 유지)
  List<Map<String, dynamic>> _getArchivedBooks() {
    return _localBooks.toList()
      ..sort((a, b) {
        final aIndex = a['archived_order_index'] ?? 0;
        final bIndex = b['archived_order_index'] ?? 0;
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

  void _toggleSelect(int index) {
    // 디버깅: 선택 전 데이터 구조 확인
    debugPrint('🔍 _toggleSelect 시작 - index: $index');
    debugPrint(
        '🔍 선택 전 _localBooks[$index]: ID=${_localBooks[index]['id']}, book_id=${_localBooks[index]['book_id']}, is_archived=${_localBooks[index]['is_archived']}');

    setState(() {
      final currentSelected = _selected.length;

      if (_selected.contains(index)) {
        _selected.remove(index);
        _localBooks[index]['is_archived'] = true;

        final removedOrderIndex = _localBooks[index]['order_index'];
        _localBooks[index]['order_index'] = null;

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
        if (currentSelected >= kMaxSelection) return;

        _selected.add(index);
        _localBooks[index]['is_archived'] = false;

        for (int i = 0; i < _localBooks.length; i++) {
          if (i == index) continue;
          final oi = _localBooks[i]['order_index'];
          if (oi != null && oi is int) {
            _localBooks[i]['order_index'] = oi + 1;
          }
        }
        _localBooks[index]['order_index'] = 0;
      }

      selectedBookCount = _selected.length;

      // 디버깅: 선택 후 데이터 구조 확인
      debugPrint(
          '🔍 선택 후 _localBooks[$index]: ID=${_localBooks[index]['id']}, book_id=${_localBooks[index]['book_id']}, is_archived=${_localBooks[index]['is_archived']}');
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
        }
      }

      if (newlyUnarchivedBookIds.isNotEmpty) {
        final nowUtc = DateTime.now().toUtc().toIso8601String();
        await client.from('user_books').update(
            {'unarchived_at': nowUtc}).inFilter('id', newlyUnarchivedBookIds);

        debugPrint(
            '✅ unarchived_at 업데이트 완료: ${newlyUnarchivedBookIds.length}개');
      } else {
        debugPrint('ℹ️ 새로 unarchived된 책 없음');
      }

      return newlyUnarchivedBookIds;
    } catch (e) {
      debugPrint('❌ unarchived_at 업데이트 실패: $e');
      return [];
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
            padding: const EdgeInsets.fromLTRB(12, 28, 12, 15),
            child: Stack(
              children: [
                Center(
                  child: Text(
                    '보관함',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.black900,
                      fontWeight: FontWeight.w400,
                      height: 1.1875,
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

                            // 2) 알림 전송 (서버에서 팔로워 조회 + 대량 insert)
                            if (newlyUnarchivedIds.isNotEmpty) {
                              final resp = await client.functions.invoke(
                                'send-notification-v2',
                                body: {
                                  'sender_id': userId,
                                  'type': 'post',
                                  // 필요에 따라 'post' 등으로 변경 가능
                                  'user_book_ids': newlyUnarchivedIds,
                                },
                              );
                              if (resp.status != 200) {
                                debugPrint('❌ 알림 전송 실패: ${resp.data}');
                                // 실패해도 UX 계속 진행할지 여부는 선택. 여기선 진행.
                              } else {
                                debugPrint('✅ 알림 전송 성공: ${resp.data}');
                              }
                            }

                            // 3) 상위로 최신 상태 전달 & 시트 닫기
                            widget.onBooksUpdated?.call(
                              _localBooks
                                  .map((e) => Map<String, dynamic>.from(e))
                                  .toList(),
                            );
                            widget.onClose?.call();
                            if (mounted) Navigator.pop(context, true);
                          } catch (e) {
                            debugPrint('❌ 저장 처리 실패: $e');
                            if (mounted) Navigator.pop(context, false);
                          } finally {
                            if (mounted) setState(() => _isSaving = false);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 0), // 👈 클릭 영역 확장
                          color: Colors.transparent, // 👈 배경은 투명
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
                      Text(
                        '$selectedBookCount/9',
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
                Text(
                  '$selectedBookCount/9',
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
