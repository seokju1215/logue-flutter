import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:my_logue/core/themes/app_colors.dart';
import 'package:my_logue/presentation/screens/add_book/search_book_screen.dart';
import 'package:reorderables/reorderables.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_logue/data/datasources/user_book_api.dart';
import 'package:my_logue/presentation/screens/home/home_recommand_tab.dart';

import '../../../core/themes/stroke_text_style.dart';
import '../../../core/widgets/book/book_frame.dart';
import '../../../core/widgets/dialogs/book_limit_dialog.dart';
import '../../../core/widgets/dialogs/archive_bottom_sheet.dart';
import '../../../data/models/book_model.dart';

class ProfileTab extends StatefulWidget {
  final bool isLimitReached;
  final List<Map<String, dynamic>> books;
  final List<Map<String, dynamic>> allBooks; // 모든 책 목록 (보관함 포함)
  final VoidCallback onRefresh;
  final Function(bool)? onBookAdded; // 책 추가 완료 콜백
  final GlobalKey<NavigatorState>? navigatorKey; // AddBookView의 Navigator에 접근하기 위한 키
  final Function(bool)? onLoadingStateChanged; // 로딩 상태 변경 콜백

  const ProfileTab({
    Key? key,
    required this.isLimitReached,
    required this.books,
    required this.allBooks,
    required this.onRefresh,
    this.onBookAdded,
    this.navigatorKey,
    this.onLoadingStateChanged,
  }) : super(key: key);

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  OverlayEntry? _loadingOverlay;
  final client = Supabase.instance.client;
  List<String> originalOrder = [];
  bool isEdited = false;
  final GlobalKey _titleKey = GlobalKey(); // 텍스트 위젯의 위치를 측정하기 위한 키
  bool _isUpdatingBooks = false; // 책 변경 로딩 상태

  @override
  void initState() {
    super.initState();
    _updateOriginalOrder();
  }

  @override
  void dispose() {
    _hideLoadingOverlay(); // ✅ 누수 방지
    super.dispose();
  }

  void _updateOriginalOrder() {
    setState(() {
      originalOrder = widget.books.map((book) => book['id'] as String).toList();
      isEdited = false;
    });
  }

