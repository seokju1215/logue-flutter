import 'package:flutter/material.dart';
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

  Future<void> _saveReview() async {
    final user = client.auth.currentUser;
    if (user == null) return;

    final reviewTitle = _titleController.text.trim();
    final reviewContent = _contentController.text.trim();

    if (reviewTitle.length > 50 || reviewContent.length > 1000) return;

    setState(() => _isSaving = true);

    try {
      // 1. order_index 모두 +1 (한 쿼리로 처리)
      await client.rpc('increment_all_order_indices', params: {'uid': user.id});

      // 2. 새 책 추가
      await client.from('user_books').insert({
        'user_id': user.id,
        'title': widget.book.title,
        'author': widget.book.author,
        'publisher': widget.book.publisher,
        'image': widget.book.image,
        'order_index': 0,
        'review_title': reviewTitle,
        'review_content': reviewContent,
      });

      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainNavigationScreen(initialIndex: 1)),
              (route) => false,
        );
      }
    } catch (e) {
      debugPrint('❌ 책 저장 실패: $e');
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
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('후기 작성', style: TextStyle(fontSize: 18, color: AppColors.black900),),
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
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: SizedBox(
                width: 235,  // 원하는 너비
                height: 349, // 원하는 높이
                child: BookFrame(imageUrl: widget.book.image),
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: EdgeInsets.fromLTRB(13, 0, 0, 0),
              child: Text('후기 제목', style: TextStyle(fontSize: 12, color: AppColors.black500)),
            ),
            TextField(
              controller: _titleController,
              maxLength: 50,
              minLines: 2,
              maxLines: null,
              style: const TextStyle(fontSize: 14, color:AppColors.black900),
              decoration:  InputDecoration(
                contentPadding: const EdgeInsets.symmetric(vertical: 9, horizontal: 9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(5),
                  borderSide: const BorderSide(color: Colors.grey, width: 1),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(5),
                  borderSide: const BorderSide(color: Colors.grey),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(5),
                  borderSide: const BorderSide(color: Colors.grey), // ✅ hover나 focus에도 변화 없게
                ),

              ),
            ),
            const SizedBox(height: 16),
            const Text('후기 내용', style: TextStyle(fontSize: 12, color: AppColors.black500)),
            Expanded(
              child: TextField(
                controller: _contentController,
                maxLength: 1000,
                minLines: 3,
                maxLines: null,
                style: const TextStyle(fontSize: 14, color:AppColors.black900),
                decoration:  InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(vertical: 9, horizontal: 9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(5),
                    borderSide: const BorderSide(color: Colors.grey, width: 1),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(5),
                    borderSide: const BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(5),
                    borderSide: const BorderSide(color: Colors.grey), // ✅ hover나 focus에도 변화 없게
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}