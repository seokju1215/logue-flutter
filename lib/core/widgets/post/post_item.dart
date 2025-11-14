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
  final double? horizontalPadding;

  const PostItem({
    super.key,
    required this.post,
    required this.isMyPost,
    this.onDeleteSuccess,
    this.onEditSuccess,
    this.onArchiveSuccess,
    this.onTap,
    this.fromScreen,
    this.horizontalPadding,
  });

  /// 화면 너비와 more_vert 아이콘 유무에 따라 username의 최대 표시 길이를 반환
  /// 
  /// more_vert 아이콘이 있을 때 (isMyPost == true): 공간이 제한적이므로 더 짧게
  /// more_vert 아이콘이 없을 때 (isMyPost == false): 공간이 더 넓으므로 더 길게
  int _getMaxUsernameLength(double screenWidth, bool hasMoreVertIcon) {
    if (hasMoreVertIcon) {
      // more_vert 아이콘이 있을 때 (현재 적용된 기준)
      if (screenWidth >= 400) {
        return 20;
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
    final double effectiveHorizontalPadding =
        isMyPost ? (horizontalPadding ?? 0) : (horizontalPadding ?? 22);

    final stopwatch = Stopwatch()..start();
    debugPrint('🚀 PostItem 렌더링 시작 - ID: ${post.id}');
    debugPrint('   📊 Post 데이터:');
    debugPrint('     - title: ${post.title}');
    debugPrint('     - author: ${post.author}');
    debugPrint('     - reviewTitle: ${post.reviewTitle}');
    debugPrint('     - reviewContent 길이: ${post.reviewContent?.length ?? 0}');
    debugPrint('     - userName: ${post.userName}');
    debugPrint('     - image: ${post.image?.isNotEmpty == true ? '있음' : '없음'}');
    debugPrint('     - avatarUrl: ${post.avatarUrl?.isNotEmpty == true ? '있음' : '없음'}');
    debugPrint('     - is_archived: ${post.is_archived}');
    debugPrint('     - orderIndex: ${post.orderIndex}');
    
    final dataExtractionStart = DateTime.now();
    final imageUrl = post.image ?? '';
    final avatarUrl = post.avatarUrl ?? '';
    final userName = post.userName ?? '';
    final reviewTitle = post.reviewTitle ?? '';
    final dataExtractionEnd = DateTime.now();
    final dataExtractionDuration = dataExtractionEnd.difference(dataExtractionStart);
    debugPrint('   ⏱️ 데이터 추출 소요시간: ${dataExtractionDuration.inMicroseconds}μs');

    final widgetBuildStart = DateTime.now();
    final result = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 이미지 섹션
        Builder(
          builder: (context) {
            final imageSectionStart = DateTime.now();
            debugPrint('   🖼️ 이미지 섹션 렌더링 시작');
            final imageWidget = Center(
              child: imageUrl.isEmpty
                  ? Container(
                width: 206,
                height: 306,
                color: Colors.grey[300],
                child: const Icon(Icons.broken_image, size: 50),
              )
                  : SizedBox(width: 206, height: 306, child: BookFrame(imageUrl: imageUrl)),
            );
            final imageSectionEnd = DateTime.now();
            final imageSectionDuration = imageSectionEnd.difference(imageSectionStart);
            debugPrint('   ⏱️ 이미지 섹션 소요시간: ${imageSectionDuration.inMicroseconds}μs');
            return imageWidget;
          },
        ),
        const SizedBox(height: 15),
        // 사용자 정보 및 버튼 섹션
        Builder(
          builder: (context) {
            final userSectionStart = DateTime.now();
            debugPrint('   👤 사용자 정보 섹션 렌더링 시작');
            final userSectionWidget = Padding(
              padding: isMyPost ? EdgeInsets.only(left : 22, right: 4) : EdgeInsets.symmetric(horizontal: 22),
              child: Row(
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
                        Builder(
                          builder: (context) {
                            final screenWidth = MediaQuery.of(context).size.width;
                            final truncatedName = _getTruncatedUsername(userName, isMyPost, screenWidth);
                            return Text(
                              truncatedName,
                              style: const TextStyle(fontSize: 14, color: AppColors.black900, height: 1.5, letterSpacing: -0.32),
                            );
                          },
                        ),
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
                            child: const Text('책 둘러보기',
                                style: TextStyle(fontSize: 14, color: AppColors.black500, height: 1, fontWeight: FontWeight.w400)),
                          ),
                          IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: const Icon(Icons.more_vert),
                              onPressed: () async {
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
                                try {
                                  final userBookApi = UserBookApi(Supabase.instance.client);
                                  await userBookApi.moveToProfile(post.id);
                                  onDeleteSuccess?.call(); // 프로필 이동 후 목록 새로고침
                                } catch (e) {
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
            );
            final userSectionEnd = DateTime.now();
            final userSectionDuration = userSectionEnd.difference(userSectionStart);
            debugPrint('   ⏱️ 사용자 정보 섹션 소요시간: ${userSectionDuration.inMicroseconds}μs');
            return userSectionWidget;
          },
        ),
        const SizedBox(height: 10),
        // 리뷰 제목 섹션
        if (reviewTitle.isNotEmpty)
          Builder(
            builder: (context) {
              final titleSectionStart = DateTime.now();
              debugPrint('   📝 리뷰 제목 섹션 렌더링 시작');
              final titleWidget = Text(
                reviewTitle,
                style: const TextStyle(fontSize: 16, color: AppColors.black900, height: 1.4, letterSpacing: -0.32),
              );
              final titleSectionEnd = DateTime.now();
              final titleSectionDuration = titleSectionEnd.difference(titleSectionStart);
              debugPrint('   ⏱️ 리뷰 제목 섹션 소요시간: ${titleSectionDuration.inMicroseconds}μs');
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: titleWidget,
              );
            },
          ),
        const SizedBox(height: 4),
        // PostContent 섹션 (가장 중요한 부분)
        Builder(
          builder: (context) {
            final contentSectionStart = DateTime.now();
            debugPrint('   📄 PostContent 섹션 렌더링 시작');
            debugPrint('     - reviewContent 길이: ${post.reviewContent?.length ?? 0}');
            debugPrint('     - reviewContent 미리보기: ${post.reviewContent?.substring(0, (post.reviewContent?.length ?? 0).clamp(0, 50))}...');
            
            final contentWidget = Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Container(
                constraints: const BoxConstraints(minHeight: 0),
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  child: PostContent(
                    post: post,
                    fromScreen: fromScreen,
                    onDeleteSuccess: onDeleteSuccess,
                    onEditSuccess: onEditSuccess,
                    onArchiveSuccess: onArchiveSuccess,
                    isMyPost: isMyPost,
                  ),
                ),
              ),
            );
            
            final contentSectionEnd = DateTime.now();
            final contentSectionDuration = contentSectionEnd.difference(contentSectionStart);
            debugPrint('   ⏱️ PostContent 섹션 소요시간: ${contentSectionDuration.inMicroseconds}μs');
            return contentWidget;
          },
        ),
      ],
    );
    
    final widgetBuildEnd = DateTime.now();
    final widgetBuildDuration = widgetBuildEnd.difference(widgetBuildStart);
    stopwatch.stop();
    
    debugPrint('✅ PostItem 렌더링 완료 - ID: ${post.id}');
    debugPrint('   ⏱️ 전체 위젯 빌드 소요시간: ${widgetBuildDuration.inMicroseconds}μs');
    debugPrint('   ⏱️ 전체 렌더링 소요시간: ${stopwatch.elapsedMicroseconds}μs');
    debugPrint('   🚨 렌더링 시간이 16ms(16000μs) 초과 시 렉 발생 가능');
    
    if (stopwatch.elapsedMicroseconds > 16000) {
      debugPrint('⚠️ ⚠️ ⚠️ 렌더링 시간 초과! 렉 발생 가능성 높음! ⚠️ ⚠️ ⚠️');
    }
    
    return result;
  }
}