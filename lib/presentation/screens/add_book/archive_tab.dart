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

class ArchiveTab extends StatefulWidget {
  /// NOTE: 이제 서버 페이지네이션으로 불러오므로 allBooks는 선택사항이지만
  /// 기존 상위 코드 호환을 위해 남겨둠. (처음 렌더 속도 개선용 seed로도 사용 가능)
  final List<Map<String, dynamic>> allBooks;
  final VoidCallback onRefresh;
  final VoidCallback? onBookAdded;
  final Function(List<Map<String, dynamic>>)? onBooksChanged;
  final GlobalKey<NavigatorState>? navigatorKey;
  final VoidCallback? onFocusMe;

  const ArchiveTab({
    Key? key,
    required this.allBooks,
    required this.onRefresh,
    this.onBookAdded,
    this.onBooksChanged,
    this.navigatorKey,
    this.onFocusMe,
  }) : super(key: key);

  @override
  State<ArchiveTab> createState() => _ArchiveTabState();
}

class _ArchiveTabState extends State<ArchiveTab> {
  final client = Supabase.instance.client;

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
    // 초기 페이지 로드
    _refreshFromServer();
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
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
      setState(() => _isInitialLoading = false);
    }
  }

  Future<void> _loadNextPage() async {
    if (_isPageLoading || !_hasMore) return;

    setState(() {
      _isPageLoading = true;
    });

    try {
      // 1) RPC로 user_books 페이지 가져오기 (정렬/카운트 포함)
      final rpc = await client.rpc(
        'get_archived_books_page',
        params: {
          'p_limit': _pageSize,
          'p_offset': _offset,
          'p_only_archived': true, // 보관함만
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
        });
      }
    } catch (e) {
      debugPrint('❌ 페이지 로드 실패: $e');
    } finally {
      if (mounted) {
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

  // ========== 드래그 처리 (로컬만 변경, 저장은 flush에서) ==========

  void _onReorder(int oldIndex, int newIndex) {
    if (!mounted || oldIndex == newIndex) return;

    setState(() {
      final item = _localBooks.removeAt(oldIndex);
      _localBooks.insert(newIndex, item);
      _hasLocalChanges = true;
    });

    widget.onBooksChanged?.call(List<Map<String, dynamic>>.from(_localBooks));
  }

  /// 탭을 떠날 때/저장 버튼 등에서 호출하면 서버에 일괄 반영
  Future<void> flushPendingChanges() async {
    if (!_hasLocalChanges) return;

    try {
      for (int i = 0; i < _localBooks.length; i++) {
        final id = _localBooks[i]['id'];
        await client
            .from('user_books')
            .update({'archived_order_index': i})
            .eq('id', id);
      }
      _hasLocalChanges = false;
      originalOrder = _localBooks.map((b) => b['id'] as String).toList();

      // 상위 새로고침 + 첫 페이지 재로드(선택)
      widget.onRefresh();
      // await _refreshFromServer(); // 필요시 사용
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
                            if (_localBooks.length >= 1000) {
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
                            '${_localBooks.length}권',
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