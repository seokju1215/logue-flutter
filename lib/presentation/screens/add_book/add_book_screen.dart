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
  bool get _tabsDisabled => isLoading || _isProfileTabLoading;
  late PageController _pageController;
  int _currentIndex = 0; // 0: 프로필 탭, 1: 보관함 탭
  String _profileTabKey = 'profile_${DateTime.now().millisecondsSinceEpoch}';
  String _archiveTabKey = 'archive_${DateTime.now().millisecondsSinceEpoch}';
  void focusArchiveTab() {
    _pageController.jumpToPage(1);
    setState(() => _currentIndex = 1);
  }

  // 공통 데이터 관리
  List<Map<String, dynamic>> allBooks = [];
  bool isLoading = true;
  bool _isProfileTabLoading = false; // ProfileTab 로딩 상태
  
  // ArchiveTab의 State에 접근하기 위한 GlobalKey
  final GlobalKey<State<ArchiveTab>> _archiveTabStateKey = GlobalKey<State<ArchiveTab>>();
  
  // archive_tab의 변경사항 상태 추적
  bool _hasArchiveChanges = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0); // 프로필 탭을 기본으로 설정

    // 화면 방문 트래킹
    MixpanelUtil.trackScreenView('Add Book');

    // 데이터 로드
    _fetchAllBooks();
  }

  @override
  void deactivate() {
    // 화면이 비활성화될 때 보관함 변경사항 자동 저장
    final archiveTabState = _archiveTabStateKey.currentState;
    if (archiveTabState != null) {
      debugPrint('🔄 AddBookScreen deactivate - ArchiveTab 변경사항 자동 저장');
      // 타입 캐스팅을 통해 flushPendingChanges 호출
      (archiveTabState as dynamic).flushPendingChanges();
    }
    super.deactivate();
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
      final data = await Supabase.instance.client
          .from('user_books')
          .select(
          'id, user_id, order_index, archived_order_index, is_archived, book_id, books(id, image)')
          .eq('user_id', userId);

      final fetched = List<Map<String, dynamic>>.from(data);

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

  ButtonStyle _outlinedStyle(BuildContext context) {
    return ButtonStyle(
      foregroundColor: MaterialStateProperty.all(AppColors.black900),
      backgroundColor: MaterialStateProperty.all(Colors.white),
      overlayColor: MaterialStateProperty.resolveWith<Color?>(
            (states) => states.contains(MaterialState.pressed) ? AppColors.black100 : null,
      ),
      side: MaterialStateProperty.all(
        const BorderSide(color: AppColors.black500, width: 1),
      ),
      shape: MaterialStateProperty.all(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      padding: MaterialStateProperty.all(const EdgeInsets.symmetric(horizontal: 9)),
      minimumSize: MaterialStateProperty.all(const Size(0, 34)),
      textStyle: MaterialStateProperty.all(
        const TextStyle(fontSize: 12, fontWeight: FontWeight.w400, height: 1.0),
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      // ✅ 떠날 때 보관함 순서 저장
              onWillPop: () async {
          // 뒤로가기 시 보관함 변경사항 저장
          final archiveTabState = _archiveTabStateKey.currentState;
          if (archiveTabState != null) {
            await (archiveTabState as dynamic).flushPendingChanges();
          }
          Navigator.of(context).pop(false);
          return true;
        },
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: const Text(
            '책장',
            style: TextStyle(
              color: AppColors.black900,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        body: Column(
          children: [
            // 탭바
            Container(
              color: Colors.white,
              child: AbsorbPointer(
                absorbing: _tabsDisabled, // 로딩 중 탭 터치 차단
                child: Row(
                  children: [
                    _buildTab('프로필', 0),
                    _buildTab('보관함', 1),
                  ],
                ),
              ),
            ),
            // 탭뷰
            Expanded(
              child: isLoading
                  ? const Center(
                child: CircularProgressIndicator(color: AppColors.black900),
              )
                  : PageView(
                controller: _pageController,
                physics: _tabsDisabled
                    ? const NeverScrollableScrollPhysics()
                    : const ClampingScrollPhysics(),
                onPageChanged: (index) async {
                  debugPrint('🔄 PageView 변경: 현재=$_currentIndex, 목표=$index, 변경사항=$_hasArchiveChanges');
                  
                  // ✅ 보관함(1) → 다른 탭으로 넘어갈 때 저장 (백그라운드에서)
                  if (_currentIndex == 1 && index != 1 && _hasArchiveChanges) {
                    debugPrint('🔄 PageView에서 보관함 변경사항 저장 시작 (백그라운드)');
                    final archiveTabState = _archiveTabStateKey.currentState;
                    if (archiveTabState != null) {
                      // 백그라운드에서 저장 실행 (await 제거)
                      (archiveTabState as dynamic).flushPendingChanges().then((_) {
                        if (mounted) {
                          setState(() {
                            _hasArchiveChanges = false;
                          });
                          debugPrint('✅ PageView에서 보관함 변경사항 저장 완료 (백그라운드)');
                        }
                      });
                    }
                  }
                  
                  // 즉시 _currentIndex 업데이트 (저장 완료 기다리지 않음)
                  if (mounted) {
                    debugPrint('🔄 PageView _currentIndex 업데이트: $_currentIndex → $index');
                    setState(() {
                      _currentIndex = index;
                    });
                  }
                },
                children: [
                  ProfileTab(
                    key: ValueKey(_profileTabKey),
                    isLimitReached: widget.isLimitReached,
                    books: List.from(
                      allBooks.where((book) => book['is_archived'] == false),
                    )..sort((a, b) {
                      final aIndex = a['order_index'] ?? 0;
                      final bIndex = b['order_index'] ?? 0;
                      return aIndex.compareTo(bIndex);
                    }),
                    allBooks: allBooks, // 모든 책 목록
                    onRefresh: _fetchAllBooks,
                    onBookAdded: (result) {
                      if (result == true) {
                        Navigator.of(context).pop(true);
                      }
                    },
                    navigatorKey: widget.navigatorKey,
                    onLoadingStateChanged: (isLoading) {
                      setState(() {
                        _isProfileTabLoading = isLoading;
                      });
                      widget.onLoadingStateChanged?.call(isLoading);
                    },
                  ),
                  ArchiveTab(
                    key: _archiveTabStateKey, // GlobalKey 사용
                    allBooks: allBooks, // 모든 책 목록 전달
                    onRefresh: _fetchAllBooks,
                    onFocusMe: focusArchiveTab,
                    onBookAdded: () {
                      if (mounted) {
                        setState(() {
                          isLoading = true;
                        });
                        _fetchAllBooks().then((_) {
                          if (mounted) {
                            setState(() {
                              isLoading = false;
                            });
                          }
                        });
                      }
                    },
                    onBooksChanged: (updatedBooks) {
                      debugPrint('🔄 onBooksChanged 호출됨: ${updatedBooks.length}개 책');
                      // 보관함 책 순서 로컬 반영
                      setState(() {
                        for (int i = 0; i < updatedBooks.length; i++) {
                          final bookId = updatedBooks[i]['id'];
                          final idx = allBooks.indexWhere((b) => b['id'] == bookId);
                          if (idx != -1) {
                            allBooks[idx]['archived_order_index'] = i;
                          }
                        }
                        // 변경사항 상태 업데이트
                        _hasArchiveChanges = true;
                        debugPrint('✅ _hasArchiveChanges = true로 설정');
                      });
                    },
                    navigatorKey: widget.navigatorKey,
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
    debugPrint('🔍 _buildTab: $label, index=$index, _currentIndex=$_currentIndex, isSelected=$isSelected');

    return Expanded(
      child: GestureDetector(
        onTap: () async {
          if (_tabsDisabled) return;

          debugPrint('🔍 탭 클릭: 현재=$_currentIndex, 목표=$index, 변경사항=$_hasArchiveChanges');

          // ✅ 보관함(1)에서 다른 탭으로 탭 클릭 이동 시에도 저장 (백그라운드에서)
          if (_currentIndex == 1 && index != 1 && _hasArchiveChanges) {
            debugPrint('🔄 보관함 변경사항 저장 시작 (백그라운드)');
            final archiveTabState = _archiveTabStateKey.currentState;
            if (archiveTabState != null) {
              // 백그라운드에서 저장 실행 (await 제거)
              (archiveTabState as dynamic).flushPendingChanges().then((_) {
                if (mounted) {
                  setState(() {
                    _hasArchiveChanges = false;
                  });
                  debugPrint('✅ 보관함 변경사항 저장 완료 (백그라운드)');
                }
              });
            }
          }

          // 즉시 탭 이동 (저장 완료 기다리지 않음)
          _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeInOut,
          ).then((_) {
            if (mounted) {
              debugPrint('🔄 animateToPage 완료, _currentIndex 업데이트: $_currentIndex → $index');
              setState(() {
                _currentIndex = index;
              });
            }
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