  void _showLoadingOverlay() {
    if (_loadingOverlay != null) return; // 중복 방지
    _loadingOverlay = OverlayEntry(
      builder: (_) => Stack(
        children: [
          Positioned.fill(
            child: AbsorbPointer(
              absorbing: true,
              child: Container(color: Colors.black.withOpacity(0.35)),
            ),
          ),
          const Positioned.fill(
            child: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 3,
              ),
            ),
          ),
        ],
      ),
    );
    Overlay.of(context, rootOverlay: true)?.insert(_loadingOverlay!);
  }

  void _hideLoadingOverlay() {
    _loadingOverlay?.remove();
    _loadingOverlay = null;
  }

  Future<void> _updateBookOrder() async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    // NOTE: 프로필 그리드에서 순서만 바꿀 때는 간단히 per-row 업데이트 유지
    for (int i = 0; i < widget.books.length; i++) {
      final bookId = widget.books[i]['id'];
      await client.from('user_books').update({'order_index': i}).eq('id', bookId);
    }

    setState(() {
      originalOrder = widget.books.map((b) => b['id'] as String).toList();
      isEdited = false;
    });

    widget.onRefresh();
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

  bool _areListsEqual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// archived_order_index 기준으로 책들을 정렬하는 메서드
  List<Map<String, dynamic>> _getSortedBooks() {
    final sortedBooks = List<Map<String, dynamic>>.from(widget.allBooks);
    sortedBooks.sort((a, b) {
      final aOrder = a['archived_order_index'] as int? ?? 0;
      final bOrder = b['archived_order_index'] as int? ?? 0;
      return aOrder.compareTo(bOrder);
    });
    return sortedBooks;
  }

  /// 변경된 책만 추려서 RPC에 넘기기 위한 diff
  List<Map<String, dynamic>> _diffUserBooks({
    required List<Map<String, dynamic>> updated,   // 바텀시트 결과(보관함+프로필 전체 최신 상태)
    required List<Map<String, dynamic>> original,  // 기존 전체 상태(widget.allBooks)
  }) {
    final byId = { for (final o in original) o['id']: o };
    return updated.where((u) {
      final o = byId[u['id']];
      if (o == null) return true;
      final changedArchived = (o['is_archived'] as bool?) != (u['is_archived'] as bool?);
      final changedOrder = (o['order_index'] as int?) != (u['order_index'] as int?);
      return changedArchived || changedOrder;
    }).toList();
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
      textStyle: MaterialStateProperty.all(const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.0,
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SingleChildScrollView(
          primary: false,
          padding: const EdgeInsets.fromLTRB(0, 21, 0, 21),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 타이틀
              Padding(
                padding: const EdgeInsets.only(left: 22),
                child: Stack(
                  key: _titleKey,
                  children: [
                    StrokeTextStyle.createStrokeText(
                      text: "인생 책을 골라 프로필에 소개해보세요.",
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: AppColors.black900,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 13),

              // 버튼
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 21),
                child: Row(
                  children: [
                    const Expanded(child: SizedBox()),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          showModalBottomSheet(
                            context: context,
                            useRootNavigator: true,
                            isScrollControlled: true,
                            isDismissible: false,
                            backgroundColor: Colors.transparent,
                            barrierColor: Colors.transparent,
                            builder: (BuildContext context) {
                              final RenderBox? titleBox =
                              _titleKey.currentContext?.findRenderObject() as RenderBox?;
                              final titlePosition = titleBox?.localToGlobal(Offset.zero);
                              final titleBottom = titlePosition?.dy ?? 0;

                              return Stack(
                                children: [
                                  Positioned.fill(
                                    child: GestureDetector(
                                      onTap: () => Navigator.pop(context),
                                      child: Container(color: Colors.transparent),
                                    ),
                                  ),
                                  Positioned(
                                    top: titleBottom + (titleBox?.size.height ?? 0) + 8,
                                    left: 0,
                                    right: 0,
                                    bottom: 0,
                                    child: ArchiveBottomSheet(
                                      books: _getSortedBooks(),
                                      onClose: () {
                                        debugPrint('🔒 ArchiveBottomSheet 닫힘 - 선택 상태 초기화');
                                        setState(() {});
                                      },
                                      onBooksUpdated: (updatedBooks) async {
                                        if (!mounted) return;

                                        setState(() => _isUpdatingBooks = true);
                                        widget.onLoadingStateChanged?.call(true);
                                        _showLoadingOverlay();

                                        try {
                                          final api = UserBookApi(Supabase.instance.client);

                                          // 1) 변경된 것만 추림
                                          final changed = _diffUserBooks(
                                            updated: updatedBooks,
                                            original: widget.allBooks,
                                          );

                                          // 변경이 없으면 바로 종료
                                          if (changed.isEmpty) {
                                            widget.onLoadingStateChanged?.call(false);
                                            _hideLoadingOverlay();
                                            setState(() => _isUpdatingBooks = false);
                                            return;
                                          }

                                          // 2) RPC 한 번으로 일괄 업데이트
                                          await api.updateBooksBatchRPC(changed);

                                          // 3) 캐시 리프레시 (예외 무시)
                                          try {
                                            HomeRecommendTab.refreshUsersWithSameBooks();
                                          } catch (_) {}

                                          // 4) UI 갱신
                                          widget.onRefresh();
                                        } catch (e) {
                                          if (mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('저장 중 오류: $e')),
                                            );
                                          }
                                        } finally {
                                          if (mounted) {
                                            setState(() => _isUpdatingBooks = false);
                                            widget.onLoadingStateChanged?.call(false);
                                            _hideLoadingOverlay();
                                          }
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                        style: _outlinedStyle(context),
                        child: const Text(
                          '책 선택',
                          style: TextStyle(fontSize: 13, color: AppColors.black900, height: 1.25),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 33),

              // 안내 + 카운트
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('책을 길게 눌러 위치를 변경할 수 있어요.',
                        style: TextStyle(fontSize: 12, color: AppColors.black500)),
                    Text(
                      '${widget.books.where((book) => book['is_archived'] == false).length}/9',
                      style: const TextStyle(fontSize: 13, color: AppColors.black500),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 그리드 (ReorderableWrap)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 26),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    const crossAxisCount = 3;
                    const crossAxisSpacing = 23.0;
                    const mainAxisSpacing = 30.0;
                    const itemAspectRatio = 98 / 145;

                    final totalSpacing = crossAxisSpacing * (crossAxisCount - 1);
                    final itemWidth =
                        (constraints.maxWidth - totalSpacing) / crossAxisCount;
                    final itemHeight = itemWidth / itemAspectRatio;

                    return ReorderableWrap(
                      spacing: crossAxisSpacing,
                      runSpacing: mainAxisSpacing,
                      needsLongPressDraggable: true,
                      onReorder: _onReorder,
                      children: widget.books.map((book) {
                        return GestureDetector(
                          child: SizedBox(
                            key: ValueKey(book['id']),
                            width: itemWidth,
                            height: itemHeight,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(0),
                              child: BookFrame(
                                imageUrl:
                                book['books']?['image'] ?? 'https://via.placeholder.com/150',
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ),
            ],
          ),
        ),

        // 로딩 오버레이(필요 시)
        if (_isUpdatingBooks)
          Positioned.fill(
            child: AbsorbPointer(
              absorbing: true,
              child: Container(
                color: Colors.black.withOpacity(0.35),
                child: const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    strokeWidth: 3,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}