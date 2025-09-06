import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:my_logue/core/themes/app_colors.dart';
import 'package:my_logue/core/widgets/book/book_frame.dart';
import 'package:my_logue/core/widgets/book/user_book_grid.dart';
import 'package:my_logue/presentation/screens/main_navigation_screen.dart';
import 'package:my_logue/presentation/screens/post/my_post_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ProfileBooksTabViewState를 외부에서 접근 가능하게 함

class ProfileBooksTabView extends StatefulWidget {
  final List<Map<String, dynamic>> nonArchivedBooks;
  final String userId;
  final ScrollController? parentScrollController;
  final bool isOtherUser;
  final VoidCallback? onBubbleHide;
  final ValueChanged<bool>? onBubbleStateChanged;
  final Map<String, dynamic>? profile;

  const ProfileBooksTabView({
    super.key,
    required this.nonArchivedBooks,
    required this.userId,
    this.parentScrollController,
    this.isOtherUser = false,
    this.onBubbleHide,
    this.onBubbleStateChanged,
    this.profile,
  });

  @override
  State<ProfileBooksTabView> createState() => ProfileBooksTabViewState();
}

class ProfileBooksTabViewState extends State<ProfileBooksTabView> {
  late PageController pageController;
  late ScrollController booksScrollController;
  int currentIndex = 0;
  final _client = Supabase.instance.client;
  bool _showBubble = false; // 말풍선 표시 상태
  

  
  // ===== 페이지네이션 상태 =====
  static const int _pageSize = 200;
  int _offset = 0;
  bool _isInitialLoading = true;   // 첫 로딩 스피너
  bool _isPageLoading = false;     // 다음 페이지 로딩 중
  bool _hasMore = true;            // 더 불러올 페이지 존재 여부
  int _totalCount = 0;             // 서버 total_count
  
  // ===== 로컬 상태 =====
  final List<Map<String, dynamic>> _localArchivedBooks = []; // 페이지를 쌓아서 보관
  
  // ===== 실시간 업데이트 구독 =====
  RealtimeChannel? _bookChannel;

