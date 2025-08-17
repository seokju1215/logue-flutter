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
  final List<Map<String, dynamic>> books;
  final VoidCallback onRefresh;
  final VoidCallback? onBookAdded; // 책 추가 시 호출되는 콜백
  final GlobalKey<NavigatorState>? navigatorKey; // AddBookView의 Navigator에 접근하기 위한 키

  const ArchiveTab({
    Key? key,
    required this.books,
    required this.onRefresh,
    this.onBookAdded,
    this.navigatorKey,
  }) : super(key: key);

  @override
  State<ArchiveTab> createState() => _ArchiveTabState();
}

class _ArchiveTabState extends State<ArchiveTab> {
  final client = Supabase.instance.client;
  List<String> originalOrder = [];
  bool isEdited = false;
  
  // 스크롤 제어를 위한 ScrollController
  late ScrollController _scrollController;
  
  // 자동 스크롤을 위한 변수들
  bool _isDragging = false;
  Offset? _dragPosition;
  Timer? _autoScrollTimer;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _updateOriginalOrder();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _autoScrollTimer?.cancel();
    super.dispose();
  }

  void _updateOriginalOrder() {
    setState(() {
      originalOrder = widget.books.map((book) => book['id'] as String).toList();
      isEdited = false;
    });
  }

  Future<void> _updateBookOrder() async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;
    for (int i = 0; i < widget.books.length; i++) {
      final bookId = widget.books[i]['id'];
      await client
          .from('user_books')
          .update({'archived_order_index': i})
          .eq('id', bookId);
    }

    setState(() {
      originalOrder = widget.books.map((b) => b['id'] as String).toList();
      isEdited = false;
    });
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      final item = widget.books.removeAt(oldIndex);
      widget.books.insert(newIndex, item);

      final currentOrder = widget.books.map((b) => b['id'] as String).toList();
      isEdited = !_areListsEqual(currentOrder, originalOrder);
    });

    _updateBookOrder();
  }



  void _startAutoScroll() {
    _isDragging = true;
    _autoScrollTimer?.cancel();
    
    // 50ms마다 자동 스크롤 체크 (더 빠른 반응)
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
    final maxScrollExtent = _scrollController.position.maxScrollExtent;
    
    // 드래그 위치가 화면 상단 근처면 위로 스크롤
    if (_dragPosition!.dy < 150) {
      if (scrollOffset > 0) {
        _scrollController.animateTo(
          (scrollOffset - 35).clamp(0.0, maxScrollExtent),
          duration: const Duration(milliseconds: 80),
          curve: Curves.easeOut,
        );
      }
    }
    // 드래그 위치가 화면 하단 근처면 아래로 스크롤
    else if (_dragPosition!.dy > screenHeight - 150) {
      if (scrollOffset < maxScrollExtent) {
        _scrollController.animateTo(
          (scrollOffset + 35).clamp(0.0, maxScrollExtent),
          duration: const Duration(milliseconds: 80),
          curve: Curves.easeOut,
        );
      }
    }
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _isDragging = false;
    _dragPosition = null;
  }



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
            (states) {
          if (states.contains(MaterialState.pressed)) {
            return AppColors.black100;
          }
          return null;
        },
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
      minimumSize: MaterialStateProperty.all(
        const Size(0, 34),
      ),
      textStyle: MaterialStateProperty.all(
        const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          height: 1.0,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      primary: false,
      padding: const EdgeInsets.fromLTRB(0, 21, 0, 21),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(left: 22),
            child: StrokeTextStyle.createStrokeText(text: "읽었던 책들을 간편하게 정리해보세요.", fontSize: 16, fontWeight: FontWeight.w400, color: AppColors.black900)
          ),
          const SizedBox(height: 13),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 21),
            child: Row(
              children: [
                const Expanded(child: SizedBox()),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      // 1000권 제한 확인
                      if (widget.books.length >= 1000) {
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
                      
                      // 책 추가 시 로딩 상태 활성화
                      if (widget.onBookAdded != null) {
                        widget.onBookAdded!();
                      }
                      
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                          const SearchBookScreen(fromTab: 'archive'),
                        ),
                      );
                      if (result == true) widget.onRefresh();
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
                    Text(
                      '',
                      style: const TextStyle(fontSize: 12, color: AppColors.black500),
                    ),
                    Text(
                      '${widget.books.length}권',
                      style: const TextStyle(fontSize: 12, color: AppColors.black500),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),
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
                  // Stack의 최소 너비 확보용
                  SizedBox(
                    width: double.infinity,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(22, 0, 22, 10),
                                            child: Listener(
                        onPointerDown: (event) {
                          // 포인터 다운 시 드래그 시작
                          _isDragging = true;
                          _dragPosition = event.position;
                          _startAutoScroll();
                        },
                        onPointerMove: (event) {
                          // 포인터 이동 시 위치 업데이트
                          if (_isDragging) {
                            _dragPosition = event.position;
                          }
                        },
                        onPointerUp: (event) {
                          // 포인터 업 시 드래그 종료
                          _stopAutoScroll();
                        },
                        child: ReorderableWrap(
                          spacing: crossAxisSpacing,
                          runSpacing: 35,
                          needsLongPressDraggable: true,
                          onReorder: _onReorder,
                          // 드래그 중 자동 스크롤 활성화
                          buildDraggableFeedback: (context, constraints, child) {
                            return Material(
                              elevation: 8.0,
                              child: child,
                            );
                          },

                        children: widget.books.map((book) {
                          return GestureDetector(
                            onTap: () async {
                              // AddBookView의 Navigator를 통해 이동하여 하단 네비게이션바 유지
                              final navigatorState = widget.navigatorKey?.currentState;
                              if (navigatorState != null) {
                                final result = await navigatorState.push(
                                  MaterialPageRoute(
                                    builder: (_) => SinglePostScreen(
                                      bookId: book['book_id'] ?? '',
                                      userBookId: book['id'],
                                      userId: client.auth.currentUser?.id,
                                    ),
                                  ),
                                );
                                if (result == true) {
                                  widget.onRefresh();
                                }
                              } else {
                                // fallback: 기존 방식 사용
                                final result = await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => SinglePostScreen(
                                      bookId: book['book_id'] ?? '',
                                      userBookId: book['id'],
                                      userId: client.auth.currentUser?.id,
                                    ),
                                  ),
                                );
                                if (result == true) {
                                  widget.onRefresh();
                                }
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
                  ..._buildShelves(widget.books.length, itemHeight),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}