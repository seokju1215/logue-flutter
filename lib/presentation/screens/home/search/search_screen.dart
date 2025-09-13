import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_logue/core/themes/app_colors.dart';
import 'package:my_logue/core/themes/text_theme.dart';
import 'package:my_logue/core/widgets/book/book_frame.dart';
import 'package:my_logue/core/widgets/follow/follow_user_tile.dart';
import 'package:my_logue/data/datasources/aladin_book_api.dart';
import 'package:my_logue/data/datasources/user_book_api.dart';
import 'package:my_logue/data/models/book_model.dart';
import 'package:my_logue/data/models/user_profile.dart';
import 'package:my_logue/domain/usecases/follows/follow_user.dart';
import 'package:my_logue/domain/usecases/follows/is_following.dart';
import 'package:my_logue/domain/usecases/follows/unfollow_user.dart';
import 'package:my_logue/domain/usecases/search_users.dart';
import 'package:my_logue/presentation/screens/book/book_detail_screen.dart';
import 'package:my_logue/presentation/screens/main_navigation_screen.dart';
import 'package:my_logue/presentation/screens/profile/other_profile_screen.dart';
import 'package:my_logue/core/constants/app_constants.dart';
import '../../../../data/utils/firebase_analytics_util.dart';
import 'package:my_logue/data/repositories/follow_repository.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:async'; // ✅ 타이머 패키지 추가

