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
// import '../../../data/datasources/user_book_api.dart'; // ← 탭에서 나갈 때 배치 저장용(필요 시 사용)

class ArchiveTab extends StatefulWidget {
  final List<Map<String, dynamic>> books;
  final VoidCallback onRefresh;
  final VoidCallback? onBookAdded;
  final Function(List<Map<String, dynamic>>)? onBooksChanged;
  final GlobalKey<NavigatorState>? navigatorKey;

  const ArchiveTab({
    Key? key,
    required this.books,
    required this.onRefresh,
    this.onBookAdded,
    this.onBooksChanged,
    this.navigatorKey,
  }) : super(key: key);

  @override
  State<ArchiveTab> createState() => _ArchiveTabState();
}

class _ArchiveTabState extends State<ArchiveTab> {
  final client = Supabase.instance.client;

  // 로컬 상태
  late List<Map<String, dynamic>> _localBooks;
  List<String> originalOrder = [];
  bool _hasLocalChanges = false; // 변경이 남아있는 동안 외부 동기화 잠금

  // UI 상태
  bool _isUpdatingBooks = false;

  // 스크롤/자동 스크롤
  late ScrollController _scrollController;
  bool _isDragging = false;
  Offset? _dragPosition;
  Timer? _autoScrollTimer;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _localBooks = List<Map<String, dynamic>>.from(widget.books);
    originalOrder = _localBooks.map((b) => b['id'] as String).toList();
  }

  @override
  void didUpdateWidget(ArchiveTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // ✅ 변경 보유 중이면 외부 리스트 무시 (되돌림 방지)
    if (_hasLocalChanges) return;

    // 외부 데이터가 실제로 바뀐 경우만 반영
    final incoming = widget.books.map((b) => b['id'] as String).toList();
    final current  = _localBooks.map((b) => b['id'] as String).toList();
    if (!_areListsEqual(incoming, current)) {
      _localBooks = List<Map<String, dynamic>>.from(widget.books);
      originalOrder = _localBooks.map((b) => b['id'] as String).toList();
      setState(() {});
    }
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  // ===== 드래그 처리: 로컬만 변경, DB 호출 금지 =====
  void _onReorder(int oldIndex, int newIndex) {
    if (!mounted) return;

    // 불변 업데이트
    final newList = List<Map<String, dynamic>>.from(_localBooks);
    final item = newList.removeAt(oldIndex);
    newList.insert(newIndex, item);

    setState(() {
      _localBooks = newList;
      _hasLocalChanges = true; // ← 변경 보유 플래그: 외부 동기화 잠금
    });

    // 필요 시 부모에 로컬 순서 변경 알려주기
    widget.onBooksChanged?.call(newList);

    // ❌ 여기서 DB 업데이트 금지!
    // _updateBookOrderWithList(newList); // 제거
  }

  // ===== 외부에서 호출해 저장: 탭을 떠날 때 한 번만(권장) =====
  // 부모 탭 컨테이너에서 onTabChanged/onLeave 등에 연결해서 호출하세요.
  Future<void> flushPendingChanges() async {
    if (!_hasLocalChanges) return;

    try {
      // payload 준비
      final updates = <Map<String, dynamic>>[];
      for (int i = 0; i < _localBooks.length; i++) {
        updates.add({'id': _localBooks[i]['id'], 'archived_order_index': i});
      }

      // ① RPC가 있다면:
      // await client.rpc('update_user_books_archived_order_batch', params: {'_items': updates});

      // ② 없다면 간단 루프:
      for (final u in updates) {
        await client
            .from('user_books')
            .update({'archived_order_index': u['archived_order_index']})
            .eq('id', u['id']);
      }

      // 성공 → 기준 갱신 & 잠금 해제
      originalOrder = _localBooks.map((b) => b['id'] as String).toList();
      _hasLocalChanges = false;

      // 부모 새로고침
      widget.onRefresh();
    } catch (e) {
      // 실패해도 로컬 상태는 유지 (다음에 다시 저장 가능)
      debugPrint('❌ flush 실패: $e');
    }
  }

  // ===== 자동 스크롤 =====
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
    if (!mounted) return;

    final screenHeight = MediaQuery.of(context).size.height;
    final scrollOffset = _scrollController.offset;
    final maxScroll = _scrollController.position.maxScrollExtent;

    if (_dragPosition!.dy < 150 && scrollOffset > 0) {
      _scrollController.animateTo(
        (scrollOffset - 35).clamp(0.0, maxScroll),
        duration: const Duration(milliseconds: 80),
        curve: Curves.easeOut,
      );
    } else if (_dragPosition!.dy > screenHeight - 150 && scrollOffset < maxScroll) {
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

  // ===== 유틸 =====
  bool _areListsEqual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

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
          width: double.infinity,
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
            (states) => states.contains(MaterialState.pressed) ? AppColors.black100 : null,
      ),
      side: MaterialStateProperty.all(const BorderSide(color: AppColors.black500, width: 1)),
      shape: MaterialStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(5))),
      padding: MaterialStateProperty.all(const EdgeInsets.symmetric(horizontal: 9)),
      minimumSize: MaterialStateProperty.all(const Size(0, 34)),
      textStyle: MaterialStateProperty.all(
        const TextStyle(fontSize: 12, fontWeight: FontWeight.w400, height: 1.0),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SingleChildScrollView(
          controller: _scrollController,
          primary: false,
          padding: const EdgeInsets.fromLTRB(0, 21, 0, 21),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 22),
                child: StrokeTextStyle.createStrokeText(
                  text: "읽었던 책들을 보관함에 정리해보세요.",
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: AppColors.black900,
                ),
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
                                  body: '현재 보관함에 추가 가능한\n책의 한도는 1,000권이에요.\n더 많은 책을 추가하실 수 있도록\n빠른 시일 내로 확장해드릴게요!!\n독서를 좋아해 주셔서 감사합니다.',
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
                                builder: (_) => const SearchBookScreen(fromTab: 'archive'),
                              ),
                            );

                            if (!mounted) return;
                            setState(() => _isUpdatingBooks = false);

                            if (result == true) {
                              widget.onRefresh();
                            }
                          } catch (e) {
                            if (!mounted) return;
                            setState(() => _isUpdatingBooks = false);
                            debugPrint('❌ 책 추가 중 오류 발생: $e');
                          }
                        },
                        style: _outlinedStyle(context),
                        child: const Text(
                          '책 추가 +',
                          style: TextStyle(fontSize: 13, color: AppColors.black900, height: 1.25),
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
                      style: TextStyle(fontSize: 12, color: AppColors.black500),
                    ),
                    Column(
                      children: [
                        const Text('', style: TextStyle(fontSize: 12, color: AppColors.black500)),
                        Text(
                          '${_localBooks.length}권',
                          style: const TextStyle(fontSize: 13, color: AppColors.black500),
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

                  final availableWidth = constraints.maxWidth - (bookPadding * 2);
                  final totalSpacing = crossAxisSpacing * (crossAxisCount - 1);
                  final itemWidth = (availableWidth - totalSpacing) / crossAxisCount;
                  final itemHeight = itemWidth / itemAspectRatio;

                  return Stack(
                    children: [
                      // 드래그 자동 스크롤용 리스너
                      SizedBox(
                        width: double.infinity,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(22, 0, 22, 10),
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
                              buildDraggableFeedback: (context, c, child) {
                                return Material(
                                  elevation: 8.0,
                                  color: Colors.transparent,
                                  child: child,
                                );
                              },
                              children: _localBooks.map((book) {
                                return GestureDetector(
                                  onTap: () async {
                                    final nav = widget.navigatorKey?.currentState;
                                    if (nav != null) {
                                      final result = await nav.push(
                                        MaterialPageRoute(
                                          builder: (_) => SinglePostScreen(
                                            bookId: book['book_id'] ?? '',
                                            userBookId: book['id'],
                                            userId: client.auth.currentUser?.id,
                                          ),
                                        ),
                                      );
                                      if (result == true) widget.onRefresh();
                                    } else {
                                      final result = await Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => SinglePostScreen(
                                            bookId: book['book_id'] ?? '',
                                            userBookId: book['id'],
                                            userId: client.auth.currentUser?.id,
                                          ),
                                        ),
                                      );
                                      if (result == true) widget.onRefresh();
                                    }
                                  },
                                  child: SizedBox(
                                    key: ValueKey(book['id']),
                                    width: itemWidth,
                                    height: itemHeight,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(0),
                                      child: BookFrame(
                                        imageUrl: book['books']?['image'] ??
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
                      ..._buildShelves(_localBooks.length, itemHeight),
                    ],
                  );
                },
              ),
            ],
          ),
        ),

        if (_isUpdatingBooks)
          Container(
            color: Colors.black.withOpacity(0.7),
            child: const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 3,
              ),
            ),
          ),
      ],
    );
  }
}