  @override
  void initState() {
    super.initState();
    pageController = PageController(initialPage: 0);
    booksScrollController = ScrollController();
    _fetchTotalCount();
    _loadNextPage();
    _subscribeToBookUpdates();
    
    // 말풍선 표시 로직 체크
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!widget.isOtherUser) {
        _checkAndShowBubble();
      }
    });
  }

  Future<void> _fetchTotalCount() async {
    try {
      // 새로운 RPC 함수에서 total_count를 가져오기 위해 첫 번째 페이지 조회
      final rpc = await _client.rpc(
        'get_other_user_archived_books_page',
        params: {
          'p_user_id': widget.userId,
          'p_limit': 1,
          'p_offset': 0,
        },
      ) as List<dynamic>;

      int count = 0;
      if (rpc.isNotEmpty) {
        count = (rpc.first['total_count'] as int?) ?? 0;
      }

      if (mounted) {
        setState(() => _totalCount = count);
      }
    } catch (e) {
      debugPrint('❌ 총 권수 가져오기 실패: $e');
      if (mounted) {
        setState(() => _totalCount = 0);
      }
    }
  }

  Future<void> _loadNextPage() async {
    if (_isPageLoading || !_hasMore) return;

    // 초기 로딩 중일 때는 _isPageLoading을 설정하지 않음
    if (!_isInitialLoading) {
      setState(() {
        _isPageLoading = true;
      });
    }

    try {
      // 1) 새로운 RPC 함수로 다른 사용자의 책 가져오기
      final rpc = await _client.rpc(
        'get_other_user_archived_books_page',
        params: {
          'p_user_id': widget.userId,
          'p_limit': _pageSize,
          'p_offset': _offset,
        },
      ) as List<dynamic>;

      final rows = rpc.cast<Map<String, dynamic>>();

      // total_count 추출
      if (rows.isNotEmpty) {
        _totalCount = (rows.first['total_count'] as int?) ?? 0;
      }

      // 2) rows + archived_order_index 타입 보장 (이미 books 정보 포함됨)
      final pageItems = rows.map((e) {
        final item = {
          ...e,
        };
        
        // archived_order_index를 강제로 double 타입으로 변환 (소수점 값 보존)
        
        return item;
      }).toList();

      // 4) 로컬 리스트에 추가 (기존 archived_order_index 값 보존)
      if (mounted) {
        setState(() {
          // 새 데이터만 추가 (중복 방지)
          for (final newBook in pageItems) {
            // 이미 존재하는 책인지 확인
            final existingIndex = _localArchivedBooks.indexWhere(
              (book) => book['id'] == newBook['id'],
            );
            
            if (existingIndex == -1) {
              // 새 책이면 추가
              _localArchivedBooks.add(newBook);
            } else {
              // 기존 책이면 archived_order_index 값만 업데이트 (소수점 보존)
              final existingBook = _localArchivedBooks[existingIndex];
              if (existingBook['archived_order_index'] != null && 
                  existingBook['archived_order_index'] is double) {
                newBook['archived_order_index'] = existingBook['archived_order_index'];
                debugPrint('🔄 archived_order_index 값 보존: ${newBook['id']} -> ${existingBook['archived_order_index']}');
              }
              // 기존 책을 새 데이터로 교체
              _localArchivedBooks[existingIndex] = newBook;
            }
          }
          
          // archived_order_index 순서대로 정렬
          _localArchivedBooks.sort((a, b) {
            final aIndex = (a['archived_order_index'] as num?)?.toDouble() ?? 0.0;
            final bIndex = (b['archived_order_index'] as num?)?.toDouble() ?? 0.0;
            return aIndex.compareTo(bIndex);
          });
          
          _offset += rows.length;
          _hasMore = _offset < _totalCount;
          _isInitialLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ 페이지 로드 실패: $e');
    } finally {
      if (mounted && !_isInitialLoading) {
        setState(() => _isPageLoading = false);
      }
    }
  }

  void _subscribeToBookUpdates() {
    // 이미 구독 중이면 중복 구독 방지
    if (_bookChannel != null) return;

    _bookChannel = _client.channel('public:user_books')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'user_books',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'user_id',
          value: widget.userId,
        ),
        callback: (payload) async {
          if (!mounted) return;
          
          // archive_tab에서 순서 변경 시 ProfileBooksTabView도 새로고침
          debugPrint('🔄 ProfileBooksTabView - user_books 변경 감지: ${payload.eventType}');
          
          // 로컬 데이터 초기화 후 다시 로드
          setState(() {
            _localArchivedBooks.clear();
            _offset = 0;
            _hasMore = true;
          });
          
          // 데이터 다시 로드
          await _fetchTotalCount();
          await _loadNextPage();
        },
      )
      ..subscribe();
  }

  @override
  void dispose() {
    pageController.dispose();
    booksScrollController.dispose();
    _bookChannel?.unsubscribe();
    super.dispose();
  }

  // 말풍선을 숨기는 메서드
  void hideBubble() {
    if (_showBubble) {
      setState(() {
        _showBubble = false;
      });
      // 외부에 말풍선 상태 변경 알림
      widget.onBubbleStateChanged?.call(false);
    }
  }

  // 말풍선 상태를 외부에서 확인할 수 있는 getter
  bool get isBubbleVisible => _showBubble;

  // 말풍선 표시 로직 체크
  Future<void> _checkAndShowBubble() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 1. show_archived_books를 한번이라도 변경했는지 체크
      final hasChangedShowArchivedBooks = prefs.getBool('has_changed_show_archived_books') ?? false;
      if (hasChangedShowArchivedBooks) {
        debugPrint('🚫 말풍선 표시 안함: show_archived_books를 변경한 적이 있음');
        return;
      }
      
      // 2. 현재 show_archived_books 상태를 SharedPreferences에 저장
      final currentShowArchivedBooks = (widget.profile?['show_archived_books'] as bool?) ?? false;
      await prefs.setBool('show_archived_books', currentShowArchivedBooks);
      
      if (!currentShowArchivedBooks) {
        debugPrint('🚫 말풍선 표시 안함: show_archived_books가 false');
        return;
      }
      
      // 3. 말풍선 표시 횟수 체크 (최대 2번)
      final bubbleShowCount = prefs.getInt('bubble_show_count') ?? 0;
      if (bubbleShowCount >= 2) {
        debugPrint('🚫 말풍선 표시 안함: 최대 표시 횟수(2번) 초과');
        return;
      }
      
      // 4. 마지막 표시 시간 체크 (하루 간격)
      final lastShowTime = prefs.getInt('bubble_last_show_time') ?? 0;
      final currentTime = DateTime.now().millisecondsSinceEpoch;
      const oneDayInMillis = 24 * 60 * 60 * 1000; // 24시간을 밀리초로
      
      if (bubbleShowCount > 0 && (currentTime - lastShowTime) < oneDayInMillis) {
        debugPrint('🚫 말풍선 표시 안함: 하루가 지나지 않음 (${(currentTime - lastShowTime) / (60 * 60 * 1000)}시간 경과)');
        return;
      }
      
      // 5. 말풍선 표시
      debugPrint('✅ 말풍선 표시: ${bubbleShowCount + 1}번째');
      setState(() {
        _showBubble = true;
      });
      
      // 6. 상태 저장
      await prefs.setInt('bubble_show_count', bubbleShowCount + 1);
      await prefs.setInt('bubble_last_show_time', currentTime);
      
      // 7. 외부에 알림
      widget.onBubbleStateChanged?.call(true);
      
    } catch (e) {
      debugPrint('❌ 말풍선 표시 로직 오류: $e');
    }
  }







  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // 화면 어디든 탭하면 말풍선 숨기기
        if (_showBubble) {
          setState(() {
            _showBubble = false;
          });
          // 외부에 말풍선 상태 변경 알림
          widget.onBubbleStateChanged?.call(false);
          // 외부 콜백 호출
          widget.onBubbleHide?.call();
        }
      },
      child: Stack(
        children: [
          Column(
            children: [
              _buildTabs(),
              Expanded(
                child: PageView(
                  controller: pageController,
                  physics: const ClampingScrollPhysics(), // 슬라이드 전환 유지, 바운스 효과 제거
                  onPageChanged: (index) {
                    setState(() {
                      currentIndex = index;
                    });
                  },
                  children: [
                    _buildRepresentativeTab(),
                    _buildAllBooksTab(),
                  ],
                ),
              ),
            ],
          ),
          // 말풍선을 탭바 바로 아래에 위치 (내 프로필이고 표시 상태일 때만)
          if (!widget.isOtherUser && _showBubble)
            Positioned(
              top: 26, // 탭바 높이만큼 아래
              right: 28,
              child: Stack(
                children: [
                  // 말풍선 배경
                  SvgPicture.asset(
                    'assets/bubble.svg',
                    width: 240,
                    height: 50,
                  ),
                  // 텍스트 오버레이
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.only(top:10),
                      child: Center(
                        child: Text(
                          '프로필 편집에서 숨길 수 있어요',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.black,
                            fontWeight: FontWeight.w500,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Material(
      color: Colors.white,
      child: Row(
        children: [
          _buildTab('대표', 0),
          _buildTab('책장', 1),
        ],
      ),
    );
  }

  Widget _buildTab(String label, int index) {
    final isSelected = currentIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: _showBubble ? null : () {
          pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeInOut,
          );
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
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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





  Widget _buildRepresentativeTab() {
    final books = widget.nonArchivedBooks;
    if (books.isEmpty) {
      return _buildEmptyState(isRepresentativeTab: true);
    }
    
    // 6권 이하면 스크롤 없이 고정 높이, 7권 이상이면 스크롤 가능
    if (books.length <= 6) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
        child: SizedBox(
          height: _calculateRepresentativeTabHeight(books.length),
          child: UserBookGrid(
            books: books,
            onTap: _onBookTap,
          ),
        ),
      );
    } else {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
        child: UserBookGrid(
          books: books,
          onTap: _onBookTap,
        ),
      );
    }
  }

  double _calculateRepresentativeTabHeight(int bookCount) {
    const crossAxisCount = 3;
    const crossAxisSpacing = 23.0;
    const mainAxisSpacing = 30.0;
    const childAspectRatio = 98 / 145;
    const horizontalPadding = 52.0; // 26 * 2
    
    // 화면 너비에서 패딩 제외
    final screenWidth = MediaQuery.of(context).size.width;
    final availableWidth = screenWidth - horizontalPadding;
    
    // 아이템 너비 계산
    final totalSpacing = crossAxisSpacing * (crossAxisCount - 1);
    final itemWidth = (availableWidth - totalSpacing) / crossAxisCount;
    final itemHeight = itemWidth / childAspectRatio;
    
    // 행 수 계산
    final rowCount = (bookCount / crossAxisCount).ceil();
    
    // 총 높이 계산 (아이템 높이 + 행 간격)
    final totalHeight = (itemHeight * rowCount) + (mainAxisSpacing * (rowCount - 1));
    
    return totalHeight;
  }

  Widget _buildAllBooksTab() {
    if (_isInitialLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    // get_archived_books_page에서 가져온 데이터만 사용 (이미 archived_order_index 기준으로 정렬됨)
    final combined = _localArchivedBooks;
    
    if (combined.isEmpty) {
      return _buildEmptyState(isRepresentativeTab: false);
    }
    
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollEndNotification) {
          _onScrollReachBottom();
        }
        
        // 책 부분에서 맨 위로 올린 후 더 올리면 탭바 윗부분도 같이 스크롤
        if (notification is ScrollUpdateNotification) {
          if (notification.metrics.pixels <= 0 && 
              notification.scrollDelta! < 0 && 
              widget.parentScrollController != null) {
            // 책 부분이 맨 위에 있고, 더 위로 스크롤하려고 할 때
            final parentOffset = widget.parentScrollController!.offset;
            if (parentOffset > 0) {
              // 부모가 스크롤 가능한 상태면 부모로 스크롤 전달
              widget.parentScrollController!.jumpTo(
                parentOffset + notification.scrollDelta!,
              );
            }
          }
        }
        
        return false;
      },
      child: SingleChildScrollView(
        controller: booksScrollController,
        physics: const ClampingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              _buildBookshelfLayout(combined),
              if (_isPageLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.black900),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _onScrollReachBottom() {
    if (_hasMore && !_isPageLoading) {
      _loadNextPage();
    }
  }

  Widget _buildBookshelfLayout(List<Map<String, dynamic>> books) {
    const crossAxisCount = 5;
    const crossAxisSpacing = 11.7;
    const itemAspectRatio = 98 / 145;
    const bookPadding = 22.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth - (bookPadding * 2);
        final totalSpacing = crossAxisSpacing * (crossAxisCount - 1);
        final itemWidth = (availableWidth - totalSpacing) / crossAxisCount;
        final itemHeight = itemWidth / itemAspectRatio;



        return Stack(
          children: [
            // 책들
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 10),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: crossAxisSpacing,
                  mainAxisSpacing: 35,
                  childAspectRatio: itemAspectRatio,
                ),
                itemCount: books.length,
                itemBuilder: (context, index) {
                  final book = books[index];
                  final booksData = book['books'] as Map<String, dynamic>?;
                  final imageUrl = booksData?['image'] as String? ?? '';
                  
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(0),
                    child: BookFrame(
                      imageUrl: imageUrl,
                    ),
                  );
                },
              ),
            ),
            // 선반들
            ..._buildShelves(books.length, itemHeight),
          ],
        );
      },
    );
  }

  List<Widget> _buildShelves(int bookCount, double itemHeight) {
    const booksPerRow = 5;
    final shelfCount = (bookCount / booksPerRow).ceil();

    return List.generate(shelfCount, (i) {
      final shelfY = 90 + (itemHeight + 35) * i;
      return Positioned(
        top: shelfY,
        left: 0,
        right: 0,
        child: Container(
          height: 5,
          decoration: BoxDecoration(
            color: const Color(0xFFF6F6F6),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 4,
                offset: const Offset(0, 4),
              ),
            ],
          ),
        ),
      );
    });
  }

  void _onBookTap(Map<String, dynamic> book) async {
    // nonArchivedBooks와 _localArchivedBooks의 구조가 다를 수 있음
    final bookId = book['book_id'] as String? ?? book['id'] as String?;
    final userBookId = book['id'] as String? ?? book['user_book_id'] as String?;
    
    debugPrint('🔍 ProfileBooksTabView - 책 탭됨: bookId=$bookId, userBookId=$userBookId, userId=${widget.userId}');
    
    if (bookId == null || userBookId == null) {
      debugPrint('❌ 책 정보가 누락되었습니다: book=$book, bookId=$bookId, userBookId=$userBookId');
      return;
    }
    
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MyBookPostScreen(
          bookId: bookId,
          userBookId: userBookId,
          userId: widget.userId, // userId도 전달
        ),
      ),
    );
    if (result == true && mounted) {
      // 상위에서 갱신되도록 두고, 여기서는 탭 유지만
      setState(() {});
    }
  }

  Widget _buildEmptyState({required bool isRepresentativeTab}) {
    if (widget.isOtherUser) {
      // 다른 사용자의 프로필일 때
      return Column(
        children: [
          const SizedBox(height: 76),
          Text(
            isRepresentativeTab ? '인생 책이 없어요.' : '책장이 비어 있어요.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppColors.black500),
          ),
          const SizedBox(height: 90),
        ],
      );
    } else {
      // 내 프로필일 때
      return Column(
        children: [
          const SizedBox(height: 76),
          TextButton(
            onPressed: () async {
              final mainNavigationState = context.findAncestorStateOfType<MainNavigationScreenState>();
              if (mainNavigationState != null) {
                mainNavigationState.navigateToAddBookProfileTab();
              }
            },
            child: Text(
             '책 추가 +',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.black900,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          const SizedBox(height: 90),
        ],
      );
    }
  }
}