import '../../../../core/providers/follow_state_provider.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen>
    with TickerProviderStateMixin {
  late final TabController _tabController;
  late final PageController _pageController;
  final TextEditingController _searchController = TextEditingController();
  late final FollowRepository _followRepo;
  late final FollowUser _followUser;
  late final UnfollowUser _unfollowUser;
  late final IsFollowing _isFollowing;
  List<UserProfile> _userResults = [];
  List<BookModel> _bookResults = [];
  bool _isLoading = false;
  String _query = '';
  bool _isSearching = false; // ✅ 중복 검색 방지 플래그
  int _currentIndex = 0; // 현재 탭 인덱스를 별도로 관리
  bool _openingBook = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _pageController = PageController(initialPage: _currentIndex);

    _followRepo = FollowRepository(
      client: Supabase.instance.client,
      functionBaseUrl: dotenv.env['FUNCTION_BASE_URL']!,
    );
    _followUser = FollowUser(_followRepo);
    _unfollowUser = UnfollowUser(_followRepo);
    _isFollowing = IsFollowing(_followRepo);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (_isSearching) {
      return;
    }

    setState(() {
      _isLoading = true;
      _query = query;
    });
    _isSearching = true;

    try {
      // 1️⃣ 사용자 검색 (내 DB)
      final users = await SearchUsers().call(query);

      // 2️⃣ 내 DB에서 책 검색
      final userBookApi = UserBookApi(Supabase.instance.client);
      final dbResults = await userBookApi.searchBooksFromDB(query);

      // 3️⃣ Aladin API에서 책 검색
      final aladinResults = await AladinBookApi().searchBooks(query);

      // 4️⃣ 책 결과 합치기 및 중복 제거
      final allBooks = <BookModel>[];
      final seenIsbns = <String>{};
      final seenTitles = <String>{};

      // DB 결과 먼저 추가
      for (final dbBook in dbResults) {
        final book = BookModel.fromJson(dbBook);
        if (book.isbn.isNotEmpty && !seenIsbns.contains(book.isbn)) {
          allBooks.add(book);
          seenIsbns.add(book.isbn);
        } else if (book.isbn.isEmpty &&
            !seenTitles.contains(book.title.toLowerCase())) {
          allBooks.add(book);
          seenTitles.add(book.title.toLowerCase());
        }
      }

      // Aladin 결과 추가 (중복 제거)
      for (final aladinBook in aladinResults) {
        final book = BookModel.fromJson(aladinBook);
        if (book.isbn.isNotEmpty && !seenIsbns.contains(book.isbn)) {
          allBooks.add(book);
          seenIsbns.add(book.isbn);
        } else if (book.isbn.isEmpty &&
            !seenTitles.contains(book.title.toLowerCase())) {
          allBooks.add(book);
          seenTitles.add(book.title.toLowerCase());
        }
      }

      if (mounted) {
        setState(() {
          _userResults = users;
          _bookResults = allBooks;
        });
      }
    } catch (e) {
      debugPrint('❌ 검색 실패: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      _isSearching = false;
    }
  }

  Future<void> _updateFollowStatus(String userId) async {
    try {
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      if (currentUserId == null) return;

      // 해당 사용자의 팔로우 상태를 다시 확인
      final followResult = await Supabase.instance.client
          .from('follows')
          .select('following_id')
          .eq('follower_id', currentUserId)
          .eq('following_id', userId)
          .maybeSingle();

      final isFollowing = followResult != null;

      // _userResults에서 해당 사용자의 팔로우 상태 업데이트
      setState(() {
        _userResults = _userResults.map((user) {
          if (user.id == userId) {
            return user.copyWith(isFollowing: isFollowing);
          }
          return user;
        }).toList();
      });
    } catch (e) {
      debugPrint('팔로우 상태 업데이트 실패: $e');
    }
  }

  Future<void> _onTapBook(BookModel book) async {
    if (_openingBook) return;        // ✅ 연타 가드
    _openingBook = true;

    try {
      MainNavigationScreen.lastSelectedIndex = 0;
      // ✅ 즉시 BookDetailScreen으로 이동 (book 정보 전달)
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => BookDetailScreen(
            bookModel: book, // ✅ BookModel 전달
          ),
        ),
      );
    } finally {
      _openingBook = false;          // ✅ 반드시 잠금 해제
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentTab = _tabController.index;
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
          child: IconButton(
            icon: Transform.scale(
              scale: 1.2, // 크기를 1.2배로 확대
              child: SvgPicture.asset('assets/back_arrow.svg'),
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        titleSpacing: 0,
        title: Padding(
            padding: const EdgeInsets.fromLTRB(0, 12, 22, 0),
            child: SizedBox(
              height: 38,
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: AppColors.black900, fontSize: 14),
                decoration: InputDecoration(
                  hintText: '사용자 이름 또는 책 이름을 검색해주세요.',
                  hintStyle: const TextStyle(
                      color: AppColors.black500,
                      fontSize: 14,
                      fontWeight: FontWeight.w400),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 9, horizontal: 9),
                  filled: true,
                  fillColor: const Color(0xFFF3F3F3),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(5),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(5),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: _search,
              ),
            )),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(33),
          child: Stack(
            children: [
              const Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child:
                    Divider(height: 1, thickness: 1, color: AppColors.black500),
              ),
              Row(
                children: List.generate(3, (index) {
                  final labels = ['추천', '계정', '책'];
                  final isSelected = _currentIndex == index;

                  return GestureDetector(
                    onTap: () {
                      _pageController.animateToPage(index,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut);
                      setState(() {
                        _currentIndex = index;
                      });
                    },
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: index == 0 ? 11 : 0,
                        right: 0,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(height: 12),
                          Text(
                            labels[index],
                            style: TextStyle(
                              fontWeight: FontWeight.w400,
                              color: isSelected
                                  ? AppColors.black900
                                  : AppColors.black500,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            height: 2,
                            width: 56,
                            color: isSelected
                                ? AppColors.black900
                                : Colors.transparent,
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        children: [
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _query.isEmpty
                  ? const SizedBox.shrink()
                  : _userResults.isEmpty && _bookResults.isEmpty
                      ? const SizedBox.expand(
                          child: Center(
                            child: Text(
                              "검색 결과가 없어요.",
                              style: TextStyle(
                                  fontSize: 14, color: AppColors.black500),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(
                              vertical: 19, horizontal: 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_userResults.isNotEmpty) ...[
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 22),
                                  child: Text(
                                    "계정",
                                    style: TextStyle(
                                        fontSize: 16,
                                        color: AppColors.black900),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                ..._userResults.take(6).map(
                                      (e) => FollowUserTile(
                                        userId: e.id,
                                        username: e.username,
                                        name: e.name,
                                        avatarUrl: e.avatarUrl ?? 'basic',
                                        isMyProfile: false,
                                        currentUserId: Supabase.instance.client
                                            .auth.currentUser!.id,
                                        onTapFollow: () async {
                                          try {
                                            final followNotifier = ref.read(
                                                followStateProvider(e.id)
                                                    .notifier);

                                            if (e.isFollowing) {
                                              // 언팔로우
                                              followNotifier
                                                  .optimisticUnfollow();
                                              setState(() {
                                                _userResults =
                                                    _userResults.map((u) {
                                                  return u.id == e.id
                                                      ? u.copyWith(
                                                          isFollowing: false)
                                                      : u;
                                                }).toList();
                                              });

                                              await followNotifier.unfollow();
                                              
                                              // Firebase Analytics 이벤트 전송
                                              await FirebaseAnalyticsUtil.logUnfollowUser(
                                                targetUserId: e.id,
                                                targetUsername: e.username,
                                                sourceScreen: 'search_screen',
                                              );
                                            } else {
                                              // 팔로우
                                              followNotifier.optimisticFollow();
                                              setState(() {
                                                _userResults =
                                                    _userResults.map((u) {
                                                  return u.id == e.id
                                                      ? u.copyWith(
                                                          isFollowing: true)
                                                      : u;
                                                }).toList();
                                              });

                                              await followNotifier.follow();
                                              
                                              // Firebase Analytics 이벤트 전송 (별도 try-catch)
                                              try {
                                                debugPrint('🚀🚀🚀 검색에서 팔로우 이벤트 전송 시도: ${e.id}');
                                                await FirebaseAnalyticsUtil.logFollowUser(
                                                  targetUserId: e.id,
                                                  targetUsername: e.username,
                                                  sourceScreen: 'search_screen',
                                                );
                                                debugPrint('🎯🎯🎯 검색에서 팔로우 이벤트 전송 완료: ${e.id}');
                                              } catch (analyticsError) {
                                                debugPrint('❌ 검색 팔로우 이벤트 전송 실패: $analyticsError');
                                              }
                                            }
                                          } catch (err) {
                                            debugPrint('❌ 팔로우 실패: $err');
                                            // 실패 시 롤백
                                            final followNotifier = ref.read(
                                                followStateProvider(e.id)
                                                    .notifier);
                                            if (e.isFollowing) {
                                              followNotifier.optimisticFollow();
                                            } else {
                                              followNotifier
                                                  .optimisticUnfollow();
                                            }
                                            setState(() {
                                              _userResults =
                                                  _userResults.map((u) {
                                                return u.id == e.id
                                                    ? u.copyWith(
                                                        isFollowing:
                                                            e.isFollowing)
                                                    : u;
                                              }).toList();
                                            });
                                          }
                                        },
                                        onTapProfile: () async {
                                          final result = await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  OtherProfileScreen(
                                                      userId: e.id),
                                            ),
                                          );

                                          // 프로필 화면에서 돌아왔을 때 팔로우 상태가 변경되었을 수 있으므로
                                          // 해당 사용자의 팔로우 상태를 다시 확인
                                          if (result == true) {
                                            await _updateFollowStatus(e.id);
                                          }
                                        },
                                      ),
                                    ),
                                const SizedBox(height: 26),
                              ],
                              if (_bookResults.isNotEmpty) ...[
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 22),
                                  child: Text(
                                    "책",
                                    style: TextStyle(
                                        fontSize: 16,
                                        color: AppColors.black900),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 26),
                                  child: GridView.builder(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 3,
                                      crossAxisSpacing: 23,
                                      mainAxisSpacing: 30,
                                      childAspectRatio: 98 / 145,
                                    ),
                                    itemCount: _bookResults.length,
                                    itemBuilder: (context, index) {
                                      final book = _bookResults[index];

                                      return GestureDetector(
                                        onTap: () => _onTapBook(book),
                                        child: BookFrame(imageUrl: book.image),
                                      );
                                    },
                                  ),
                                )
                              ],
                            ],
                          ),
                        ),
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _query.isEmpty
                  ? const SizedBox.shrink() // 🔍 검색 전에는 아무것도 안 보이게
                  : _userResults.isEmpty
                      ? const SizedBox.expand(
                          child: Center(
                            child: Text(
                              "검색 결과가 없어요.",
                              style: TextStyle(
                                  fontSize: 14, color: AppColors.black500),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.fromLTRB(22, 19, 22, 6),
                              child: Text("계정",
                                  style: TextStyle(
                                      fontSize: 16, color: AppColors.black900)),
                            ),
                            Expanded(
                              child: ListView(
                                children: _userResults
                                    .map(
                                      (e) => FollowUserTile(
                                        userId: e.id,
                                        username: e.username,
                                        name: e.name,
                                        avatarUrl: e.avatarUrl ?? 'basic',
                                        isMyProfile: false,
                                        currentUserId: Supabase.instance.client
                                            .auth.currentUser!.id,
                                        onTapFollow: () async {
                                          try {
                                            final followNotifier = ref.read(
                                                followStateProvider(e.id)
                                                    .notifier);

                                            if (e.isFollowing) {
                                              // 언팔로우
                                              followNotifier
                                                  .optimisticUnfollow();
                                              setState(() {
                                                _userResults =
                                                    _userResults.map((u) {
                                                  return u.id == e.id
                                                      ? u.copyWith(
                                                          isFollowing: false)
                                                      : u;
                                                }).toList();
                                              });

                                              await followNotifier.unfollow();
                                              
                                              // Firebase Analytics 이벤트 전송
                                              await FirebaseAnalyticsUtil.logUnfollowUser(
                                                targetUserId: e.id,
                                                targetUsername: e.username,
                                                sourceScreen: 'search_screen',
                                              );
                                            } else {
                                              // 팔로우
                                              followNotifier.optimisticFollow();
                                              setState(() {
                                                _userResults =
                                                    _userResults.map((u) {
                                                  return u.id == e.id
                                                      ? u.copyWith(
                                                          isFollowing: true)
                                                      : u;
                                                }).toList();
                                              });

                                              await followNotifier.follow();
                                              
                                              // Firebase Analytics 이벤트 전송 (별도 try-catch)
                                              try {
                                                debugPrint('🚀🚀🚀 검색에서 팔로우 이벤트 전송 시도: ${e.id}');
                                                await FirebaseAnalyticsUtil.logFollowUser(
                                                  targetUserId: e.id,
                                                  targetUsername: e.username,
                                                  sourceScreen: 'search_screen',
                                                );
                                                debugPrint('🎯🎯🎯 검색에서 팔로우 이벤트 전송 완료: ${e.id}');
                                              } catch (analyticsError) {
                                                debugPrint('❌ 검색 팔로우 이벤트 전송 실패: $analyticsError');
                                              }
                                            }
                                          } catch (err) {
                                            debugPrint('❌ 팔로우 실패: $err');
                                            // 실패 시 롤백
                                            final followNotifier = ref.read(
                                                followStateProvider(e.id)
                                                    .notifier);
                                            if (e.isFollowing) {
                                              followNotifier.optimisticFollow();
                                            } else {
                                              followNotifier
                                                  .optimisticUnfollow();
                                            }
                                            setState(() {
                                              _userResults =
                                                  _userResults.map((u) {
                                                return u.id == e.id
                                                    ? u.copyWith(
                                                        isFollowing:
                                                            e.isFollowing)
                                                    : u;
                                              }).toList();
                                            });
                                          }
                                        },
                                        onTapProfile: () async {
                                          final result = await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  OtherProfileScreen(
                                                      userId: e.id),
                                            ),
                                          );

                                          // 프로필 화면에서 돌아왔을 때 팔로우 상태가 변경되었을 수 있으므로
                                          // 해당 사용자의 팔로우 상태를 다시 확인
                                          if (result == true) {
                                            await _updateFollowStatus(e.id);
                                          }
                                        },
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                          ],
                        ),
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _query.isEmpty
                  ? const SizedBox.shrink() // 🔍 검색 전에는 아무것도 안 보이게
                  : _bookResults.isEmpty
                      ? const SizedBox.expand(
                          child: Center(
                            child: Text(
                              "검색 결과가 없어요.",
                              style: TextStyle(
                                  fontSize: 14, color: AppColors.black500),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 19, vertical: 22),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '책',
                                style: TextStyle(
                                    fontSize: 16, color: AppColors.black900),
                              ),
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: GridView.builder(
                                  itemCount: _bookResults.length,
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    crossAxisSpacing: 23,
                                    mainAxisSpacing: 30,
                                    childAspectRatio: 98 / 145,
                                  ),
                                  itemBuilder: (context, index) {
                                    final book = _bookResults[index];
                                    return GestureDetector(
                                      onTap: () => _onTapBook(book),
                                      child: BookFrame(imageUrl: book.image),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        )
        ],
      ),
    );
  }
}
