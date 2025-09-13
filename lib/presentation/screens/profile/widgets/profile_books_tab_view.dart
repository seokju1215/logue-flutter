import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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
  final ValueChanged<int>? onTabChanged;

  const ProfileBooksTabView({
    super.key,
    required this.nonArchivedBooks,
    required this.userId,
    this.parentScrollController,
    this.isOtherUser = false,
    this.onBubbleHide,
    this.onBubbleStateChanged,
    this.profile,
    this.onTabChanged,
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
  bool _isTabBarPinned = false; // 탭바 고정 상태
  
  // 앱 시작 시점의 세션 키 (한 번만 생성)
  static String? _sessionKey;
  
  // ===== 페이지네이션 상태 =====
  static const int _pageSize = 100;
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
    
    // 세션 키가 없으면 생성 (앱 시작 시점에 한 번만)
    if (_sessionKey == null) {
      _sessionKey = 'bubble_shown_session_${DateTime.now().millisecondsSinceEpoch}';
    } else {
    }
    
    pageController = PageController(initialPage: 0);
    booksScrollController = ScrollController();
    
    _fetchTotalCount();
    _loadNextPage();
    _subscribeToBookUpdates();
    
    // 말풍선 표시 로직 체크
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !widget.isOtherUser) {
        _checkAndShowBubble().catchError((e) {
          // 오류 발생 시 무시 (위젯이 dispose된 경우 등)
        });
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
    if (!_isInitialLoading && mounted) {
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
          
          // 로컬 데이터 초기화 후 다시 로드
          if (mounted) {
            setState(() {
              _localArchivedBooks.clear();
              _offset = 0;
              _hasMore = true;
            });
          }
          
          // 데이터 다시 로드 (mounted 체크 후)
          if (mounted) {
            await _fetchTotalCount();
          }
          if (mounted) {
            await _loadNextPage();
          }
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
    if (_showBubble && mounted) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _showBubble = false;
          });
          // 외부에 말풍선 상태 변경 알림
          widget.onBubbleStateChanged?.call(false);
        }
      });
    }
  }

  // 말풍선 상태를 외부에서 확인할 수 있는 getter
  bool get isBubbleVisible => _showBubble;

  // 탭바 고정 상태 업데이트 메서드
  void updateTabBarPinnedState(bool isPinned) {
    if (_isTabBarPinned != isPinned && mounted) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _isTabBarPinned = isPinned;
          });
        }
      });
    }
  }

  // 스크롤 업데이트 이벤트 핸들러
  void _onScrollUpdate(ScrollUpdateNotification notification) {
    if (!mounted) return;

    final pos = notification.metrics;
    const threshold = 300.0; // 바닥 300px 전

    // 말풍선 숨기기
    if (_showBubble) {
      setState(() => _showBubble = false);
      widget.onBubbleStateChanged?.call(false);
      widget.onBubbleHide?.call();
    }

    // 책장 탭(currentIndex == 1)에서만 무한 스크롤 적용
    if (currentIndex == 1 && _hasMore && !_isPageLoading && 
        pos.maxScrollExtent - pos.pixels <= threshold) {
      _loadNextPage();
    }
  }

  // 말풍선 표시 로직 체크 (접속마다 한번씩 평생 2회)
  Future<void> _checkAndShowBubble() async {
    try {
      // 내 프로필이 아니면 표시하지 않음
      if (widget.isOtherUser) {
        return;
      }
      
      // show_archived_books가 false면 표시하지 않음
      final showArchivedBooks = (widget.profile?['show_archived_books'] as bool?) ?? false;
      if (!showArchivedBooks) {
        return;
      }
      
      final prefs = await SharedPreferences.getInstance();
      
      // 평생 표시 횟수 확인 (최대 2회)
      final bubbleShowCount = prefs.getInt('bubble_show_count') ?? 0;
      
      if (bubbleShowCount >= 2) {
        return;
      }
      
      // 현재 세션에서 이미 표시했는지 확인
      final currentSessionKey = _sessionKey!;
      final hasShownInCurrentSession = prefs.getBool(currentSessionKey) ?? false;
      
      if (hasShownInCurrentSession) {
        return;
      }
      
      // 모든 조건을 만족하면 말풍선 표시
      
      // 세션 키 저장 (현재 세션에서 표시했음을 기록)
      await prefs.setBool(currentSessionKey, true);
      
      // 평생 표시 횟수 증가
      await prefs.setInt('bubble_show_count', bubbleShowCount + 1);
      
      if (mounted) {
        setState(() {
          _showBubble = true;
        });
      }
      
      // 외부에 알림
      widget.onBubbleStateChanged?.call(true);
    } catch (e) {
      // 말풍선 체크 실패 시 무시
    }
  }


  // 디버깅용: 현재 말풍선 상태 확인







  @override
  Widget build(BuildContext context) {
    
    return GestureDetector(
      onTap: () {
        // 화면 어디든 탭하면 말풍선 숨기기
        if (_showBubble && mounted) {
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
          SizedBox(
            height: MediaQuery.of(context).size.height,
            child: PageView(
              controller: pageController,
              physics: widget.isOtherUser ? const ClampingScrollPhysics() : (_showBubble ? const NeverScrollableScrollPhysics() : const ClampingScrollPhysics()),
              onPageChanged: (index) {
                // 스와이프로 페이지가 변경되면 말풍선 숨기기 (내 프로필일 때만)
                if (!widget.isOtherUser && _showBubble && mounted) {
                  setState(() {
                    _showBubble = false;
                  });
                  widget.onBubbleStateChanged?.call(false);
                  widget.onBubbleHide?.call();
                }
                
                if (mounted) {
                  setState(() {
                    currentIndex = index;
                  });
                }
                widget.onTabChanged?.call(index);
              },
              children: [
                NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification is ScrollUpdateNotification) {
                      _onScrollUpdate(notification);
                    }
                    return false;
                  },
                  child: _buildRepresentativeTabContent(),
                ),
                NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification is ScrollUpdateNotification) {
                      _onScrollUpdate(notification);
                    }
                    return false;
                  },
                  child: _buildAllBooksTabContent(),
                ),
              ],
            ),
          ),
          // 버블이 떠있을 때만 투명 오버레이 (스크롤과 충돌 방지)
          if (!widget.isOtherUser && _showBubble)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (mounted) {
                    setState(() => _showBubble = false);
                    widget.onBubbleStateChanged?.call(false);
                    widget.onBubbleHide?.call();
                  }
                },
              ),
            ),
          // 말풍선을 탭바 바로 아래에 위치 (내 프로필이고 표시 상태일 때만)
          if (!widget.isOtherUser && _showBubble)
            Positioned(
              top: _isTabBarPinned ? 30 : 0,
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
                      padding: const EdgeInsets.only(top: 10),
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






  Widget _buildRepresentativeTab() {
    final books = widget.nonArchivedBooks;
    if (books.isEmpty) {
      return _buildEmptyState(isRepresentativeTab: true);
    }
    
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 23,
          mainAxisSpacing: 30,
          childAspectRatio: 98 / 145,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final book = books[index];
            final imageUrl = book['books']?['image'] ?? '';

            return GestureDetector(
              onTap: () {
                if (_onBookTap != null) {
                  _onBookTap(book);
                }
              },
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.black300, width: 0.5),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(0),
                  child: imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: AppColors.black100,
                              child: const Icon(Icons.book, color: AppColors.black300),
                            );
                          },
                        )
                      : Container(
                          color: AppColors.black100,
                          child: const Icon(Icons.book, color: AppColors.black300),
                        ),
                ),
              ),
            );
          },
          childCount: books.length,
        ),
      ),
    );
  }

  Widget _buildRepresentativeTabContent() {
    final books = widget.nonArchivedBooks;
    if (books.isEmpty) {
      return _buildEmptyStateContent(isRepresentativeTab: true);
    }
    
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 23,
            mainAxisSpacing: 30,
            childAspectRatio: 98 / 145,
          ),
          itemCount: books.length,
          itemBuilder: (context, index) {
            final book = books[index];
            final imageUrl = book['books']?['image'] ?? '';

            return GestureDetector(
              onTap: () {
                if (_onBookTap != null) {
                  _onBookTap(book);
                }
              },
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.black300, width: 0.5),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(0),
                  child: imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: AppColors.black100,
                              child: const Icon(Icons.book, color: AppColors.black300),
                            );
                          },
                        )
                      : Container(
                          color: AppColors.black100,
                          child: const Icon(Icons.book, color: AppColors.black300),
                        ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }



  Widget _buildAllBooksTab() {
    if (_isInitialLoading) {
      return const SliverToBoxAdapter(
        child: Center(child: CircularProgressIndicator()),
      );
    }
    
    // get_archived_books_page에서 가져온 데이터만 사용 (이미 archived_order_index 기준으로 정렬됨)
    final combined = _localArchivedBooks;
    
    if (combined.isEmpty) {
      return _buildEmptyState(isRepresentativeTab: false);
    }
    
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 220),
      sliver: _buildBookshelfLayoutSliver(combined),
    );
  }

  Widget _buildAllBooksTabContent() {
    if (_isInitialLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    // get_archived_books_page에서 가져온 데이터만 사용 (이미 archived_order_index 기준으로 정렬됨)
    final combined = _localArchivedBooks;
    
    if (combined.isEmpty) {
      return _buildEmptyStateContent(isRepresentativeTab: false);
    }
    
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 16, 0, 20),
        child: _buildBookshelfLayout(combined),
      ),
    );
  }

  void _onScrollReachBottom() {
    if (!mounted || _isPageLoading || !_hasMore) return;

    final pos = booksScrollController.hasClients ? booksScrollController.position : null;
    if (pos != null && (pos.maxScrollExtent - pos.pixels) > 300) return; // 안전 체크

    _loadNextPage();
  }

  Widget _buildBookshelfLayoutSliver(List<Map<String, dynamic>> books) {
    return SliverToBoxAdapter(
      child: _buildBookshelfLayout(books),
    );
  }

  Widget _buildBookshelfLayout(List<Map<String, dynamic>> books) {
    const crossAxisCount = 5;
    const crossAxisSpacing = 11.7;
    const itemAspectRatio = 98 / 138; // archive_tab과 동일한 비율
    const bookPadding = 22.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth - (bookPadding * 2);
        final totalSpacing = crossAxisSpacing * (crossAxisCount - 1);
        final itemWidth = (availableWidth - totalSpacing) / crossAxisCount;
        final itemHeight = itemWidth / itemAspectRatio;

        // 책과 선반 사이의 간격을 유동적으로 계산
        // 책 높이의 40% 정도를 선반과의 간격으로 설정 (더 넓게)
        final bookShelfSpacing = (itemHeight * 0.4).clamp(25.0, 60.0);

        // 첫 번째 선반의 위치도 책 크기에 맞게 유동적으로 계산
        // 책 높이의 60% 정도를 첫 번째 선반 위치로 설정
        final firstShelfY = itemHeight.clamp(50.0, 120.0);



        return Stack(
          children: [
            // 책들 - archive_bottom_sheet와 동일한 방식
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 10),
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemCount: books.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: crossAxisSpacing,
                  mainAxisSpacing: bookShelfSpacing,
                  childAspectRatio: itemAspectRatio,
                ),
                itemBuilder: (context, index) {
                  final book = books[index];
                  final booksData = book['books'] as Map<String, dynamic>?;
                  final imageUrl = booksData?['image'] as String? ?? '';
                  
                  return GestureDetector(
                    onTap: () => _onBookTap(book),
                    child: SizedBox(
                      width: itemWidth,
                      height: itemHeight,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(0),
                        child: BookFrame(
                          imageUrl: imageUrl,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            // 선반들
            ..._buildShelves(books.length, itemHeight, bookShelfSpacing, firstShelfY),
          ],
        );
      },
    );
  }

  List<Widget> _buildShelves(int bookCount, double itemHeight, double bookShelfSpacing, double firstShelfY) {
    const booksPerRow = 5;
    final shelfCount = (bookCount / booksPerRow).ceil();

    return List.generate(shelfCount, (i) {
      final shelfY = firstShelfY + (itemHeight + bookShelfSpacing) * i;
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
    // 책장탭(currentIndex == 1)에서는 책 탭 비활성화
    if (currentIndex == 1) {
      return; // 책장탭에서는 클릭 무시
    }
    
    // 말풍선이 표시된 상태에서는 책 탭을 막고 말풍선만 숨기기
    if (_showBubble && mounted) {
      setState(() {
        _showBubble = false;
      });
      widget.onBubbleStateChanged?.call(false);
      widget.onBubbleHide?.call();
      return; // 책 상세 화면으로 이동하지 않음
    }
    
    // nonArchivedBooks와 _localArchivedBooks의 구조가 다를 수 있음
    final bookId = book['book_id'] as String? ?? book['id'] as String?;
    final userBookId = book['id'] as String? ?? book['user_book_id'] as String?;
    
    
    if (bookId == null || userBookId == null) {
      // 책 정보가 누락됨
      return;
    }
    
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MyBookPostScreen(
          bookId: bookId,
          userBookId: userBookId,
          userId: widget.userId, // userId도 전달
          booksData: widget.nonArchivedBooks, // ✅ 기존 책 데이터 전달
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
      return SliverToBoxAdapter(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                isRepresentativeTab ? '인생 책이 없어요.' : '책장이 비어 있어요.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppColors.black500),
              ),
            ],
          ),
        ),
      );
    } else {
      // 내 프로필일 때
      return SliverToBoxAdapter(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
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
            ],
          ),
        ),
      );
    }
  }

  Widget _buildEmptyStateContent({required bool isRepresentativeTab}) {
    if (widget.isOtherUser) {
      // 다른 사용자의 프로필일 때
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              isRepresentativeTab ? '인생 책이 없어요.' : '책장이 비어 있어요.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.black500),
            ),
          ],
        ),
      );
    } else {
      // 내 프로필일 때
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
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
          ],
        ),
      );
    }
  }
}

