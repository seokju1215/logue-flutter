import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:my_logue/core/themes/app_colors.dart';
import 'package:my_logue/presentation/screens/add_book/search_book_screen.dart';
import 'package:my_logue/presentation/screens/main_navigation_screen.dart';
import 'package:reorderables/reorderables.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/widgets/book/book_frame.dart';
import '../../../core/widgets/dialogs/book_limit_dialog.dart';
import '../../../core/services/book_data_service.dart';
import '../../../data/utils/mixpanel_util.dart';
import 'profile_tab.dart';
import 'archive_tab.dart';

class AddBookScreen extends StatefulWidget {
  final bool isLimitReached;
  final GlobalKey<NavigatorState>? navigatorKey; // AddBookView의 Navigator에 접근하기 위한 키
  final Function(bool)? onLoadingStateChanged; // 로딩 상태 변경 콜백
  
  // 새로운 파라미터들 - 상위에서 관리되는 데이터
  final List<Map<String, dynamic>> persistentAllBooks; // 지속적인 데이터
  final bool hasInitializedData; // 데이터 초기화 여부
  final Future<void> Function()? onRefreshData; // 데이터 새로고침 콜백
  final Function(List<Map<String, dynamic>>)? onUpdateLocalBooks; // 로컬 데이터 업데이트 콜백

  const AddBookScreen({
    Key? key,
    required this.isLimitReached,
    this.navigatorKey,
    this.onLoadingStateChanged,
    required this.persistentAllBooks,
    required this.hasInitializedData,
    this.onRefreshData,
    this.onUpdateLocalBooks,
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

  // 로컬 상태 (상위에서 전달받은 데이터 사용)
  late List<Map<String, dynamic>> allBooks;
  bool isLoading = true;
  bool _isProfileTabLoading = false; // ProfileTab 로딩 상태
  
  // BookDataService 인스턴스
  late final BookDataService _bookDataService;
  
  // ArchiveTab의 State에 접근하기 위한 GlobalKey
  final GlobalKey<State<ArchiveTab>> _archiveTabStateKey = GlobalKey<State<ArchiveTab>>();
  
  // archive_tab의 변경사항 상태 추적
  bool _hasArchiveChanges = false;
  
  // archive_bottom_sheet에 즉시 순서 변경 알림을 위한 콜백
  VoidCallback? _notifyArchiveBottomSheet;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0); // 프로필 탭을 기본으로 설정

    // BookDataService 초기화
    _bookDataService = BookDataService();

    // 화면 방문 트래킹
    MixpanelUtil.trackScreenView('Add Book');

    // 상위에서 전달받은 데이터 사용
    _initializeWithPersistentData();
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

  /// 상위에서 전달받은 지속 데이터로 초기화
  void _initializeWithPersistentData() {
    debugPrint('📚 AddBookScreen - 지속 데이터로 초기화: ${widget.persistentAllBooks.length}개 책');
    
    setState(() {
      allBooks = List<Map<String, dynamic>>.from(widget.persistentAllBooks);
      isLoading = !widget.hasInitializedData; // 초기화가 완료되었으면 로딩 해제
    });
    
    // 초기화가 완료되지 않았다면 기다림
    if (!widget.hasInitializedData) {
      _waitForInitialization();
    }
  }

  /// 초기화 완료까지 대기
  Future<void> _waitForInitialization() async {
    debugPrint('⏳ AddBookScreen - 초기화 완료 대기 중...');
    
    // 최대 5초까지 기다림
    for (int i = 0; i < 50; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      
      if (widget.hasInitializedData && mounted) {
        setState(() {
          allBooks = List<Map<String, dynamic>>.from(widget.persistentAllBooks);
          isLoading = false;
        });
        debugPrint('✅ AddBookScreen - 초기화 완료: ${allBooks.length}개 책');
        break;
      }
    }
  }

  /// 수동 새로고침 (필요시에만 호출) - 상위 데이터 새로고침 사용
  Future<void> _fetchAllBooks() async {
    debugPrint('🔄 AddBookScreen - 수동 새로고침 요청');
    
    if (widget.onRefreshData != null) {
      // 상위에서 데이터 새로고침
      await widget.onRefreshData!();
      
      // 새로고침된 데이터로 로컬 상태 업데이트
      if (mounted) {
        setState(() {
          allBooks = List<Map<String, dynamic>>.from(widget.persistentAllBooks);
          isLoading = false;
        });
        
        // ProfileTab 키를 새로 생성하여 강제 리빌드 (데이터 변경 즉시 반영)
        _profileTabKey = 'profile_${DateTime.now().millisecondsSinceEpoch}';
        debugPrint('🔄 ProfileTab 키 새로 생성: $_profileTabKey');
      }
      debugPrint('✅ AddBookScreen - 새로고침 완료: ${allBooks.length}개 책');
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
    // ProfileTab에 전달할 books 리스트를 computed property로 생성
    final profileBooks = allBooks
        .where((book) => book['is_archived'] == false)
        .toList()
      ..sort((a, b) {
        final aIndex = a['order_index'] ?? 0;
        final bIndex = b['order_index'] ?? 0;
        return aIndex.compareTo(bIndex);
      });
    
    return WillPopScope(
      // ✅ 뒤로가기 방지 (바텀 네비게이션 내부 화면이므로)
      onWillPop: () async {
        // 보관함 변경사항 저장
        final archiveTabState = _archiveTabStateKey.currentState;
        if (archiveTabState != null) {
          await (archiveTabState as dynamic).flushPendingChanges();
        }
        // 뒤로가기 차단 (바텀 네비게이션에서 관리)
        return false;
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
                    _buildTab('대표', 0),
                    _buildTab('전체', 1),
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
                    books: profileBooks, // computed property 사용
                    allBooks: allBooks, // 모든 책 목록
                    onRefresh: _fetchAllBooks,
                    onBookAdded: (result) {
                      // 책 추가 완료 시 데이터만 새로고침 (Navigator.pop 제거)
                      if (result == true) {
                        debugPrint('📚 책 추가 완료 - 데이터 새로고침');
                        _fetchAllBooks();
                      }
                    },
                    navigatorKey: widget.navigatorKey,
                    onLoadingStateChanged: (isLoading) {
                      setState(() {
                        _isProfileTabLoading = isLoading;
                      });
                      widget.onLoadingStateChanged?.call(isLoading);
                    },
                    onRegisterArchiveNotificationCallback: (callback) {
                      debugPrint('🔗 ArchiveBottomSheet 알림 콜백 등록');
                      _notifyArchiveBottomSheet = callback;
                    },
                  ),
                  ArchiveTab(
                    key: _archiveTabStateKey, // GlobalKey 사용
                    allBooks: allBooks, // 모든 책 목록 전달
                    bookDataService: _bookDataService, // BookDataService 전달
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
                      
                      // 상위 AddBookView에도 변경사항 전달 (지속성을 위해)
                      widget.onUpdateLocalBooks?.call(updatedBooks);
                    },
                    onArchiveOrderChanged: () {
                      debugPrint('🔄 ArchiveTab 순서 변경 - archive_bottom_sheet에 즉시 알림');
                      // archive_bottom_sheet에 즉시 알림 (업데이트된 allBooks와 함께)
                      _notifyArchiveBottomSheet?.call();
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