import 'package:flutter/material.dart';
import 'package:logue/core/themes/app_colors.dart';
import 'package:logue/data/models/book_post_model.dart';
import 'package:logue/core/widgets/book/book_frame.dart';
import 'package:logue/core/widgets/post/post_content.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:logue/core/widgets/post/post_action_dialog.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/datasources/user_book_api.dart';

class PostItem extends StatelessWidget {
  final BookPostModel post;
  final bool isMyPost;
  final VoidCallback? onDeleteSuccess;


  const PostItem(
      {Key? key, required this.isMyPost, required this.post,  this.onDeleteSuccess,})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final hasLongContent = (post.reviewContent ?? '').length > 100;
    final imageUrl = post.image ?? '';
    final avatarUrl = post.avatarUrl ?? '';
    final userName = post.userName ?? '';
    final reviewTitle = post.reviewTitle ?? '';

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
                          showDialog(
                            context: context,
                            barrierDismissible: true,
                            barrierColor: Colors.transparent,
                            builder: (_) => PostActionDialog(
                              onEdit: () {
                                Navigator.pop(context);
                                print('✏️ 수정');
                                // Navigator.pushNamed(context, '/edit_post_screen', arguments: post.id);
                              },
                              onDelete: () async {
                                Navigator.pop(context); // 먼저 다이얼로그 닫고
                                final userBookApi = UserBookApi(Supabase.instance.client);
                                try {
                                  await userBookApi.deleteBook(post.id);
                                  onDeleteSuccess?.call();
                                } catch (_) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('책 삭제 중 오류가 발생했어요')),
                                  );
                                }
                              },
                            ),
                          );
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
            style: const TextStyle(fontSize: 16, color: AppColors.black900),
          ),

        const SizedBox(height: 8),

        // 리뷰 본문
        PostContent(post: post),
      ],
    );
  }
}
