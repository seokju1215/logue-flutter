import 'package:flutter/material.dart';
import 'package:logue/core/themes/app_colors.dart';
import 'package:logue/data/models/book_post_model.dart';
import 'package:logue/core/widgets/book/book_frame.dart';
import 'package:logue/core/widgets/post/post_content.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:logue/core/widgets/dialogs/post_action_dialog.dart';
import 'package:logue/presentation/screens/post/edit_review_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/datasources/user_book_api.dart';
import '../../../presentation/screens/book/book_detail_screen.dart';
import '../../../presentation/screens/profile/other_profile_screen.dart';

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
    final imageUrl = post.image ?? '';
    final avatarUrl = post.avatarUrl ?? '';
    final userName = post.userName ?? '';
    final reviewTitle = post.reviewTitle ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: imageUrl.isEmpty
              ? Container(
            width: 200,
            height: 300,
            color: Colors.grey[300],
            child: const Icon(Icons.broken_image, size: 50),
          )
              : SizedBox(
            width: 206,
            height: 306,
            child: BookFrame(imageUrl: imageUrl),
          ),
        ),
        const SizedBox(height: 15),

        Row(
          children: [
            GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => OtherProfileScreen(userId: post.userId),
                  ),
                );
              },
              child: Row(
                children: [
                  (avatarUrl.isEmpty || avatarUrl == 'basic')
                      ? CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.grey[300],
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
                  Text(
                    userName,
                    style: const TextStyle(
                      color: AppColors.black900,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            isMyPost
                ? Row(
              children: [
                OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            BookDetailScreen(bookId: post.bookId!),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.black300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 19,
                      vertical: 8,
                    ),
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
                  onPressed: () async {
                    final scaffoldContext = context;

                    await showDialog(
                      context: context,
                      useRootNavigator: true,
                      builder: (_) => PostActionDialog(
                        onEdit: () {
                          Navigator.of(context).pop(); // 다이얼로그 닫기

                          Future.microtask(() async {
                            final editResult =
                            await Navigator.of(scaffoldContext).push(
                              MaterialPageRoute(
                                fullscreenDialog: true,
                                builder: (_) =>
                                    EditReviewScreen(post: post),
                              ),
                            );
                            if (editResult == true) {
                              onEditSuccess?.call();
                            }
                          });
                        },
                        onDelete: () async {
                          Navigator.of(context).pop();
                          final userBookApi = UserBookApi(
                              Supabase.instance.client);
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
                  arguments: post.bookId,
                );
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.black300),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 19,
                  vertical: 8,
                ),
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
        if (reviewTitle.isNotEmpty)
          Text(
            reviewTitle,
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.black900,
            ),
          ),
        const SizedBox(height: 8),
        PostContent(
          post: post,
          onTapMore: onEditSuccess,
        ),
      ],
    );
  }
}