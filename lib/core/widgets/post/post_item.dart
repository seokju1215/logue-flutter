import 'package:flutter/material.dart';
import 'package:logue/core/themes/app_colors.dart';
import 'package:logue/data/models/book_post_model.dart';
import 'package:logue/core/widgets/book/book_frame.dart';
import 'package:logue/core/widgets/post/post_content.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:logue/core/widgets/dialogs/post_action_dialog.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/datasources/user_book_api.dart';

class PostItem extends StatelessWidget {
  final BookPostModel post;
  final bool isMyPost;
  final VoidCallback? onDeleteSuccess;
  final VoidCallback? onEditSuccess;
  final VoidCallback? onTap;

  const PostItem({
    Key? key,
    required this.isMyPost,
    required this.post,
    this.onDeleteSuccess,
    this.onEditSuccess,
    this.onTap,
  }) : super(key: key);

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
            GestureDetector(
              onTap: () {
                Navigator.pushNamed(context, '/other_profile',
                    arguments: post.userId);
              },
              child: Row(
                children: [
                  (avatarUrl.isEmpty || avatarUrl == 'basic')
                      ? CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.grey[300],
                          child: Image.asset('assets/basic_avatar.png',
                              width: 32, height: 32, fit: BoxFit.cover),
                        )
                      : CircleAvatar(
                          radius: 16,
                          backgroundImage: NetworkImage(avatarUrl),
                          backgroundColor: Colors.grey[300],
                        ),
                  const SizedBox(width: 8),
                  Text(
                    userName,
                    style: const TextStyle(
                        color: AppColors.black900, fontSize: 16),
                  ),
                ],
              ),
            ),
            const Spacer(),
            isMyPost
                ? Row(
                    children: [
                      OutlinedButton(
                        onPressed: () async {
                          final client = Supabase.instance.client;

                          try {
                            final response = await client
                                .from('user_books')
                                .select('isbn')
                                .eq('id', post.id)
                                .maybeSingle();

                            final isbn = response?['isbn'] as String?;
                            if (isbn == null || isbn.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('ISBN을 찾을 수 없어요.')),
                              );
                              return;
                            }

                            print('📚 user_books.id로 조회한 ISBN: $isbn');

                            Navigator.pushNamed(
                              context,
                              '/book_detail',
                              arguments: isbn,
                            );
                          } catch (e) {
                            print('❌ ISBN 조회 실패: $e');
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('도서 정보를 불러오는 데 실패했어요.')),
                            );
                          }
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
                              onEdit: () async {
                                Navigator.pop(context); // 먼저 dialog 닫고
                                final result = await Navigator.pushNamed(
                                  context,
                                  '/edit_post_screen',
                                  arguments: post,
                                );

                                if (result == true) {
                                  onEditSuccess?.call(); // 수정된 경우 다시 불러오기
                                }
                              },
                              onDelete: () async {
                                Navigator.pop(context); // 먼저 다이얼로그 닫고
                                final userBookApi =
                                    UserBookApi(Supabase.instance.client);
                                try {
                                  await userBookApi.deleteBook(post.id);
                                  onDeleteSuccess?.call();
                                } catch (_) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('책 삭제 중 오류가 발생했어요')),
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
                      Navigator.pushNamed(
                        context,
                        '/book_detail',
                        arguments: post.isbn, // 또는 post.bookIsbn, 실제 필드명 확인
                      );
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
        PostContent(
          post: post,
          onTapMore: onEditSuccess,
        ),
      ],
    );
  }
}
