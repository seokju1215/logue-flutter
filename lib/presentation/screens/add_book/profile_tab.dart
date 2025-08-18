import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:my_logue/core/themes/app_colors.dart';
import 'package:my_logue/presentation/screens/add_book/search_book_screen.dart';
import 'package:reorderables/reorderables.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_logue/data/datasources/user_book_api.dart';
import 'package:my_logue/presentation/screens/home/home_recommand_tab.dart';

import '../../../core/themes/stroke_text_style.dart';
import '../../../core/widgets/book/book_frame.dart';
import '../../../core/widgets/dialogs/book_limit_dialog.dart';
import '../../../core/widgets/dialogs/archive_bottom_sheet.dart';
import '../../../data/models/book_model.dart';

class ProfileTab extends StatefulWidget {
  final bool isLimitReached;
  final List<Map<String, dynamic>> books;
  final List<Map<String, dynamic>> allBooks; // 모든 책 목록 (보관함 포함)
  final VoidCallback onRefresh;

  final Function(bool)? onBookAdded; // 책 추가 완료 콜백
  final GlobalKey<NavigatorState>?
      navigatorKey; // AddBookView의 Navigator에 접근하기 위한 키

  const ProfileTab({
    Key? key,
    required this.isLimitReached,
    required this.books,
    required this.allBooks,
    required this.onRefresh,

    this.onBookAdded,
    this.navigatorKey,
  }) : super(key: key);

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final client = Supabase.instance.client;
  List<String> originalOrder = [];
  bool isEdited = false;
  final GlobalKey _titleKey = GlobalKey(); // 텍스트 위젯의 위치를 측정하기 위한 키
  bool _isUpdatingBooks = false; // 책 변경 로딩 상태
  


  @override
  void initState() {
    super.initState();
    _updateOriginalOrder();
  }

  void _updateOriginalOrder() {
    setState(() {
      originalOrder = widget.books.map((book) => book['id'] as String).toList();
      isEdited = false;
    });
  }

  Future<void> _updateBookOrder() async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;
    
    // DB 업데이트
    for (int i = 0; i < widget.books.length; i++) {
      final bookId = widget.books[i]['id'];
      await client
          .from('user_books')
          .update({'order_index': i}).eq('id', bookId);
    }

    setState(() {
      originalOrder = widget.books.map((b) => b['id'] as String).toList();
      isEdited = false;
    });
    
    // 부모 위젯에게 순서 변경 알림 (새로고침 요청)
    widget.onRefresh();
    

  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      final item = widget.books.removeAt(oldIndex);
      widget.books.insert(newIndex, item);

