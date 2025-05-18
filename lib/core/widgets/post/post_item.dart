import 'package:flutter/material.dart';
import 'package:logue/core/themes/app_colors.dart';
import 'package:logue/data/models/book_post_model.dart';
import 'package:logue/core/widgets/book/book_frame.dart';
import 'package:logue/core/widgets/post/post_content.dart';
import 'package:flutter_svg/flutter_svg.dart';

class PostItem extends StatelessWidget {
  final BookPostModel post;
  final bool isMyPost;
  final VoidCallback? onTapComment; // 댓글 버튼 누르면

  const PostItem(
      {Key? key, required this.isMyPost, required this.post, this.onTapComment})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final hasLongContent = (post.reviewContent ?? '').length > 100;
    final imageUrl = post.image ?? '';
    final avatarUrl = post.avatarUrl ?? '';
    final userName = post.userName ?? '';
    final reviewTitle = post.reviewTitle ?? '';
    final reviewContent = post.reviewContent ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 책 이미지
        Center(
            child: imageUrl.isEmpty
                ? Container(
                    width: 200,
                    height: 300,
                    color: Colors.grey[300],
                    child: const Icon(Icons.broken_image, size: 50),
                  )
                : SizedBox(
                    width: 235.429,
                    height: 349.714,
                    child: BookFrame(imageUrl: imageUrl),
                  )),
        const SizedBox(height: 12),

        // 프로필 영역
        Row(
          children: [
            (post.avatarUrl == null ||
                    post.avatarUrl!.isEmpty ||
                    post.avatarUrl == 'basic')
                ? CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.grey[300],
                    child: Image.asset('assets/basic_avatar.png',
                        width: 32, height: 32, fit: BoxFit.cover),
                  )
                : CircleAvatar(
                    radius: 16,
                    backgroundImage: NetworkImage(post.avatarUrl!),
                    backgroundColor: Colors.grey[300],
                  ),
            const SizedBox(width: 8),
            Text(
              userName,
              style: const TextStyle(color: AppColors.black900, fontSize: 16),
            ),
            const Spacer(),
            isMyPost
                ? Row(
                    children: [
                      OutlinedButton(
                        onPressed: () {
                          // 버튼 눌렀을 때 동작
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.black300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5), // 필요 시 둥글게
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 19, vertical: 8),
                        ),
                        child: const Text(
                          '책 둘러보기 →',
                          style: TextStyle(
                            color: AppColors.black500,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.more_vert),
                        onPressed: () {
                          // 더보기 메뉴 (편집, 삭제)
                        },
                      ),
                    ],
                  )
                : OutlinedButton(
                    onPressed: () {
                      // 버튼 눌렀을 때 동작
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.black300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5), // 필요 시 둥글게
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 19, vertical: 8),
                    ),
                    child: const Text(
                      '책 둘러보기 →',
                      style: TextStyle(
                        color: AppColors.black500,
                        fontSize: 14,
                      ),
                    ),
                  ),
          ],
        ),
        const SizedBox(height: 8),

        // 리뷰 제목
        if (reviewTitle.isNotEmpty)
          Text(
            reviewTitle,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),

        const SizedBox(height: 8),

        // 리뷰 본문
        PostContent(post: post),
      ],
    );
  }
}
