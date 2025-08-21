// PostItem.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:my_logue/core/themes/app_colors.dart';
import 'package:my_logue/core/widgets/book/book_frame.dart';
import 'package:my_logue/core/widgets/dialogs/reject_delete_dialog.dart';
import 'package:my_logue/core/widgets/post/post_content.dart';
import 'package:my_logue/data/datasources/user_book_api.dart';
import 'package:my_logue/data/models/book_post_model.dart';
import 'package:my_logue/presentation/screens/book/book_detail_screen.dart';
import 'package:my_logue/presentation/screens/post/edit_review_screen.dart';
import 'package:my_logue/presentation/screens/profile/other_profile_screen.dart';
import 'package:my_logue/core/widgets/dialogs/post_action_bottom_sheet.dart';
import 'package:my_logue/core/widgets/dialogs/post_delete_dialog.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PostItem extends StatelessWidget {
  final BookPostModel post;
  final bool isMyPost;
  final VoidCallback? onDeleteSuccess;
  final VoidCallback? onEditSuccess;
  final VoidCallback? onArchiveSuccess;
  final VoidCallback? onTap;
  final String? fromScreen;

  const PostItem({
    super.key,
    required this.post,
    required this.isMyPost,
    this.onDeleteSuccess,
    this.onEditSuccess,
    this.onArchiveSuccess,
    this.onTap,
    this.fromScreen
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
                final result = Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => OtherProfileScreen(userId: post.userId),
                ));
                if (result == true) {
                  onEditSuccess?.call(); // 여기를 onRefresh? 로 바꿔도 좋음
                }
              },
              child: Row(
                children: [
                  (avatarUrl.isEmpty || avatarUrl == 'basic')
                      ? CircleAvatar(
                    radius: 22.5,
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
                      padding: const EdgeInsets.symmetric(horizontal: 19),
                      minimumSize: const Size(0, 34),
                    ),
                    child: const Text('책 둘러보기 →',
                        style: TextStyle(fontSize: 14, color: AppColors.black500, height: 1, fontWeight: FontWeight.w400)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert),
                    onPressed: () async {
                      debugPrint('🔍 PostActionBottomSheet 호출: is_archived=${post.is_archived}');
                      final action = await showModalBottomSheet<String>(
                        context: context,
                        useRootNavigator: true,           // ✅ 루트 네비게이터 위에 띄움 → 바텀 네비까지 덮음
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (ctx) {
                          // ✅ 불필요한 padding 제거: 가장 아래에서 시작
                          return SafeArea(
                            top: false,
                            // bottom: false도 가능. 홈 인디케이터 공간까지 덮고 싶으면 false 유지
                            child: PostActionBottomSheet(
                              is_archived: post.is_archived,
                              fromScreen: fromScreen,
                            ),
                          );
                        },
                      );
                      debugPrint('🔍 PostActionBottomSheet 결과: $action');

                      if (action == 'share') {
                        // 공유 기능 구현
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('공유 기능이 준비 중입니다')),
                        );
                      } else if (action == 'edit') {
                        final result = await Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => EditReviewScreen(post: post, fromScreen: 'post_item',),
                        ));
                        if (result == true) {
                          onEditSuccess?.call();
                        }
                      } else if (action == 'archive') {
                        // 보관함으로 이동 기능 구현
                        try {
                          final userBookApi = UserBookApi(Supabase.instance.client);
                          await userBookApi.archiveBook(post.id);
                          fromScreen == 'single_post_screen'? onDeleteSuccess?.call() :onArchiveSuccess?.call(); // 보관 후 목록 새로고침
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('보관 중 오류가 발생했습니다')),
                          );
                        }
                      } else if (action == 'profile') {
                        // 프로필로 이동 기능 구현
                        debugPrint('🔍 프로필로 이동 시도: ${post.id}');
                        try {
                          final userBookApi = UserBookApi(Supabase.instance.client);
                          await userBookApi.moveToProfile(post.id);
                          debugPrint('✅ 프로필로 이동 성공: ${post.id}');
                          onDeleteSuccess?.call(); // 프로필 이동 후 목록 새로고침
                        } catch (e) {
                          debugPrint('❌ 프로필로 이동 실패: $e');
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('프로필 이동 중 오류가 발생했습니다: $e')),
                          );
                        }
                      } else if (action == 'delete') {
                        if(post.is_archived == false) {
                          await showDialog(
                            context: context,
                            builder: (rejectDialogContext) => RejectDeleteDialog(
                              onDelete: () async {
                                Navigator.pop(rejectDialogContext);
                              },
                            ),
                          );
                        } else{
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
                  padding: const EdgeInsets.symmetric(horizontal: 19),
                  minimumSize: const Size(0, 34),
                ),

                child: const Text('책 둘러보기 →',
                    style: TextStyle(fontSize: 14, color: AppColors.black500, fontWeight: FontWeight.w400)),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (reviewTitle.isNotEmpty)
          Text(
            reviewTitle,
            style: const TextStyle(fontSize: 16, color: AppColors.black900, height: 1.4, letterSpacing: -0.32),
          ),
        const SizedBox(height: 4),
        Container(
          constraints: const BoxConstraints(minHeight: 0),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: PostContent(post: post, fromScreen: fromScreen, onDeleteSuccess:onDeleteSuccess, onEditSuccess: onEditSuccess, onArchiveSuccess: onArchiveSuccess, isMyPost: isMyPost,),
          ),
        ),
      ],
    );
  }
}