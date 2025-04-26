import 'package:flutter/material.dart';
import 'package:logue/data/models/book_post_model.dart';

class PostItem extends StatelessWidget {
  final BookPostModel post;
  final VoidCallback? onTapComment; // 댓글 버튼 누르면

  const PostItem({Key? key, required this.post, this.onTapComment}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final hasLongContent = (post.reviewContent ?? '').length > 100;
    final imageUrl = post.image ?? '';
    final avatarUrl = post.avatarUrl ?? '';
    final userName = post.userName ?? '사용자';
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
              : Image.network(
            imageUrl,
            width: 200,
            height: 300,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: 12),

        // 프로필 영역
        Row(
          children: [
            (post.avatarUrl == null || post.avatarUrl!.isEmpty || post.avatarUrl == 'basic')
                ? CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey[300],
              child: Image.asset('assets/basic_avatar.png', width: 32, height: 32, fit: BoxFit.cover),
            )
                : CircleAvatar(
              radius: 16,
              backgroundImage: NetworkImage(post.avatarUrl!),
              backgroundColor: Colors.grey[300],
            ),
            const SizedBox(width: 8),
            Text(
              userName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.more_horiz),
              onPressed: () {
                // 👉 더보기 옵션 (편집, 삭제 등) 나중에 추가할 자리
              },
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
        Text(
          hasLongContent ? '${reviewContent.substring(0, 100)}...' : reviewContent,
          style: const TextStyle(fontSize: 14, color: Colors.black87),
        ),

        // 더보기 버튼
        if (hasLongContent)
          TextButton(
            onPressed: () {
              // 👉 더보기 눌렀을 때 상세 화면 이동
            },
            child: const Text('더보기'),
          ),

        // 댓글 버튼
        Row(
          children: [
            IconButton(
              onPressed: onTapComment,
              icon: const Icon(Icons.comment),
            ),
            const Text('댓글 0개'), // 나중에 댓글 수 연동할 자리
          ],
        ),

        const Divider(thickness: 1),
      ],
    );
  }
}