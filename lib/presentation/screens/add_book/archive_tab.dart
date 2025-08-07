import 'package:flutter/material.dart';
import 'package:my_logue/core/themes/app_colors.dart';
import 'package:my_logue/presentation/screens/add_book/search_book_screen.dart';
import 'package:my_logue/presentation/screens/post/single_post_screen.dart';
import 'package:reorderables/reorderables.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/widgets/book/book_frame.dart';

class ArchiveTab extends StatefulWidget {
  const ArchiveTab({Key? key}) : super(key: key);

  @override
  State<ArchiveTab> createState() => _ArchiveTabState();
}

class _ArchiveTabState extends State<ArchiveTab> {

  final client = Supabase.instance.client;
  List<Map<String, dynamic>> books = [];
  List<String> originalOrder = [];
  bool isEdited = false;

  @override
  void initState() {
    super.initState();
    _fetchBooks();
  }

  Future<void> _fetchBooks() async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      // 보관함에서는 모든 책을 가져오기 (is_archived 상관없이)
      final data = await client
          .from('user_books')
          .select('id, user_id, order_index, archived_order_index, is_archived, books(image)')
          .eq('user_id', userId)
          .order('archived_order_index', ascending: true);

      final fetched = List<Map<String, dynamic>>.from(data);
      setState(() {
        books = fetched;
        originalOrder = fetched.map((book) => book['id'] as String).toList();
        isEdited = false;
      });
    } catch (e) {
      debugPrint('❌ 책 불러오기 실패: $e');
    }
  }

  Future<void> _updateBookOrder() async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;
    for (int i = 0; i < books.length; i++) {
      final bookId = books[i]['id'];
      await client
          .from('user_books')
          .update({'archived_order_index': i})
          .eq('id', bookId);
    }

    setState(() {
      originalOrder = books.map((b) => b['id'] as String).toList();
      isEdited = false;
    });
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      final item = books.removeAt(oldIndex);
      books.insert(newIndex, item);

      final currentOrder = books.map((b) => b['id'] as String).toList();
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

  List<Widget> _buildShelves(int bookCount, double itemWidth, double spacing, double itemHeight) {
    const booksPerRow = 5;
    final List<Widget> shelves = [];
    
    // 필요한 선반 개수 계산
    final shelfCount = (bookCount / booksPerRow).ceil();
    
    for (int i = 0; i < shelfCount; i++) {
      // 선반의 Y 위치 계산 (책 높이 + 간격)
      final shelfY =90 + (itemHeight + 35) * i;
      
      shelves.add(
        Positioned(
          top: shelfY,
          left: 22,
          right: 22,
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
        ),
      );
    }
    
    return shelves;
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
      padding: const EdgeInsets.fromLTRB(0, 27, 0, 27),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 22),
            child: Text(
              '살면서 읽었던 책들을 보관함에 정리해보세요.',
              style: TextStyle(fontSize: 16, color: AppColors.black900),
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
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const SearchBookScreen(fromTab: 'archive')),
                      );
                      if (result == true) {
                        _fetchBooks();
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
          const SizedBox(height: 19),
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
                  '${books.length}권',
                  style: const TextStyle(fontSize: 12, color: AppColors.black500),
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),
          LayoutBuilder(
            builder: (context, constraints) {
              const crossAxisCount = 5;
              const crossAxisSpacing = 11.7;
              const mainAxisSpacing = 20.0;
              const itemAspectRatio = 98 / 145;
              const bookPadding = 22.0; // 책들에 적용되는 패딩

              // 패딩을 고려한 실제 사용 가능한 너비 계산
              final availableWidth = constraints.maxWidth - (bookPadding * 2);
              final totalSpacing = crossAxisSpacing * (crossAxisCount - 1);
              final itemWidth = (availableWidth - totalSpacing) / crossAxisCount;
              final itemHeight = itemWidth / itemAspectRatio;

              return Stack(
                children: [
                  // 책들을 ReorderableWrap으로 배치
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 0, 22, 10),
                    child: ReorderableWrap(
                      spacing: crossAxisSpacing,
                      runSpacing: 35, // 선반 높이 + 간격
                      needsLongPressDraggable: false,
                      onReorder: _onReorder,
                      children: books.map((book) {
                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => SinglePostScreen(
                                  bookId: book['book_id'] ?? '',
                                  userBookId: book['id'],
                                  userId: client.auth.currentUser?.id,
                                ),
                              ),
                            );
                          },
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
                    ),
                  ),
                  // 선반들을 오버레이로 배치
                  ..._buildShelves(books.length, itemWidth, crossAxisSpacing, itemHeight),
                ],
              );
            },
          ),

        ],
      ),
    );
  }
}
