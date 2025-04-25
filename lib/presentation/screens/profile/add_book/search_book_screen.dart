import 'package:flutter/material.dart';
import 'package:logue/core/themes/app_colors.dart';
import '../../../../data/datasources/kakao_book_api.dart';
import '../../../../data/models/book_model.dart';
import 'package:logue/core/widgets/book/book_frame.dart';
import 'package:logue/presentation/screens/profile/add_book/write_review_screen.dart';

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

  void _search(String query) async {
    _currentQuery = query;
    if (query.isEmpty) {
      setState(() {
        _results = [];
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      final rawResults = await KakaoBookApi().searchBooks(query);
      final results = rawResults.map((data) => BookModel.fromJson(data)).toList();

      setState(() {
        _results = results;
      });
    } catch (e) {
      print('검색 실패: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _selectBook(BookModel book) {
    setState(() {
      _selectedBook = _selectedBook == book ? null : book;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isQueryEmpty = _searchController.text.isEmpty;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text("책 추가", style: TextStyle(fontSize: 18, color: AppColors.black900),),
      ),
      body: Column(
        children: [
          const Padding(
            padding: const EdgeInsets.fromLTRB(31, 20, 0, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "책 이름",
                style: const TextStyle(fontSize: 14, color: AppColors.black500),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 3, 22, 12),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: _search,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF191A1C),
                fontWeight: FontWeight.w400,
              ),
              decoration: InputDecoration(
                hintText: "책 이름을 검색해주세요.",
                hintStyle: TextStyle(fontSize: 14, color: AppColors.black500),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.black500, width: 1.0),
                  borderRadius: BorderRadius.circular(5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.black500, width: 1.0),
                  borderRadius: BorderRadius.circular(5),
                ),
                contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 9),
              ),
            ),
          ),
          if (!isQueryEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 31, bottom: 8),
              child: Row(
                children: [
                  Text(
                    '“$_currentQuery” 검색결과',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          Expanded(
            child: isQueryEmpty
                ? const SizedBox.shrink()
                : _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _results.isEmpty
                ? const Center(child: Text("검색 결과가 없습니다."))
                : GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 21),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.7,
              ),
              itemCount: _results.length,
              itemBuilder: (context, index) {
                final book = _results[index];
                final isSelected = _selectedBook == book;

                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => WriteReviewScreen(book: book),
                      ),
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isSelected ? Colors.blue : Colors.transparent,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(0),
                    ),
                    child: ClipRRect(
                      child: BookFrame(imageUrl: book.image),
                    ),
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