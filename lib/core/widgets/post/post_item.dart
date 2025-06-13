// PostItem.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:logue/core/themes/app_colors.dart';
import 'package:logue/core/widgets/book/book_frame.dart';
import 'package:logue/core/widgets/post/post_content.dart';
import 'package:logue/data/datasources/user_book_api.dart';
import 'package:logue/data/models/book_post_model.dart';
import 'package:logue/presentation/screens/book/book_detail_screen.dart';
import 'package:logue/presentation/screens/post/edit_review_screen.dart';
import 'package:logue/presentation/screens/profile/other_profile_screen.dart';
import 'package:logue/core/widgets/dialogs/post_action_dialog.dart';
import 'package:logue/core/widgets/dialogs/post_delete_dialog.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PostItem extends StatelessWidget {
  final BookPostModel post;
  final bool isMyPost;
  final VoidCallback? onDeleteSuccess;
  final VoidCallback? onEditSuccess;
  final VoidCallback? onTap;

  const PostItem({
    super.key,
    required this.post,
    required this.isMyPost,
    this.onDeleteSuccess,
    this.onEditSuccess,
    this.onTap,
  });

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
            width: 206,
            height: 306,
            color: Colors.grey[300],
            child: const Icon(Icons.broken_image, size: 50),
          )
              : SizedBox(width: 206, height: 306, child: BookFrame(imageUrl: imageUrl)),
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            GestureDetector(
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => OtherProfileScreen(userId: post.userId),
                ));
              },
              child: Row(
                children: [
                  (avatarUrl.isEmpty || avatarUrl == 'basic')
                      ? CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.grey[300],
                    child: Image.asset(
                      'assets/basic_avatar.png',
                      width: 45,
                      height: 45,
                      fit: BoxFit.cover,
                    ),
                  )
                      : CircleAvatar(
                    radius: 22.5,
                    backgroundImage: NetworkImage(avatarUrl),
                    backgroundColor: Colors.grey[300],
                  ),
                  const SizedBox(width: 9),
                  Text(userName,
                      style: const TextStyle(fontSize: 14, color: AppColors.black900, height: 1.5, letterSpacing: -0.32)),
                ],
              ),
            ),
            const Spacer(),
            if (isMyPost)
              Row(
                children: [
                  OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => BookDetailScreen(bookId: post.bookId!),
                      ));
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.black300),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                      padding: const EdgeInsets.symmetric(horizontal: 19, vertical: 8),
                    ),
                    child: const Text('책 둘러보기 →',
                        style: TextStyle(fontSize: 14, color: AppColors.black500, height: 1)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert),
                    onPressed: () async {
                      final action = await showDialog<String>(
                        context: context,
                        builder: (_) => const PostActionDialog(),
                      );

                      if (action == 'edit') {
                        final result = await Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => EditReviewScreen(post: post),
                        ));
                        if (result == true) {
                          onEditSuccess?.call();
                        }
                      } else if (action == 'delete') {
                        await showDialog(
                          context: context,
                          builder: (deleteDialogContext) => PostDeleteDialog(
                            onDelete: () async {
                              Navigator.pop(deleteDialogContext);
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
                      }
                    },
                  ),
                ],
              )
            else
              OutlinedButton(
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => BookDetailScreen(bookId: post.bookId!),
                  ));
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.black300, width: 1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                  padding: const EdgeInsets.symmetric(horizontal: 19, vertical: 8),
                ),

                child: const Text('책 둘러보기 →',
                    style: TextStyle(fontSize: 14, color: AppColors.black500)),
              ),
          ],
        ),
        const SizedBox(height: 18),
        if (reviewTitle.isNotEmpty)
          Text(
            reviewTitle,
            style: const TextStyle(fontSize: 16, color: AppColors.black900, height: 1.5, letterSpacing: -0.32),
          ),
        const SizedBox(height: 8),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: PostContent(post: post),
        ),
      ],
    );
  }
}