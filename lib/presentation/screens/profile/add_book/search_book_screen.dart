import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:my_logue/core/themes/app_colors.dart';
import '../../../../data/datasources/aladin_book_api.dart';
import '../../../../data/models/book_model.dart';
import 'package:my_logue/core/widgets/book/book_frame.dart';
import 'package:my_logue/presentation/screens/profile/add_book/write_review_screen.dart';
import '../../../../data/utils/mixpanel_util.dart';
import 'dart:async'; // ✅ 디바운싱 타이머를 위한 임포트

class SearchBookScreen extends StatefulWidget {
  const SearchBookScreen({super.key});

  @override
  State<SearchBookScreen> createState() => _SearchBookScreenState();
}

class _SearchBookScreenState extends State<SearchBookScreen> {
  final _searchController = TextEditingController();
  List<BookModel> _results = [];
  BookModel? _selectedBook;
  bool _isLoading = false;
  String _currentQuery = '';
  Timer? _debounce; // ✅ 디바운싱 타이머
  bool _isSearching = false; // ✅ 중복 검색 방지 플래그

  void _search(String query) async {
    if (_isSearching) {
      return;
    }
    
    _currentQuery = query;
    if (query.isEmpty) {
      setState(() {
        _results = [];
      });
      return;
    }

    // 책 검색 트래킹
    MixpanelUtil.trackBookSearch(query);

    setState(() => _isLoading = true);
    _isSearching = true;

    try {
      final rawResults = await AladinBookApi().searchBooks(query);
      final results = rawResults.map((data) => BookModel.fromJson(data)).toList();

      if (mounted) {
        setState(() {
          _results = results;
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

  void _selectBook(BookModel book) {
    setState(() {
      _selectedBook = _selectedBook == book ? null : book;
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isQueryEmpty = _searchController.text.isEmpty;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56), // 일반 AppBar 높이
        child: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: Colors.white,
          elevation: 0,
          titleSpacing: 0,
          title: Row(
            children: [
              IconButton(
                icon: SvgPicture.asset('assets/back_arrow.svg'),
                onPressed: () => Navigator.pop(context),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: SizedBox(
                    height: 38,
                    child: TextField(
                      controller: _searchController,
                      textInputAction: TextInputAction.search,
                      onSubmitted: _search,
                      onChanged: (value) {
                        if (_debounce?.isActive ?? false) _debounce!.cancel();
                        _debounce = Timer(const Duration(milliseconds: 500), () {
                          _search(value);
                        });
                      },
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF191A1C),
                        fontWeight: FontWeight.w400,
                      ),
                      decoration: InputDecoration(
                        hintText: "책 이름을 검색해주세요.",
                        hintStyle: const TextStyle(fontSize: 14, color: AppColors.black500),
                        filled: true,
                        fillColor: AppColors.black200,
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: AppColors.black200, width: 1.0),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: AppColors.black200, width: 1.0),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 9),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          if (_searchController.text.isNotEmpty)
          Expanded(
            child: _searchController.text.isEmpty
                ? const SizedBox.shrink()
                : _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _results.isEmpty
                ? const Center(child: Text("검색 결과가 없습니다.", style: TextStyle(
    fontSize: 14, color: AppColors.black500),
    ),)
                : GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.7,
              ),
              itemCount: _results.length,
              itemBuilder: (context, index) {
                final book = _results[index];
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => WriteReviewScreen(book: book),
                      ),
                    );
                  },
                  child: ClipRRect(
                    child: BookFrame(imageUrl: book.image),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}