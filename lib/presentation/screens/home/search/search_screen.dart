import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:logue/core/themes/app_colors.dart';
import 'package:logue/core/widgets/search/search_user_item.dart';
import 'package:logue/core/widgets/book/book_frame.dart';
import 'package:logue/data/models/book_model.dart';
import 'package:logue/data/models/user_profile.dart';
import 'package:logue/domain/usecases/search_users.dart';
import 'package:logue/data/datasources/kakao_book_api.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with TickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  List<UserProfile> _userResults = [];
  List<BookModel> _bookResults = [];
  bool _isLoading = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
      final booksRaw = await KakaoBookApi().searchBooks(query);
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
              hintStyle: const TextStyle(color: AppColors.black500, fontSize: 14),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
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
                child: Divider(height: 1, thickness: 1, color: AppColors.black500),
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
                              color: isSelected ? AppColors.black900 : AppColors.black500,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 6),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            height: 2,
                            width: 56,
                            color: isSelected ? AppColors.black900 : Colors.transparent,
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
              : SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
            child: Column(
              children: [
                ..._userResults.take(6).map((e) => SearchUserItem(
                  user: e,
                  isFollowing: e.isFollowing,
                  onTapFollow: () {},
                )),
                const SizedBox(height: 20),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
                )
              ],
            ),
          ),
          ListView(
            padding: const EdgeInsets.all(20),
            children: _userResults.map((e) => SearchUserItem(
              user: e,
              isFollowing: e.isFollowing,
              onTapFollow: () {},
            )).toList(),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
          ),
        ],
      ),
    );
  }
}
