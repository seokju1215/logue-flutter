import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_logue/core/themes/app_colors.dart';
import 'package:my_logue/core/widgets/common/custom_app_bar.dart';
import 'package:my_logue/core/widgets/follow/follow_user_tile.dart';
import 'package:my_logue/core/widgets/book/book_frame.dart';
import 'package:my_logue/presentation/screens/profile/other_profile_screen.dart';
import 'package:my_logue/presentation/screens/book/book_detail_screen.dart';
import 'package:my_logue/presentation/screens/main_navigation_screen.dart';
import 'package:my_logue/data/models/book_model.dart';
import 'package:my_logue/data/models/user_profile.dart';
import 'package:my_logue/data/datasources/aladin_book_api.dart';
import 'package:my_logue/domain/usecases/search_users.dart';
import 'package:my_logue/domain/usecases/follows/follow_user.dart';
import 'package:my_logue/domain/usecases/follows/unfollow_user.dart';
import 'package:my_logue/domain/usecases/follows/is_following.dart';
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

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
      final users = await SearchUsers().call(query);
      final booksRaw = await AladinBookApi().searchBooks(query);
      final books = booksRaw
          .map((data) => BookModel.fromJson(data))
          .toList();

      if (mounted) {
        setState(() {
          _userResults = users;
          _bookResults = books;
        });
      }
    } catch (e) {
      // 에러 처리
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
    final client = Supabase.instance.client;

    try {
      final res = await client.functions.invoke(
        'get-book-detail',
        body: {
          'isbn': book.isbn,
          'title': book.title, // ✅ title도 함께 넘김
        },
      );
      print('🔍 isbn: ${book.isbn}');
      print('🔍 title: ${book.title}');

      final data = res.data;

      if (data == null || data['book'] == null || data['book']['id'] == null) {
        print('📦 함수 결과: ${res.data}');
        throw Exception('유효한 책 정보를 가져오지 못했어요.');
      }

      final bookId = data['book']['id'];

      MainNavigationScreen.lastSelectedIndex = 0;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => BookDetailScreen(bookId: bookId),
        ),
      );
    } catch (e) {
      debugPrint('❌ 책 정보 가져오기 실패: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('책 정보를 불러오지 못했어요.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentTab = _tabController.index;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: SvgPicture.asset('assets/back_arrow.svg'),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 22),
          child: SizedBox(
            height: 38,
            child : TextField(
            controller: _searchController,
            style: const TextStyle(color: AppColors.black900, fontSize: 14),
            decoration: InputDecoration(
              hintText: '사용자 이름 또는 책 이름을 검색해주세요.',
              hintStyle:
                  const TextStyle(color: AppColors.black500, fontSize: 14, fontWeight: FontWeight.w400),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
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
          ),)
        ),
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
                  final isSelected = _tabController.index == index;

                  return GestureDetector(
                    onTap: () {
                      _tabController.animateTo(index);
                      setState(() {});
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
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
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
      body: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _query.isEmpty
                  ? const SizedBox.shrink()
                  : _userResults.isEmpty && _bookResults.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 60),
                            child: Text(
                              '검색 결과가 없어요.',
                              style: TextStyle(
                                  fontSize: 14, color: AppColors.black500),
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
                                  padding: const EdgeInsets.symmetric(horizontal: 22),
                                  child: Text(
                                    "계정",
                                    style: TextStyle(
                                        fontSize: 16, color: AppColors.black900),
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
                                        currentUserId: Supabase.instance.client.auth.currentUser!.id,
                                        onTapFollow: () async {
                                          try {
                                            final followNotifier = ref.read(followStateProvider(e.id).notifier);
                                            
                                            if (e.isFollowing) {
                                              // 언팔로우
                                              followNotifier.optimisticUnfollow();
                                              setState(() {
                                                _userResults = _userResults.map((u) {
                                                  return u.id == e.id ? u.copyWith(isFollowing: false) : u;
                                                }).toList();
                                              });
                                              
                                              await followNotifier.unfollow();
                                            } else {
                                              // 팔로우
                                              followNotifier.optimisticFollow();
                                              setState(() {
                                                _userResults = _userResults.map((u) {
                                                  return u.id == e.id ? u.copyWith(isFollowing: true) : u;
                                                }).toList();
                                              });
                                              
                                              await followNotifier.follow();
                                            }
                                          } catch (err) {
                                            debugPrint('❌ 팔로우 실패: $err');
                                            // 실패 시 롤백
                                            final followNotifier = ref.read(followStateProvider(e.id).notifier);
                                            if (e.isFollowing) {
                                              followNotifier.optimisticFollow();
                                            } else {
                                              followNotifier.optimisticUnfollow();
                                            }
                                            setState(() {
                                              _userResults = _userResults.map((u) {
                                                return u.id == e.id ? u.copyWith(isFollowing: e.isFollowing) : u;
                                              }).toList();
                                            });
                                          }
                                        },
                                        onTapProfile: () async {
                                          final result = await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => OtherProfileScreen(userId: e.id),
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
                                  padding: const EdgeInsets.symmetric(horizontal: 22),
                                  child: Text(
                                    "책",
                                    style: TextStyle(
                                        fontSize: 16, color: AppColors.black900),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 26),
                                  child: GridView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
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
          _query.isEmpty
              ? const SizedBox.shrink() // 🔍 검색 전에는 아무것도 안 보이게
              : _userResults.isEmpty
                  ? Container(
                      color: Colors.white,
                      alignment: Alignment.center,
                      child: const Text(
                        '검색 결과가 없어요.',
                        style:
                            TextStyle(fontSize: 14, color: AppColors.black500),
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
                                .map((e) => FollowUserTile(
                              userId: e.id,
                              username: e.username,
                              name: e.name,
                              avatarUrl: e.avatarUrl ?? 'basic',
                              isMyProfile: false,
                              currentUserId: Supabase.instance.client.auth.currentUser!.id,
                              onTapFollow: () async {
                                try {
                                  final followNotifier = ref.read(followStateProvider(e.id).notifier);
                                  
                                  if (e.isFollowing) {
                                    // 언팔로우
                                    followNotifier.optimisticUnfollow();
                                    setState(() {
                                      _userResults = _userResults.map((u) {
                                        return u.id == e.id ? u.copyWith(isFollowing: false) : u;
                                      }).toList();
                                    });
                                    
                                    await followNotifier.unfollow();
                                  } else {
                                    // 팔로우
                                    followNotifier.optimisticFollow();
                                    setState(() {
                                      _userResults = _userResults.map((u) {
                                        return u.id == e.id ? u.copyWith(isFollowing: true) : u;
                                      }).toList();
                                    });
                                    
                                    await followNotifier.follow();
                                  }
                                } catch (err) {
                                  debugPrint('❌ 팔로우 실패: $err');
                                  // 실패 시 롤백
                                  final followNotifier = ref.read(followStateProvider(e.id).notifier);
                                  if (e.isFollowing) {
                                    followNotifier.optimisticFollow();
                                  } else {
                                    followNotifier.optimisticUnfollow();
                                  }
                                  setState(() {
                                    _userResults = _userResults.map((u) {
                                      return u.id == e.id ? u.copyWith(isFollowing: e.isFollowing) : u;
                                    }).toList();
                                  });
                                }
                              },
                              onTapProfile: () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => OtherProfileScreen(userId: e.id),
                                  ),
                                );
                                
                                // 프로필 화면에서 돌아왔을 때 팔로우 상태가 변경되었을 수 있으므로
                                // 해당 사용자의 팔로우 상태를 다시 확인
                                if (result == true) {
                                  await _updateFollowStatus(e.id);
                                }
                              },
                            ),)
                                .toList(),
                          ),
                        ),
                      ],
                    ),
          _query.isEmpty
              ? const SizedBox.shrink() // 🔍 검색 전에는 아무것도 안 보이게
              : _bookResults.isEmpty
                  ? const Center(
                      child: Text(
                        '검색 결과가 없어요.',
                        style:
                            TextStyle(fontSize: 14, color: AppColors.black500),
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
                            padding: const EdgeInsets.only(left:4),
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
