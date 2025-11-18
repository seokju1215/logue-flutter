import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:my_logue/core/themes/app_colors.dart';
import 'package:my_logue/data/models/book_post_model.dart';
import 'package:my_logue/core/widgets/book/book_frame.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_logue/data/datasources/user_book_api.dart';
import 'package:my_logue/core/widgets/dialogs/post_delete_dialog.dart';


import '../../../core/widgets/dialogs/post_action_bottom_sheet.dart';
import '../../../core/widgets/dialogs/reject_delete_dialog.dart';
import '../book/book_detail_screen.dart';
import '../profile/other_profile_screen.dart';
import 'edit_review_screen.dart';

class PostDetailScreen extends StatelessWidget {
  final BookPostModel post;
  final String? fromScreen;
  final VoidCallback? onDeleteSuccess;
  final VoidCallback? onEditSuccess;
  final VoidCallback? onArchiveSuccess;
  final bool isMyPost;

  const PostDetailScreen(
      {super.key, required this.post, this.fromScreen, this.onDeleteSuccess, this.onEditSuccess, this.onArchiveSuccess,required this.isMyPost});

  /// 화면 너비와 more_vert 아이콘 유무에 따라 username의 최대 표시 길이를 반환
  /// 
  /// more_vert 아이콘이 있을 때 (isMyPost == true): 공간이 제한적이므로 더 짧게
  /// more_vert 아이콘이 없을 때 (isMyPost == false): 공간이 더 넓으므로 더 길게
  int _getMaxUsernameLength(double screenWidth, bool hasMoreVertIcon) {
    if (hasMoreVertIcon) {
      // more_vert 아이콘이 있을 때 (현재 적용된 기준)
      if (screenWidth >= 410) {
        return 20;
      } else if (screenWidth >= 400) {
        return 19;
      } else if (screenWidth >= 390) {
        return 18;
      } else if (screenWidth >= 375) {
        return 17;
      } else {
        return 15;
      }
    } else {
      // more_vert 아이콘이 없을 때 (더 긴 길이 허용)
      if (screenWidth >= 400) {
        return 20;
      } else if (screenWidth >= 390) {
        return 18;
      } else if (screenWidth >= 375) {
        return 18;
      } else {
        return 16;
      }
    }
  }

