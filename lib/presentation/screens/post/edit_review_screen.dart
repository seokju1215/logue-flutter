import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:my_logue/core/themes/app_colors.dart';
import 'package:my_logue/core/widgets/book/book_frame.dart';
import 'package:my_logue/presentation/screens/post/post_detail_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_logue/data/models/book_post_model.dart';
import 'package:my_logue/presentation/screens/main_navigation_screen.dart';
import 'package:my_logue/presentation/screens/post/single_post_screen.dart';

import 'my_post_screen.dart';

class EditReviewScreen extends StatefulWidget {
  final BookPostModel post;
  final String? fromScreen; // 'my_post_screen' 또는 'single_post_screen'

  const EditReviewScreen({
    Key? key, 
    required this.post, 
    this.fromScreen
  }) : super(key: key);

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

    _titleController.addListener(() {
      final text = _titleController.text;
      
      // 줄바꿈이 2줄을 넘으면 마지막 줄바꿈 이후의 텍스트 제거
      final newlineCount = '\n'.allMatches(text).length;
      if (newlineCount > 1) {
        // 첫 번째 줄바꿈의 위치 찾기
        final firstNewlineIndex = text.indexOf('\n');
        if (firstNewlineIndex != -1) {
          // 첫 번째 줄바꿈 이후의 모든 텍스트 제거
          _titleController.value = TextEditingValue(
            text: text.substring(0, firstNewlineIndex + 1),
            selection: TextSelection.collapsed(offset: firstNewlineIndex + 1),
          );
          return;
        }
      }
      
      // 제목이 50자를 넘으면 자동으로 잘라내기
      if (text.length > 50) {
        _titleController.value = TextEditingValue(
          text: text.substring(0, 50),
          selection: TextSelection.collapsed(offset: 50),
        );
      }
      setState(() {});
    });
    _contentController.addListener(() {
      // 내용이 2000자를 넘으면 자동으로 잘라내기
      if (_contentController.text.length > 2000) {
        _contentController.value = TextEditingValue(
          text: _contentController.text.substring(0, 2000),
          selection: TextSelection.collapsed(offset: 2000),
        );
      }
      setState(() {});
    });
  }

  Future<void> _updateReview() async {
    final user = client.auth.currentUser;
    if (user == null) return;

    final newTitle = _titleController.text.trim();
    final newContent = _contentController.text.trim();

    if (newTitle.length > 50 || newContent.length > 2000) return;

    setState(() => _isSaving = true);

    try {
      await client.from('user_books').update({
        'review_title': newTitle,
        'review_content': newContent,
      }).eq('id', widget.post.id);

      if (mounted) {
        // 어디서 왔는지에 따라 다른 동작
        if (widget.fromScreen == 'single_post_screen') {
          debugPrint("single_post에서 옴");
          Navigator.pop(context);
          // single_post_screen에서 왔다면 원래 화면으로 돌아가기
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => SinglePostScreen(
                bookId: widget.post.bookId ?? '',
                userBookId: widget.post.id,
                userId: client.auth.currentUser?.id,
              ),
            ),
          );
        } else if (widget.fromScreen == 'post_detail') {
          // post_detail에서 왔다면 수정된 데이터를 포함한 PostDetailScreen으로 직접 돌아가기
          Navigator.pop(context);
          Navigator.pop(context);
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => SinglePostScreen(bookId: widget.post.bookId ?? '', userBookId: widget.post.id,userId: client.auth.currentUser?.id,),
            ),
          );
          
          // 수정된 데이터로 새로운 post 객체 생성
          final updatedPost = widget.post.copyWith(
            reviewTitle: _titleController.text.trim(),
            reviewContent: _contentController.text.trim(),
          );
          
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PostDetailScreen(
                post: updatedPost, 
                fromScreen: widget.fromScreen, 
                isMyPost: true,
              ),
            ),
          );

        }else{
          debugPrint("my_post에서 옴");
          // my_post_screen에서 왔다면 기존 로직 유지장
          Navigator.pop(context);
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => SinglePostScreen(bookId: widget.post.bookId ?? '', userBookId: widget.post.id,userId: client.auth.currentUser?.id,),
            ),
          );
        }
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
        title: const Text('수정', style: TextStyle(fontSize: 16, color: AppColors.black900, fontWeight: FontWeight.w500,)),
        actions: [
          TextButton(
            onPressed: (_isSaving || 
                        _titleController.text.trim().isEmpty || 
                        _titleController.text.length > 50 || 
                        _contentController.text.length > 2000) 
                        ? null 
                        : _updateReview,
            child: Text(
              '저장',
              style: TextStyle(
                color: (_isSaving || 
                        _titleController.text.trim().isEmpty || 
                        _titleController.text.length > 50 || 
                        _contentController.text.length > 2000)
                        ? AppColors.black300
                        : const Color(0xFF0055FF),
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
              maxLines: 2, // 최대 2줄까지만
              keyboardType: TextInputType.multiline,
              inputFormatters: [
                LengthLimitingTextInputFormatter(50),
                // 두 번째 줄바꿈(\n)부터 차단
                TextInputFormatter.withFunction((oldValue, newValue) {
                  final oldText = oldValue.text;
                  final newText = newValue.text;
                  
                  // 기존 줄바꿈 개수
                  final oldLineCount = '\n'.allMatches(oldText).length;
                  // 새로운 줄바꿈 개수
                  final newLineCount = '\n'.allMatches(newText).length;
                  
                  // 이미 1개의 줄바꿈(2줄)이 있고, 새로 추가된 텍스트에 줄바꿈이 있으면 차단
                  if (oldLineCount >= 1 && newLineCount > oldLineCount) {
                    return oldValue; // 두 번째 줄바꿈부터 입력 차단
                  }
                  
                  return newValue;
                }),
              ],
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
                    '${_contentController.text.length}/2000',
                    style: const TextStyle(fontSize: 12, color: AppColors.black500),
                  ),
                ),
              ],
            ),
            TextField(
              controller: _contentController,
              maxLength: 2000,
              minLines: 8,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              inputFormatters: [
                LengthLimitingTextInputFormatter(2000),
              ],
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