import 'package:flutter/material.dart';
import 'package:my_logue/core/themes/app_colors.dart';
import 'package:my_logue/core/widgets/book/book_frame.dart';
import 'package:my_logue/core/widgets/book/user_book_grid.dart';
import 'package:my_logue/presentation/screens/main_navigation_screen.dart';
import 'package:my_logue/presentation/screens/post/my_post_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileBooksTabView extends StatefulWidget {
  final List<Map<String, dynamic>> nonArchivedBooks;
  final String userId;
  final ScrollController? parentScrollController;

  const ProfileBooksTabView({
    super.key,
    required this.nonArchivedBooks,
    required this.userId,
    this.parentScrollController,
  });

  @override
  State<ProfileBooksTabView> createState() => _ProfileBooksTabViewState();
}

class _ProfileBooksTabViewState extends State<ProfileBooksTabView> {
  late PageController _pageController;
  late ScrollController _booksScrollController;
  int currentIndex = 0;
  final _client = Supabase.instance.client;
  
  // 스크롤 동작 제어를 위한 상태
  bool _isBooksOnlyScrolling = false;
  double _thresholdHeight = 0;
  
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
    _pageController = PageController(initialPage: 0);
    _booksScrollController = ScrollController();
    _booksScrollController.addListener(_onBooksScroll);
    _fetchTotalCount();
    _loadNextPage();
    _subscribeToBookUpdates();
  }

  Future<void> _fetchTotalCount() async {
    try {
      final res = await _client.rpc('get_archived_books_count', params: {
        'p_user_id': widget.userId
      });

      int count = 0;
      if (res != null) {
        if (res is int) {
          count = res;
        } else if (res is num) {
          count = res.toInt();
        } else if (res is Map && res.values.isNotEmpty) {
          final v = res.values.first;
          count = (v is num) ? v.toInt() : 0;
        }
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

    if (!_isInitialLoading) {
      setState(() {
        _isPageLoading = true;
      });
    }

    try {
      final rpc = await _client.rpc(
        'get_archived_books_page',
        params: {
          'p_limit': _pageSize,
          'p_offset': _offset,
        },
      );

      if (rpc == null) {
        debugPrint('❌ RPC 결과가 null입니다');
        return;
      }

      final rows = (rpc as List<dynamic>).cast<Map<String, dynamic>>();

      if (rows.isNotEmpty) {
        _totalCount = (rows.first['total_count'] as int?) ?? 0;
      }

      final bookIds = rows
          .map((e) => e['book_id'])
          .where((id) => id != null)
          .toSet()
          .toList();

      Map<String, dynamic> imagesByBookId = {};
      if (bookIds.isNotEmpty) {
        final booksRes = await _client
            .from('books')
            .select('id, image')
            .inFilter('id', bookIds);

        if (booksRes != null) {
          for (final b in (booksRes as List)) {
            final bookId = b['id'] as String?;
            if (bookId != null) {
              imagesByBookId[bookId] = {
                'id': bookId,
                'image': b['image'],
              };
            }
          }
        }
      }

      final pageItems = rows.map((e) {
        final bookId = e['book_id'];
        final item = {
          ...e,
          'id': e['id'] ?? e['book_id'], // id 필드 추가
          'books': imagesByBookId[bookId] ?? {'id': bookId, 'image': null},
        };
        
        if (item['archived_order_index'] != null) {
          final rawValue = item['archived_order_index'];
          double finalValue;
          if (rawValue is int) {
            finalValue = rawValue.toDouble();
          } else if (rawValue is double) {
            finalValue = rawValue;
          } else if (rawValue is num) {
            finalValue = rawValue.toDouble();
          } else {
            try {
              finalValue = double.parse(rawValue.toString());
            } catch (e) {
              finalValue = 0.0;
            }
          }
          item['archived_order_index'] = finalValue;
        }
        
        return item;
      }).toList();

      if (mounted) {
        setState(() {
          for (final newBook in pageItems) {
            final existingIndex = _localArchivedBooks.indexWhere(
              (book) => book['id'] == newBook['id'],
            );
            
            if (existingIndex == -1) {
              _localArchivedBooks.add(newBook);
            } else {
              final existingBook = _localArchivedBooks[existingIndex];
              if (existingBook['archived_order_index'] != null && 
                  existingBook['archived_order_index'] is double) {
                newBook['archived_order_index'] = existingBook['archived_order_index'];
              }
              _localArchivedBooks[existingIndex] = newBook;
            }
          }
          
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
    final user = _client.auth.currentUser;
    if (user == null) return;

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
          value: user.id,
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
    _pageController.dispose();
    _booksScrollController.dispose();
    _bookChannel?.unsubscribe();
    super.dispose();
  }

  void _onBooksScroll() {
    if (!_booksScrollController.hasClients) return;
    
    // 6권 이하면 스크롤 모드 전환하지 않음
    if (widget.nonArchivedBooks.length <= 6) return;
    
    final scrollOffset = _booksScrollController.offset;
    
    // 임계 높이에 도달하면 책 부분만 스크롤
    if (scrollOffset >= _thresholdHeight && !_isBooksOnlyScrolling) {
      setState(() {
        _isBooksOnlyScrolling = true;
      });
    } else if (scrollOffset < _thresholdHeight && _isBooksOnlyScrolling) {
      setState(() {
        _isBooksOnlyScrolling = false;
      });
    }
  }

  void _setThresholdHeight(double height) {
    // 6권 이하면 임계 높이 설정하지 않음
    if (widget.nonArchivedBooks.length <= 6) return;
    
    if (_thresholdHeight == 0) {
      setState(() {
        _thresholdHeight = height;
      });
    }
  }



  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildTabs(),
        Expanded(
          child: PageView(
            controller: _pageController,
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
        onTap: () {
          _pageController.animateToPage(
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
      return _buildEmptyState();
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
    
    // archived_order_index 기준으로 정렬
    final combined = <Map<String, dynamic>>[...widget.nonArchivedBooks, ..._localArchivedBooks];
    combined.sort((a, b) {
      final aOrder = (a['archived_order_index'] as num?)?.toDouble() ?? 0.0;
      final bOrder = (b['archived_order_index'] as num?)?.toDouble() ?? 0.0;
      return aOrder.compareTo(bOrder);
    });
    
    if (combined.isEmpty) {
      return _buildEmptyState();
    }
    
    // 6권 이하면 항상 책들만 스크롤, 6권 초과면 조건부 스크롤
    final shouldUseBooksOnlyScroll = widget.nonArchivedBooks.length <= 6 || _isBooksOnlyScrolling;
    
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollEndNotification) {
          _onScrollReachBottom();
        }
        return false;
      },
      child: shouldUseBooksOnlyScroll
          ? SingleChildScrollView(
              controller: _booksScrollController,
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
            )
          : SingleChildScrollView(
              controller: widget.parentScrollController,
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

        // 임계 높이 설정 (첫 번째 줄의 높이)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _setThresholdHeight(itemHeight + 35);
        });

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
    
    if (bookId == null || userBookId == null) {
      debugPrint('❌ 책 정보가 누락되었습니다: book=$book, bookId=$bookId, userBookId=$userBookId');
      return;
    }
    
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MyBookPostScreen(
          bookId: bookId,
          userBookId: userBookId,
        ),
      ),
    );
    if (result == true && mounted) {
      // 상위에서 갱신되도록 두고, 여기서는 탭 유지만
      setState(() {});
    }
  }

  Widget _buildEmptyState() {
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
          child: const Text(
            '책 추가 +',
            style: TextStyle(
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

