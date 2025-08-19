import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:my_logue/core/themes/app_colors.dart';
import 'package:my_logue/presentation/screens/add_book/search_book_screen.dart';
import 'package:my_logue/presentation/screens/main_navigation_screen.dart';
import 'package:reorderables/reorderables.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/widgets/book/book_frame.dart';
import '../../../core/widgets/dialogs/book_limit_dialog.dart';
import '../../../data/utils/mixpanel_util.dart';
import 'profile_tab.dart';
import 'archive_tab.dart';

class AddBookScreen extends StatefulWidget {
  final bool isLimitReached;
  final GlobalKey<NavigatorState>? navigatorKey; // AddBookView의 Navigator에 접근하기 위한 키
  final Function(bool)? onLoadingStateChanged; // 로딩 상태 변경 콜백
  
  const AddBookScreen({
    Key? key, 
    required this.isLimitReached,
    this.navigatorKey,
    this.onLoadingStateChanged,
  }) : super(key: key);

  @override
  State<AddBookScreen> createState() => _AddBookScreenState();
}

class _AddBookScreenState extends State<AddBookScreen> {
  late PageController _pageController;
  int _currentIndex = 0; // 0: 보관함 탭, 1: 프로필 탭 (프로필 탭을 기본으로 선택)
  String _profileTabKey = 'profile_${DateTime.now().millisecondsSinceEpoch}';
  String _archiveTabKey = 'archive_${DateTime.now().millisecondsSinceEpoch}';
  
  // 공통 데이터 관리
  List<Map<String, dynamic>> allBooks = [];
  bool isLoading = true;
  bool _isProfileTabLoading = false; // ProfileTab 로딩 상태

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
    
    // 책 추가 화면 방문 트래킹
    MixpanelUtil.trackScreenView('Add Book');
    
    // 데이터 로드
    _fetchAllBooks();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _fetchAllBooks() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      // 모든 책을 가져오기
      final data = await Supabase.instance.client
          .from('user_books')
          .select('id, user_id, order_index, archived_order_index, is_archived, book_id, books(id, image)')
          .eq('user_id', userId);

      final fetched = List<Map<String, dynamic>>.from(data);
      
      // 디버깅: 로드된 데이터 구조 확인
      debugPrint('🔍 _fetchAllBooks - 로드된 데이터 구조:');
      for (int i = 0; i < fetched.length; i++) {
        final book = fetched[i];
        debugPrint('  [$i] ID: ${book['id']}, book_id: ${book['book_id']}, is_archived: ${book['is_archived']}');
      }
      
      // mounted 체크 추가
      if (mounted) {
        setState(() {
          allBooks = fetched;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ 책 불러오기 실패: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void _refreshTabs() {
    // 탭 키 재생성은 필요할 때만 하도록 수정
    // setState(() {
    //   _profileTabKey = 'profile_${DateTime.now().millisecondsSinceEpoch}';
    //   _archiveTabKey = 'archive_${DateTime.now().millisecondsSinceEpoch}';
    // });
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
    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pop(false);
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: const Text('책장', style: TextStyle(color: AppColors.black900, fontSize: 16, fontWeight: FontWeight.w500)),
        ),
        body: Column(
          children: [
            // 탭바
            Container(
              color: Colors.white,
              child: Row(
                children: [
                  _buildTab('보관함', 0),
                  _buildTab('프로필', 1),
                ],
              ),
            ),
            // 탭뷰
            Expanded(
              child: isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.black900,
                      ),
                    )
                  : PageView(
                      controller: _pageController,
                      onPageChanged: (index) {
                        setState(() {
                          _currentIndex = index;
                        });
                        // 탭 전환 시마다 데이터 새로고침 제거 - 무한 루프 방지
                        // _fetchAllBooks();
                      },
                      children: [
                        ArchiveTab(
                          key: ValueKey(_archiveTabKey),
                          books: List.from(allBooks)..sort((a, b) {
                            final aIndex = a['archived_order_index'] ?? 0;
                            final bIndex = b['archived_order_index'] ?? 0;
                            return aIndex.compareTo(bIndex);
                          }),
                          onRefresh: _fetchAllBooks,
                          onBookAdded: () {
                            // 책 추가 시 로딩 상태 활성화
                            if (mounted) {
                              setState(() {
                                isLoading = true;
                              });
                              // 데이터 새로고침 후 로딩 상태 해제
                              _fetchAllBooks().then((_) {
                                if (mounted) {
                                  setState(() {
                                    isLoading = false;
                                  });
                                }
                              });
                            }
                          },
                          navigatorKey: widget.navigatorKey,
                        ),
                        ProfileTab(
                          key: ValueKey(_profileTabKey),
                          isLimitReached: widget.isLimitReached,
                          books: List.from(allBooks.where((book) => book['is_archived'] == false))..sort((a, b) {
                            final aIndex = a['order_index'] ?? 0;
                            final bIndex = b['order_index'] ?? 0;
                            return aIndex.compareTo(bIndex);
                          }),
                          allBooks: allBooks, // 모든 책 목록 전달
                          onRefresh: _fetchAllBooks,
                          onBookAdded: (result) {
                            if (result == true) {
                              // 책 추가가 완료되었을 때 상위로 결과 전달
                              Navigator.of(context).pop(true);
                            }
                          },
                          navigatorKey: widget.navigatorKey,
                          onLoadingStateChanged: (isLoading) {
                            setState(() {
                              _isProfileTabLoading = isLoading;
                            });
                            
                            // 상위 위젯에 로딩 상태 변경 알림
                            widget.onLoadingStateChanged?.call(isLoading);
                          },
                        ),
                      ],
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(String label, int index) {
    final isSelected = _currentIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          _pageController.animateToPage(index, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
          setState(() {
            _currentIndex = index;
          });
        },
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Container(
              height: 30,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppColors.black500, width: 1),
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? AppColors.black900 : AppColors.black500,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w400,
                  fontSize: 14,
                ),
              ),
            ),
            if (isSelected)
              const Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Divider(
                  thickness: 2,
                  height: 0,
                  color: AppColors.black900,
                ),
              ),
          ],
        ),
      ),
    );
  }
}