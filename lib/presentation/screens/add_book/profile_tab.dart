import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:my_logue/core/themes/app_colors.dart';
import 'package:my_logue/presentation/screens/add_book/search_book_screen.dart';
import 'package:reorderables/reorderables.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/themes/stroke_text_style.dart';
import '../../../core/widgets/book/book_frame.dart';
import '../../../core/widgets/dialogs/book_limit_dialog.dart';
import '../../../core/widgets/dialogs/archive_bottom_sheet.dart';
import '../../../data/models/book_model.dart';

class ProfileTab extends StatefulWidget {
  final bool isLimitReached;
  final List<Map<String, dynamic>> books;
  final VoidCallback onRefresh;
  final Function(bool)? onBookAdded; // 책 추가 완료 콜백
  final GlobalKey<NavigatorState>? navigatorKey; // AddBookView의 Navigator에 접근하기 위한 키
  
  const ProfileTab({
    Key? key, 
    required this.isLimitReached,
    required this.books,
    required this.onRefresh,
    this.onBookAdded,
    this.navigatorKey,
  }) : super(key: key);

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final client = Supabase.instance.client;
  List<String> originalOrder = [];
  bool isEdited = false;
  final GlobalKey _titleKey = GlobalKey(); // 텍스트 위젯의 위치를 측정하기 위한 키

  @override
  void initState() {
    super.initState();
    _updateOriginalOrder();
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
          .update({'order_index': i})
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
    
    // 드래그 앤 드롭 후 즉시 데이터베이스 업데이트
    _updateBookOrder();
  }

  bool _areListsEqual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
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
      primary: false,
      padding: const EdgeInsets.fromLTRB(0, 21, 0, 21),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 22),
            child: Stack(
              key: _titleKey, // GlobalKey 추가
              children: [
                StrokeTextStyle.createStrokeText(
                  text: "나만의 인생 책을 프로필에 추가해보세요.", 
                  fontSize: 16, 
                  fontWeight: FontWeight.w400, 
                  color: AppColors.black900
                ),
              ],
            ),
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
                      // 현재 책 개수로 limit 확인
                      if (widget.books.length >= 9) {
                        showDialog(
                          context: context,
                          builder: (_) => const BookLimitDialog(),
                        );
                      } else {
                        // ArchiveBottomSheet 표시
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          barrierColor: Colors.transparent,
                          builder: (BuildContext context) {
                            // GlobalKey를 사용하여 텍스트 위젯의 위치 측정
                            final RenderBox? titleBox = _titleKey.currentContext?.findRenderObject() as RenderBox?;
                            final titlePosition = titleBox?.localToGlobal(Offset.zero);
                            final titleBottom = titlePosition?.dy ?? 0;
                            
                            return Stack(
                              children: [
                                // 배경 터치 영역
                                Positioned.fill(
                                  child: GestureDetector(
                                    onTap: () => Navigator.pop(context),
                                    child: Container(color: Colors.transparent),
                                  ),
                                ),
                                // 바텀시트
                                Positioned(
                                  top: titleBottom + (titleBox?.size.height ?? 0) + 8, // 텍스트 위젯 바로 밑 + 8px
                                  left: 0,
                                  right: 0,
                                  bottom: 0,
                                  child: ArchiveBottomSheet(
                                    onClose: (result) {
                                      Navigator.pop(context);
                                      if (result == true) {
                                        // 책 추가가 완료되었을 때 상위로 결과 전달
                                        if (widget.onBookAdded != null) {
                                          widget.onBookAdded!(true);
                                        }
                                      }
                                    },
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      }
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '책을 길게 눌러 위치를 변경할 수 있어요.',
                  style: TextStyle(fontSize: 12, color: AppColors.black500),
                ),
                Text(
                  '${widget.books.length}/9',
                  style: const TextStyle(fontSize: 12, color: AppColors.black500),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 26),
            child: LayoutBuilder(
              builder: (context, constraints) {
                const crossAxisCount = 3;
                const crossAxisSpacing = 23.0;
                const mainAxisSpacing = 30.0;
                const itemAspectRatio = 98 / 145;

                final totalSpacing = crossAxisSpacing * (crossAxisCount - 1);
                final itemWidth = (constraints.maxWidth - totalSpacing) / crossAxisCount;
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
                            imageUrl: book['books']?['image'] ?? 'https://via.placeholder.com/150',
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
    );
  }
} 