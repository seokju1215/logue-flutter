import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:logue/core/themes/app_colors.dart';
import 'package:logue/presentation/screens/profile/add_book/search_book_screen.dart';
import 'package:reorderables/reorderables.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/widgets/book/book_frame.dart';
import '../../../../core/widgets/dialogs/book_limit_dialog.dart';
import '../../../../data/utils/mixpanel_util.dart';

class AddBookScreen extends StatefulWidget {
  final bool isLimitReached;
  const AddBookScreen({Key? key, required this.isLimitReached, }) : super(key: key);

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
    
    // 책 추가 화면 방문 트래킹
    MixpanelUtil.trackScreenView('Add Book');
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
        EdgeInsets.symmetric(horizontal: 9),
      ),
      minimumSize: MaterialStateProperty.all(
        const Size(0, 34), // ✅ 원하는 높이로 강제 지정
      ),
      textStyle: MaterialStateProperty.all(
        const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          height: 1.0, // ✅ 텍스트 줄 간격 없애기
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('책 추가', style: const TextStyle(color: AppColors.black900, fontSize: 16),),
        leading: IconButton(
          icon: SvgPicture.asset('assets/back_arrow.svg'),
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
                        if (widget.isLimitReached) {
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
                      style:_outlinedStyle(context),
                      child: const Text(
                        '책 추가 +',
                        style:
                        TextStyle(fontSize: 13, color: AppColors.black900, height: 1.25),
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
                    needsLongPressDraggable: false,
                    onReorder: _onReorder,
                    children: books.map((book) {
                      return SizedBox(
                        key: ValueKey(book['id']),
                        width: itemWidth,
                        height: itemHeight,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(0),
                          child: BookFrame(
                            imageUrl: book['books']?['image'] ?? 'https://via.placeholder.com/150',
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