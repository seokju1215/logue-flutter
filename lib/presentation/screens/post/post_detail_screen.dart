import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:logue/core/themes/app_colors.dart';
import 'package:logue/data/models/book_post_model.dart';
import 'package:logue/core/widgets/book/book_frame.dart';

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

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(userName, style: TextStyle(color: AppColors.black900, fontSize: 18)),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 9),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 프로필
              Row(
                children: [
                  (avatarUrl.isEmpty || avatarUrl == 'basic')
                      ? CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.black100,
                    child: Image.asset(
                      'assets/basic_avatar.png',
                      width: 32,
                      height: 32,
                      fit: BoxFit.cover,
                    ),
                  )
                      : CircleAvatar(
                    radius: 16,
                    backgroundImage: NetworkImage(avatarUrl),
                    backgroundColor: Colors.grey[300],
                  ),
                  const SizedBox(width: 8),
                  Text(userName, style: const TextStyle(fontSize: 16)),
                ],
              ),

              const SizedBox(height: 24),

              // 리뷰 제목
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

              // 리뷰 본문 (제한 없음)
              Text(
                reviewContent,
                style: const TextStyle(fontSize: 12, color: AppColors.black500),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}