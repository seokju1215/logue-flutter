import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:logue/core/themes/app_colors.dart';
import 'package:logue/data/models/book_model.dart';
import 'package:logue/core/widgets/book/book_frame.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logue/presentation/screens/main_navigation_screen.dart';

class WriteReviewScreen extends StatefulWidget {
  final BookModel book;

  const WriteReviewScreen({Key? key, required this.book}) : super(key: key);

  @override
  State<WriteReviewScreen> createState() => _WriteReviewScreenState();
}

class _WriteReviewScreenState extends State<WriteReviewScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final client = Supabase.instance.client;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController.addListener(() => setState(() {}));
    _contentController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _saveReview() async {
    final user = client.auth.currentUser;
    if (user == null) return;

    final reviewTitle = _titleController.text.trim();
    final reviewContent = _contentController.text.trim();

    if (reviewTitle.length > 50 || reviewContent.length > 1000) return;

    setState(() => _isSaving = true);

    try {
      String? bookId;

      if (widget.book.isbn.isNotEmpty) {
        final existingByIsbn = await client
            .from('books')
            .select('id')
            .eq('isbn', widget.book.isbn)
            .maybeSingle();
        if (existingByIsbn != null) bookId = existingByIsbn['id'];
      }

      if (bookId == null) {
        final existingByInfo = await client
            .from('books')
            .select('id')
            .eq('title', widget.book.title)
            .eq('author', widget.book.author)
            .maybeSingle();
        if (existingByInfo != null) bookId = existingByInfo['id'];
      }

      if (bookId == null) {
        print("api ${widget.book.link}");
        final inserted = await client
            .from('books')
            .insert({
          'isbn': widget.book.isbn,
          'title': widget.book.title,
          'subtitle': widget.book.subtitle ?? '',
          'author': widget.book.author,
          'publisher': widget.book.publisher,
          'published_date': widget.book.publishedDate,
          'page_count': widget.book.pageCount,
          'description': widget.book.description,
          'toc': widget.book.toc,
          'image': widget.book.image,
          'link': widget.book.link,
        })
            .select('id')
            .maybeSingle();
        bookId = inserted?['id'];
      }

      if (bookId == null) throw Exception('책 ID를 확보할 수 없습니다.');

      await client.rpc('increment_all_order_indices', params: {'uid': user.id});

// ✅ Edge Function 호출
      final FunctionResponse response = await client.functions.invoke('add-user-book-and-notify', body: {
        'user_id': user.id,
        'book_id': bookId,
        'isbn': widget.book.isbn,
        'review_title': reviewTitle,
        'review_content': reviewContent,
      });

      if (response.status != 200) {
        final errorMessage = response.data['error'] ?? '알 수 없는 오류';
        debugPrint('❌ 함수 오류: $errorMessage');
        throw Exception(errorMessage);
      }



      if (!mounted) return;

      Navigator.pop(context);
      Navigator.pop(context);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      });

    } catch (e) {
      debugPrint('❌ 저장 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('저장에 실패했어요. 다시 시도해주세요.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        centerTitle: true,
        leading: IconButton(
          icon: SvgPicture.asset('assets/back_arrow.svg'),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '책 추가',
          style: TextStyle(fontSize: 16, color: AppColors.black900),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveReview,
            child: Text(
              '확인',
              style: TextStyle(
                color: _isSaving ? Colors.grey : const Color(0xFF0055FF),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: SizedBox(
                    width: 235,
                    height: 349,
                    child: BookFrame(imageUrl: widget.book.image),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left:9),
                      child: const Text('후기 제목',
                          style: TextStyle(fontSize: 12, color: AppColors.black500)),
                    ),
                    Text(
                      '${_titleController.text.length}/50',
                      style: const TextStyle(fontSize: 12, color: AppColors.black500),
                    ),
                  ],
                ),
                TextField(
                  buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                  controller: _titleController,
                  maxLength: 50,
                  minLines: 2,
                  maxLines: null,
                  style: const TextStyle(fontSize: 14, color: AppColors.black900),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(vertical: 9, horizontal: 9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(5),
                      borderSide: const BorderSide(color: Colors.grey),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left:9),
                      child: const Text('후기 내용',
                          style: TextStyle(fontSize: 12, color: AppColors.black500)),
                    ),
                    Text(
                      '${_contentController.text.length}/1000',
                      style: const TextStyle(fontSize: 12, color: AppColors.black500),
                    ),
                  ],
                ),
                TextField(
                  buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                  controller: _contentController,
                  maxLength: 1000,
                  minLines: 3,
                  maxLines: null,
                  style: const TextStyle(fontSize: 14, color: AppColors.black900),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(vertical: 9, horizontal: 9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(5),
                      borderSide: const BorderSide(color: Colors.grey),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}