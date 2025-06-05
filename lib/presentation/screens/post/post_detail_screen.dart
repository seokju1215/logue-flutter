import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:logue/core/themes/app_colors.dart';
import 'package:logue/data/models/book_post_model.dart';
import 'package:logue/core/widgets/book/book_frame.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logue/data/datasources/user_book_api.dart';
import 'package:logue/core/widgets/dialogs/post_delete_dialog.dart';

import '../book/book_detail_screen.dart';

class PostDetailScreen extends StatelessWidget {
  final BookPostModel post;

  const PostDetailScreen({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    final imageUrl = post.image ?? '';
    final avatarUrl = post.avatarUrl ?? '';
    final userName = post.userName ?? '';
    final reviewTitle = post.reviewTitle ?? '';
    final reviewContent = post.reviewContent ?? '';
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final isMyPost = post.userId == currentUserId;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(userName, style: const TextStyle(color: AppColors.black900, fontSize: 18)),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 9),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 프로필 + 책 둘러보기 + 더보기 (삭제/취소)
              Row(
                children: [
                  (avatarUrl.isEmpty || avatarUrl == 'basic')
                      ? CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.black100,
                    child: Image.asset('assets/basic_avatar.png', width: 32, height: 32),
                  )
                      : CircleAvatar(
                    radius: 16,
                    backgroundImage: NetworkImage(avatarUrl),
                    backgroundColor: Colors.grey[300],
                  ),
                  const SizedBox(width: 8),
                  Text(userName, style: const TextStyle(fontSize: 16)),
                  const Spacer(),
                  OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => BookDetailScreen(bookId: post.bookId!),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.black300),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                      padding: const EdgeInsets.symmetric(horizontal: 19, vertical: 8),
                    ),
                    child: const Text('책 둘러보기 →', style: TextStyle(color: AppColors.black500, fontSize: 14)),
                  ),
                  if (isMyPost)
                    IconButton(
                      icon: const Icon(Icons.more_vert),
                      onPressed: () => _showDeleteDialog(context),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              if (reviewTitle.isNotEmpty)
                Text(
                  reviewTitle,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.black900,
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                reviewContent,
                style: const TextStyle(fontSize: 12, color: AppColors.black500),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => PostDeleteDialog(
        onDelete: () async {
          Navigator.pop(context); // 다이얼로그 닫기
          try {
            final api = UserBookApi(Supabase.instance.client);
            await api.deleteBook(post.id);
            if (context.mounted) Navigator.pop(context, true); // 이전 화면으로
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('삭제 중 오류가 발생했어요')),
              );
            }
          }
        },
      ),
    );
  }
}