  /// username을 화면 너비와 more_vert 아이콘 유무에 맞춰 자르기
  String _getTruncatedUsername(String userName, bool isMyPost, double screenWidth) {
    final hasMoreVertIcon = isMyPost; // isMyPost가 true면 more_vert 아이콘이 있음
    final maxLength = _getMaxUsernameLength(screenWidth, hasMoreVertIcon);
    
    if (userName.length > maxLength) {
      return '${userName.substring(0, maxLength - 3)}...';
    }
    return userName;
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = post.image ?? '';
    final avatarUrl = post.avatarUrl ?? '';
    final userName = post.userName ?? '';
    final reviewTitle = post.reviewTitle ?? '';
    final reviewContent = post.reviewContent ?? '';
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    return Scaffold(
      appBar: AppBar(
        title: Text(userName, style: TextStyle(fontSize: 16,
              color: AppColors.black900,
              fontWeight: FontWeight.w500,),),
        centerTitle: true,
        leading: IconButton(
          icon: SvgPicture.asset('assets/back_arrow.svg'),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 9),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 프로필 + 책 둘러보기 + 더보기 (삭제/취소)
              Padding(
                padding: EdgeInsets.only(left:22, right: isMyPost ? 4 : 22),
                child: Row(
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
                            radius: 22.5,
                            backgroundColor: AppColors.black100,
                            child: Image.asset(
                                'assets/basic_avatar.png', width: 45, height: 45),
                          )
                              : CircleAvatar(
                            radius: 22.5,
                            backgroundImage: NetworkImage(avatarUrl),
                            backgroundColor: Colors.grey[300],
                          ),
                          const SizedBox(width: 8),
                          Builder(
                            builder: (context) {
                              final screenWidth = MediaQuery.of(context).size.width;
                              final truncatedName = _getTruncatedUsername(userName, isMyPost, screenWidth);
                              return Text(truncatedName, style: const TextStyle(fontSize: 14,
                                  color: AppColors.black900,
                                  height: 1.5,
                                  letterSpacing: -0.32));
                            },
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
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
                            borderRadius: BorderRadius.circular(5)),
                        padding: const EdgeInsets.symmetric(horizontal: 19),
                        minimumSize: const Size(0, 34),
                      ),
                      child: Text( isMyPost ? '책 둘러보기' : '책 둘러보기 →', style: TextStyle(fontSize: 14,
                          color: AppColors.black500,
                          height: 1,
                          fontWeight: FontWeight.w400),),
                    ),
                    if (isMyPost)
                      IconButton(
                          icon: const Icon(Icons.more_vert),
                          onPressed: () async {
                            debugPrint(
                                '🔍 PostActionBottomSheet 호출: is_archived=${post
                                    .is_archived}');
                            final action = await showModalBottomSheet<String>(
                              context: context,
                              useRootNavigator: true,
                              // ✅ 루트 네비게이터 위에 띄움 → 바텀 네비까지 덮음
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
                              final result = await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        EditReviewScreen(
                                          post: post, fromScreen: 'post_detail',),
                                  ));
                              if (result == true) {
                                onEditSuccess?.call();
                              }
                            } else if (action == 'archive') {
                              // 보관함으로 이동 기능 구현
                              try {
                                final userBookApi = UserBookApi(
                                    Supabase.instance.client);
                                await userBookApi.archiveBook(post.id);
                                fromScreen == 'single_post_screen'
                                    ? onDeleteSuccess?.call()
                                    : onArchiveSuccess?.call(); // 보관 후 목록 새로고침
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('보관 중 오류가 발생했습니다')),
                                );
                              }
                            } else if (action == 'profile') {
                              // 프로필로 이동 기능 구현
                              debugPrint('🔍 프로필로 이동 시도: ${post.id}');
                              try {
                                final userBookApi = UserBookApi(
                                    Supabase.instance.client);
                                await userBookApi.moveToProfile(post.id);
                                debugPrint('✅ 프로필로 이동 성공: ${post.id}');
                                onDeleteSuccess?.call(); // 프로필 이동 후 목록 새로고침
                              } catch (e) {
                                debugPrint('❌ 프로필로 이동 실패: $e');
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text('프로필 이동 중 오류가 발생했습니다: $e')),
                                );
                              }
                            } else if (action == 'delete') {
                              if (post.is_archived == false) {
                                await showDialog(
                                  context: context,
                                  builder: (rejectDialogContext) =>
                                      RejectDeleteDialog(
                                        onDelete: () async {
                                          Navigator.pop(rejectDialogContext);
                                        },
                                      ),
                                );
                              } else {
                                await showDialog(
                                  context: context,
                                  builder: (deleteDialogContext) =>
                                      PostDeleteDialog(
                                        onDelete: () async {
                                          Navigator.pop(deleteDialogContext);
                                          final userBookApi = UserBookApi(
                                              Supabase.instance.client);
                                          try {
                                            await userBookApi.deleteBook(post.id);
                                            onDeleteSuccess?.call();
                                          } catch (_) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(content: Text(
                                                  '책 삭제 중 오류가 발생했어요')),
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
                ),
              ),

              const SizedBox(height: 10),
              if (reviewTitle.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Text(
                    reviewTitle,
                    style: const TextStyle(
                        fontSize: 16,
                        color: AppColors.black900,
                        height: 1.4,
                        letterSpacing: -0.32
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Text(
                  reviewContent,
                  style: const TextStyle(fontSize: 14,
                      color: AppColors.black500,
                      height: 2,
                      letterSpacing: -0.32),
                ),
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
      builder: (_) =>
          PostDeleteDialog(
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