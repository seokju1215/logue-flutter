import 'package:flutter/material.dart';
import 'package:logue/core/themes/app_colors.dart';
import 'package:logue/presentation/screens/profile/add_book/search_book_screen.dart';
import 'package:reorderables/reorderables.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/widgets/dialogs/book_limit_dialog.dart';

class AddBookScreen extends StatefulWidget {
  const AddBookScreen({Key? key}) : super(key: key);

  @override
  State<AddBookScreen> createState() => _AddBookScreenState();
}

class _AddBookScreenState extends State<AddBookScreen> {
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
      final data = await client
          .from('user_books')
          .select('id, user_id, order_index, books(image)')
          .eq('user_id', userId)
          .order('order_index', ascending: true);

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
          .update({'order_index': i})
          .eq('id', bookId);
    }

    setState(() {
      originalOrder = books.map((b) => b['id'] as String).toList();
      isEdited = false;
    });

    if (context.mounted) Navigator.pop(context, true);
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      final item = books.removeAt(oldIndex);
      books.insert(newIndex, item);

      final currentOrder = books.map((b) => b['id'] as String).toList();
      isEdited = !_areListsEqual(currentOrder, originalOrder);
    });
  }

  bool _areListsEqual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('내 책장'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: isEdited ? _updateBookOrder : null,
            child: Text(
              '확인',
              style: TextStyle(
                color: isEdited ? AppColors.blue500 : AppColors.black300,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        primary: false,
        padding: const EdgeInsets.fromLTRB(0, 27, 0, 27),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 22),
              child: Text(
                '지금의 당신을 만든 인생 책은 무엇인가요?',
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
                      onPressed: () {
                        if (books.length >= 9) {
                          showDialog(
                            context: context,
                            builder: (_) => const BookLimitDialog(),
                          );
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const SearchBookScreen()),
                          );
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.black900,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5),
                        ),
                        side: const BorderSide(color: AppColors.black900),
                        minimumSize: const Size.fromHeight(40),
                      ),
                      child: const Text(
                        '책 추가 +',
                        style:
                        TextStyle(fontSize: 12, color: AppColors.black900),
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
                    '책을 눌러 위치를 변경할 수 있어요.',
                    style: TextStyle(fontSize: 12, color: AppColors.black500),
                  ),
                  Text(
                    '${books.length}/9',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.black500),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 21),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const spacing = 8.0;
                  const crossAxisCount = 3;
                  final totalSpacing = spacing * (crossAxisCount - 1);
                  final itemWidth =
                      (constraints.maxWidth - totalSpacing) / crossAxisCount;

                  return ReorderableWrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    needsLongPressDraggable: false,
                    onReorder: _onReorder,
                    children: books.map((book) {
                      return SizedBox(
                        key: ValueKey(book['id']),
                        width: itemWidth,
                        child: AspectRatio(
                          aspectRatio: 0.7,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(0),
                            child: Image.network(
                              book['books']?['image'] ??
                                  'https://via.placeholder.com/150',
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey[300],
                                  child: const Icon(Icons.broken_image),
                                );
                              },
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
    );
  }
}