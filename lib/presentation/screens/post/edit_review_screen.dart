import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:my_logue/core/themes/app_colors.dart';
import 'package:my_logue/core/widgets/book/book_frame.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_logue/data/models/book_post_model.dart';
import 'package:my_logue/presentation/screens/main_navigation_screen.dart';

import 'my_post_screen.dart';

class EditReviewScreen extends StatefulWidget {
  final BookPostModel post;

  const EditReviewScreen({Key? key, required this.post}) : super(key: key);

  @override
  State<EditReviewScreen> createState() => _EditReviewScreenState();
}

class _EditReviewScreenState extends State<EditReviewScreen> {
  final client = Supabase.instance.client;
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController.text = widget.post.reviewTitle ?? '';
    _contentController.text = widget.post.reviewContent ?? '';

    _titleController.addListener(() => setState(() {}));
    _contentController.addListener(() => setState(() {}));
  }

  Future<void> _updateReview() async {
    final user = client.auth.currentUser;
    if (user == null) return;

    final newTitle = _titleController.text.trim();
    final newContent = _contentController.text.trim();

    if (newTitle.length > 50 || newContent.length > 1000) return;

    setState(() => _isSaving = true);

    try {
      await client.from('user_books').update({
        'review_title': newTitle,
        'review_content': newContent,
      }).eq('id', widget.post.id);

      if (mounted) {
        Navigator.of(context).pop(true);
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => MyBookPostScreen(userBookId: widget.post.id),
          ),
        );
        return;
      }
    } catch (e) {
      debugPrint('❌ 후기 수정 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('수정에 실패했어요. 다시 시도해주세요.')),
        );
      }
    } finally {
      if (mounted && Navigator.of(context).canPop()) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    print('🛠️ EditReviewScreen: ${widget.post.id}, ${widget.post.reviewTitle}');
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        leading: IconButton(
          icon: SvgPicture.asset('assets/back_arrow.svg'),
          onPressed: () => Navigator.pop(context),// 👈 또는 null, 원하는 값으로
        ),
        title: const Text('수정', style: TextStyle(fontSize: 16, color: AppColors.black900)),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _updateReview,
            child: Text(
              '저장',
              style: TextStyle(
                color: _isSaving ? Colors.grey : const Color(0xFF0055FF),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: SizedBox(
                width: 235,
                height: 349,
                child: BookFrame(imageUrl: widget.post.image ?? ''),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 9),
                  child: Text(
                    '후기 제목',
                    style: TextStyle(fontSize: 12, color: AppColors.black500),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 9),
                  child: Text(
                    '${_titleController.text.length}/50',
                    style: const TextStyle(fontSize: 12, color: AppColors.black500),
                  ),
                ),
              ],
            ),
            TextField(
              controller: _titleController,
              maxLength: 50,
              minLines: 2,
              maxLines: null,
              style: const TextStyle(fontSize: 14, color: AppColors.black900),
              decoration: InputDecoration(
                counterText: '', // 기본 글자 수 숨김
                contentPadding: const EdgeInsets.symmetric(vertical: 9, horizontal: 9),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(5)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 9),
                  child: Text(
                    '후기 내용',
                    style: TextStyle(fontSize: 12, color: AppColors.black500),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 9),
                  child: Text(
                    '${_contentController.text.length}/1000',
                    style: const TextStyle(fontSize: 12, color: AppColors.black500),
                  ),
                ),
              ],
            ),
            TextField(
              controller: _contentController,
              maxLength: 1000,
              minLines: 8,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              style: const TextStyle(fontSize: 14, color: AppColors.black900),
              decoration: InputDecoration(
                counterText: '', // 기본 카운터 제거
                contentPadding: const EdgeInsets.symmetric(vertical: 9, horizontal: 9),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(5)),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}