import 'package:flutter/material.dart';
import '../../../data/datasources/naver_book_api.dart';
import '../../../data/models/book_model.dart';

class Select3BooksScreen extends StatefulWidget {
  const Select3BooksScreen({super.key});

  @override
  State<Select3BooksScreen> createState() => _Select3BooksScreenState();
}

class _Select3BooksScreenState extends State<Select3BooksScreen> {
  final _searchController = TextEditingController();
  List<BookModel> _results = [];
  List<BookModel> _selectedBooks = [];
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
      final results = await NaverBookApi().searchBooks(query);
      setState(() {
        _results = results;
      });
    } catch (e) {
      print('검색 실패: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _toggleSelection(BookModel book) {
    setState(() {
      if (_selectedBooks.contains(book)) {
        _selectedBooks.remove(book);
      } else {
        if (_selectedBooks.length < 3) {
          _selectedBooks.add(book);
        }
      }
    });
  }

  bool _isSelected(BookModel book) {
    return _selectedBooks.any((b) => b.image == book.image);
  }

  @override
  Widget build(BuildContext context) {
    final isQueryEmpty = _searchController.text.isEmpty;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text("책 추가", style: Theme.of(context).textTheme.titleMedium),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              onChanged: _search,
              decoration: const InputDecoration(
                hintText: "책 이름을 검색해주세요.",
                border: OutlineInputBorder(),
              ),
            ),
          ),

          // 선택된 개수 표시
          Padding(
            padding: const EdgeInsets.only(right: 16, bottom: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '${_selectedBooks.length}/3',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),

          // 검색어 표시
          if (!isQueryEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 8),
              child: Row(
                children: [
                  Text(
                    '“$_currentQuery” 검색결과',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),

          // 검색 결과 영역
          Expanded(
            child: isQueryEmpty
                ? const SizedBox.shrink() // 아무것도 표시하지 않음
                : _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _results.isEmpty
                ? const Center(child: Text("검색 결과가 없습니다."))
                : GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.7,
              ),
              itemCount: _results.length,
              itemBuilder: (context, index) {
                final book = _results[index];
                final isSelected = _isSelected(book);

                return GestureDetector(
                  onTap: () => _toggleSelection(book),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isSelected
                            ? Colors.blue
                            : Colors.transparent,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(
                        book.image,
                        fit: BoxFit.cover,
                      ),
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