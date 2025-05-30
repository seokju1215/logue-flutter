import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:logue/core/themes/app_colors.dart';
import 'package:logue/core/widgets/search/search_user_item.dart';
import 'package:logue/core/widgets/book/book_frame.dart';
import 'package:logue/data/models/book_model.dart';
import 'package:logue/data/models/user_profile.dart';
import 'package:logue/domain/usecases/search_users.dart';
import 'package:logue/data/datasources/aladin_book_api.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:logue/data/repositories/follow_repository.dart';
import 'package:logue/domain/usecases/follows/follow_user.dart';
import 'package:logue/domain/usecases/follows/unfollow_user.dart';
import 'package:logue/domain/usecases/follows/is_following.dart';
import '../../profile/other_profile_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
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
    setState(() {
      _isLoading = true;
      _query = query;
    });
    try {
      final users = await SearchUsers().call(query);

      // ✅ AladinBookApi 사용
      final booksRaw = await AladinBookApi().searchBooks(query);
      final books = booksRaw.map((data) => BookModel.fromJson(data)).toList();

      setState(() {
        _userResults = users;
        _bookResults = books;
      });
    } catch (e) {
      print('검색 오류: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _onTapBook(BookModel book) async {
    final client = Supabase.instance.client;

    if (book.isbn == null || book.isbn.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ISBN이 유효하지 않아요.')),
      );
      return;
    }

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

      Navigator.pushNamed(
        context,
        '/book_detail',
        arguments: bookId,
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
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 0),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(color: AppColors.black900, fontSize: 14),
            decoration: InputDecoration(
              hintText: '사용자 이름 또는 책 이름을 검색해주세요.',
              hintStyle:
                  const TextStyle(color: AppColors.black500, fontSize: 14),
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
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40),
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
                          const SizedBox(height: 19),
                          Text(
                            labels[index],
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
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
                              vertical: 20, horizontal: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_userResults.isNotEmpty) ...[Text(
                                "계정",
                                style: TextStyle(
                                    fontSize: 16, color: AppColors.black900),
                              ),
                              const SizedBox(height: 6),
                              ..._userResults.take(6).map(
                                    (e) => SearchUserItem(
                                      user: e,
                                      isFollowing: e.isFollowing,
                                      onTapFollow: () async {
                                        try {
                                          if (e.isFollowing) {
                                            await _unfollowUser(e.id);
                                          } else {
                                            await _followUser(e.id);
                                          }

                                          final updatedFollow =
                                              await _isFollowing(e.id);
                                          setState(() {
                                            _userResults =
                                                _userResults.map((u) {
                                              return u.id == e.id
                                                  ? u.copyWith(
                                                      isFollowing:
                                                          updatedFollow)
                                                  : u;
                                            }).toList();
                                          });
                                        } catch (err) {
                                          debugPrint('❌ 팔로우 실패: $err');
                                        }
                                      },
                                      onTapProfile: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => OtherProfileScreen(
                                                userId: e.id),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                              const SizedBox(height: 26),],
                              if (_bookResults.isNotEmpty) ...[Text(
                                "책",
                                style: TextStyle(
                                    fontSize: 16, color: AppColors.black900),
                              ),
                              const SizedBox(height: 4),
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  mainAxisSpacing: 12,
                                  crossAxisSpacing: 12,
                                  childAspectRatio: 0.7,
                                ),
                                itemCount: _bookResults.length,
                                itemBuilder: (context, index) {
                                  final book = _bookResults[index];

                                  return GestureDetector(
                                    onTap: () => _onTapBook(book),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: Image.network(book.image, fit: BoxFit.cover),
                                    ),
                                  );
                                },
                              )],
                            ],
                          ),
                        ),
          _userResults.isEmpty
              ? const Expanded(
                  child: Center(
                    child: Text(
                      '검색 결과가 없어요.',
                      style: TextStyle(fontSize: 14, color: AppColors.black500),
                    ),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
                      child: Text("계정",
                          style: TextStyle(
                              fontSize: 16, color: AppColors.black900)),
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        children: _userResults
                            .map((e) => SearchUserItem(
                                  user: e,
                                  isFollowing: e.isFollowing,
                                  onTapFollow: () {},
                                  onTapProfile: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            OtherProfileScreen(userId: e.id),
                                      ),
                                    );
                                  },
                                ))
                            .toList(),
                      ),
                    ),
                  ],
                ),
          _bookResults.isEmpty
              ? const Expanded(
                  child: Center(
                    child: Text('검색 결과가 없어요.',
                        style:
                            TextStyle(fontSize: 14, color: AppColors.black500)),
                  ),
                )
              : Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '책',
                        style:
                            TextStyle(fontSize: 16, color: AppColors.black900),
                      ),
                      const SizedBox(height: 8),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.7,
                        ),
                        itemCount: _bookResults.length,
                        itemBuilder: (context, index) {
                          final book = _bookResults[index];
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.network(book.image, fit: BoxFit.cover),
                          );
                        },
                      ),
                    ],
                  ),
                )
        ],
      ),
    );
  }
}