      final currentOrder = widget.books.map((b) => b['id'] as String).toList();
      isEdited = !_areListsEqual(currentOrder, originalOrder);
    });

    // 드래그 앤 드롭 후 즉시 데이터베이스 업데이트
    _updateBookOrder();
  }

  bool _areListsEqual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// archived_order_index 기준으로 책들을 정렬하는 메서드
  List<Map<String, dynamic>> _getSortedBooks() {
    final sortedBooks = List<Map<String, dynamic>>.from(widget.allBooks);

    // 디버깅: allBooks 데이터 구조 확인
    print('🔍 _getSortedBooks - allBooks 데이터 구조:');
    for (int i = 0; i < sortedBooks.length; i++) {
      final book = sortedBooks[i];
      print('  [$i] ID: ${book['id']}, book_id: ${book['book_id']}, is_archived: ${book['is_archived']}');
    }

    // archived_order_index 기준으로 정렬
    sortedBooks.sort((a, b) {
      final aOrder = a['archived_order_index'] as int? ?? 0;
      final bOrder = b['archived_order_index'] as int? ?? 0;
      return aOrder.compareTo(bOrder);
    });

    // 디버깅: 정렬 후 데이터 확인
    print('🔍 _getSortedBooks - 정렬 후 데이터:');
    for (int i = 0; i < sortedBooks.length; i++) {
      final book = sortedBooks[i];
      print('  [$i] ID: ${book['id']}, book_id: ${book['book_id']}, is_archived: ${book['is_archived']}, archived_order_index: ${book['archived_order_index']}');
    }

    return sortedBooks;
  }

  ButtonStyle _outlinedStyle(BuildContext context) {
    return ButtonStyle(
      foregroundColor: MaterialStateProperty.all(AppColors.black900),
      backgroundColor: MaterialStateProperty.all(Colors.white),
      overlayColor: MaterialStateProperty.resolveWith<Color?>(
        (states) {
          if (states.contains(MaterialState.pressed)) {
            return AppColors.black100;
          }
          return null;
        },
      ),
      side: MaterialStateProperty.all(
        const BorderSide(color: AppColors.black500, width: 1),
      ),
      shape: MaterialStateProperty.all(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      padding: MaterialStateProperty.all(
        const EdgeInsets.symmetric(horizontal: 9),
      ),
      minimumSize: MaterialStateProperty.all(
        const Size(0, 34),
      ),
      textStyle: MaterialStateProperty.all(
        const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          height: 1.0,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SingleChildScrollView(
          primary: false,
          padding: const EdgeInsets.fromLTRB(0, 21, 0, 21),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 22),
                child: Stack(
                  key: _titleKey, // GlobalKey 추가
                  children: [
                    StrokeTextStyle.createStrokeText(
                        text: "인생 책을 골라 프로필에 소개해보세요.",
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: AppColors.black900),
                  ],
                ),
              ),
              const SizedBox(height: 13),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 21),
                child: Row(
                  children: [
                    const Expanded(child: SizedBox()),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          // 현재 책 개수로 limit 확인

                          // ArchiveBottomSheet 표시
                          showModalBottomSheet(
                            context: context,
                            useRootNavigator: true,
                            isScrollControlled: true,
                            isDismissible: false, // 바텀 시트를 완전히 내려야만 닫힘
                            backgroundColor: Colors.transparent,
                            barrierColor: Colors.transparent,
                            builder: (BuildContext context) {
                              // GlobalKey를 사용하여 텍스트 위젯의 위치 측정
                              final RenderBox? titleBox = _titleKey.currentContext
                                  ?.findRenderObject() as RenderBox?;
                              final titlePosition =
                                  titleBox?.localToGlobal(Offset.zero);
                              final titleBottom = titlePosition?.dy ?? 0;

                              return Stack(
                                children: [
                                  // 배경 터치 영역
                                  Positioned.fill(
                                    child: GestureDetector(
                                      onTap: () => Navigator.pop(context),
                                      child: Container(color: Colors.transparent),
                                    ),
                                  ),
                                  // 바텀시트
                                  Positioned(
                                    top: titleBottom +
                                        (titleBox?.size.height ?? 0) +
                                        8,
                                    // 텍스트 위젯 바로 밑 + 8px
                                    left: 0,
                                    right: 0,
                                    bottom: 0,
                                    child: ArchiveBottomSheet(
                                      books: _getSortedBooks(),
                                      onClose: () {
                                        // 바텀 시트가 닫힐 때만 호출됨
                                        debugPrint('🔒 ArchiveBottomSheet 완전히 닫힘 - 선택 상태 초기화');
                                        setState(() {});
                                      },
                                      // archived_order_index 기준으로 정렬된 책 목록 전달
                                      onBooksUpdated: (updatedBooks) async {
                                        // 로딩 상태 시작
                                        if (!mounted) return;
                                        setState(() {
                                          _isUpdatingBooks = true;
                                        });
                                        
                                        // 저장 버튼을 눌렀을 때만 실행되는 DB 저장 로직
                                        print(
                                            '📚 DB 저장 시작: ${updatedBooks.length}개 책 업데이트');
                                        print('🔍 updatedBooks 내용:');
                                        for (int i = 0;
                                            i < updatedBooks.length;
                                            i++) {
                                          final book = updatedBooks[i];
                                          print(
                                              '  [$i] ID: ${book['id']}, book_id: ${book['book_id']}, is_archived: ${book['is_archived']}, order_index: ${book['order_index']}');
                                        }
                                        
                                        // 디버깅: updatedBooks의 모든 키 확인
                                        if (updatedBooks.isNotEmpty) {
                                          print('🔍 updatedBooks[0]의 모든 키: ${updatedBooks[0].keys.toList()}');
                                          print('🔍 updatedBooks[0]의 전체 데이터: ${updatedBooks[0]}');
                                        }

                                        print('🔍 widget.books 내용:');
                                        for (int i = 0;
                                            i < widget.books.length;
                                            i++) {
                                          final book = widget.books[i];
                                          print(
                                              '  [$i] ID: ${book['id']}, book_id: ${book['book_id']}, is_archived: ${book['is_archived']}, order_index: ${book['order_index']}');
                                        }

                                        try {
                                          // DB 업데이트 로직 구현
                                          final userBookApi =
                                              UserBookApi(Supabase.instance.client);

                                          // 새로 프로필에 추가된 책이 있는지 확인 (보관함 → 프로필로 이동한 책)
                                          final newlyAddedBooks =
                                              <Map<String, dynamic>>[];

                                          // 원래 프로필에 있던 책들의 ID 목록
                                          final originalProfileBookIds = widget
                                              .books
                                              .map((book) => book['id'] as String)
                                              .toSet();
                                          print(
                                              '🔍 원래 프로필에 있던 책 ID들: $originalProfileBookIds');

                                          // 업데이트된 책들 중 프로필로 이동한 책 찾기
                                          for (final updatedBook in updatedBooks) {
                                            final updatedBookId =
                                                updatedBook['id'] as String;
                                            final updatedIsArchived =
                                                updatedBook['is_archived'] as bool;

                                            // 프로필로 이동한 책이고, 원래 프로필에 없던 책인지 확인
                                            if (updatedIsArchived == false &&
                                                !originalProfileBookIds
                                                    .contains(updatedBookId)) {
                                              newlyAddedBooks.add(updatedBook);
                                              print(
                                                  '🔍 새로 프로필에 추가된 책 발견: ID=${updatedBookId}, book_id=${updatedBook['book_id']}');
                                            }
                                          }

                                          print(
                                              '🔍 새로 프로필에 추가된 책 개수: ${newlyAddedBooks.length}');
                                          
                                          print('🔄 updateBooksBatch 호출 시작');
                                          // 일괄 업데이트로 모든 책의 is_archived와 order_index 업데이트
                                          await userBookApi.updateBooksBatch(updatedBooks);
                                          print('🔄 updateBooksBatch 호출 완료');
                                          
                                          // mounted 체크 - 위젯이 dispose되었는지 확인
                                          if (!mounted) {
                                            print('⚠️ 위젯이 dispose됨 - 추가 작업 중단');
                                            return;
                                          }

                                          // 홈 화면의 인생책이 겹치는 친구 목록 캐시 새로고침
                                          try {
                                            HomeRecommendTab.refreshUsersWithSameBooks();
                                            print('🔄 보관함 변경 후 홈 화면 친구 목록 캐시 새로고침 요청');
                                          } catch (e) {
                                            print('⚠️ 홈 화면 캐시 새로고침 실패: $e');
                                          }
                                          
                                          if (newlyAddedBooks.isNotEmpty) {
                                            print('🎯 ===== 팔로워 알림 전송 시작 =====');
                                            print('🔍 새로 추가된 책들 (${newlyAddedBooks.length}개):');
                                            for (final book in newlyAddedBooks) {
                                              print(
                                                  '  - ID: ${book['id']}, book_id: ${book['book_id']}');
                                            }

                                            // 새로 추가된 책들에 대해 팔로워들에게 알림 전송
                                            final currentUserId =
                                                client.auth.currentUser?.id;
                                            if (currentUserId != null) {
                                              print('👤 현재 사용자 ID: $currentUserId');
                                              for (int i = 0; i < newlyAddedBooks.length; i++) {
                                                // 각 알림 전송 전에 mounted 체크
                                                if (!mounted) {
                                                  print('⚠️ 위젯이 dispose됨 - 알림 전송 중단');
                                                  return;
                                                }
                                                
                                                final book = newlyAddedBooks[i];
                                                final userBookId = book['id'] as String?;
                                                if (userBookId != null) {
                                                  print(
                                                      '📢 [$i] 알림 전송 시도: userId=$currentUserId, userBookId=$userBookId');
                                                  
                                                  try {
                                                    await userBookApi
                                                        .notifyFollowersAboutNewBook(
                                                            currentUserId, userBookId);
                                                    print('✅ [$i] 알림 전송 성공: userBookId=$userBookId');
                                                  } catch (e) {
                                                    print('❌ [$i] 알림 전송 실패: userBookId=$userBookId, error=$e');
                                                    // 알림 전송 실패는 치명적이지 않으므로 계속 진행
                                                  }
                                                } else {
                                                  print('❌ [$i] user_books ID가 null: ID=${book['id']}');
                                                }
                                              }
                                              print('🎯 ===== 팔로워 알림 전송 완료 =====');
                                            } else {
                                              print('❌ 현재 사용자 ID를 가져올 수 없음');
                                            }
                                          }

                                          print('✅ DB 업데이트 완료');

                                          // mounted 체크 - 위젯이 dispose되었는지 확인
                                          if (!mounted) {
                                            print('⚠️ 위젯이 dispose됨 - UI 업데이트 중단');
                                            return;
                                          }

                                          // DB 저장 완료 후 프로필 탭 새로고침
                                          print('🔄 widget.onRefresh() 호출');
                                          widget.onRefresh();

                                        } catch (e) {
                                          print('❌ DB 업데이트 실패: $e');
                                          print('❌ 에러 스택: ${StackTrace.current}');
                                          
                                          // mounted 체크 후 에러 표시
                                          if (mounted) {
                                            // 에러 발생 시 사용자에게 알림
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                  content:
                                                      Text('저장 중 오류가 발생했습니다: $e')),
                                            );
                                          }
                                        } finally {
                                          // 로딩 상태 해제 - mounted 체크 필수
                                          if (mounted) {
                                            setState(() {
                                              _isUpdatingBooks = false;
                                            });
                                          }
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                        style: _outlinedStyle(context),
                        child: const Text(
                          '책 선택',
                          style: TextStyle(
                              fontSize: 13,
                              color: AppColors.black900,
                              height: 1.25),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 33),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '책을 길게 눌러 위치를 변경할 수 있어요.',
                      style: TextStyle(fontSize: 12, color: AppColors.black500),
                    ),
                    Text(
                      '${widget.books.where((book) => book['is_archived'] == false).length}/9',
                      style:
                          const TextStyle(fontSize: 13, color: AppColors.black500),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 26),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    const crossAxisCount = 3;
                    const crossAxisSpacing = 23.0;
                    const mainAxisSpacing = 30.0;
                    const itemAspectRatio = 98 / 145;

                    final totalSpacing = crossAxisSpacing * (crossAxisCount - 1);
                    final itemWidth =
                        (constraints.maxWidth - totalSpacing) / crossAxisCount;
                    final itemHeight = itemWidth / itemAspectRatio;

                    return ReorderableWrap(
                      spacing: crossAxisSpacing,
                      runSpacing: mainAxisSpacing,
                      needsLongPressDraggable: true,
                      onReorder: _onReorder,
                      children: widget.books.map((book) {
                        return GestureDetector(
                          child: SizedBox(
                            key: ValueKey(book['id']),
                            width: itemWidth,
                            height: itemHeight,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(0),
                              child: BookFrame(
                                imageUrl: book['books']?['image'] ??
                                    'https://via.placeholder.com/150',
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        // 로딩 오버레이
        if (_isUpdatingBooks)
          Container(
            color: Colors.black.withOpacity(0.7),
            child: const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 3,
              ),
            ),
          ),
      ],
    );
  }
}
