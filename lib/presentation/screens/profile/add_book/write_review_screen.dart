import 'package:flutter/material.dart';
import 'package:logue/core/themes/app_colors.dart';
import 'package:logue/data/models/book_model.dart';
import 'package:logue/core/widgets/book/book_frame.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/profile',
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
        title: const Text('후기 작성'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveReview,
            child: Text(
              '확인',
              style: TextStyle(
                color: _isSaving ? Colors.grey : const Color(0xFF0055FF),
                fontWeight: FontWeight.w600,
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
              child: BookFrame(imageUrl: widget.book.image),
            ),
            const SizedBox(height: 24),
            const Text('후기 제목 (최대 50자)', style: TextStyle(fontSize: 14)),
            TextField(
              controller: _titleController,
              maxLength: 50,
              decoration: const InputDecoration(
                hintText: '이 책을 한 줄로 요약해본다면?',
              ),
            ),
            const SizedBox(height: 16),
            const Text('후기 내용 (최대 1,000자)', style: TextStyle(fontSize: 14)),
            Expanded(
              child: TextField(
                controller: _contentController,
                maxLength: 1000,
                maxLines: null,
                expands: true,
                decoration: const InputDecoration(
                  hintText: '이 책에 대한 솔직한 감상을 적어주세요.',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}