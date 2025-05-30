import 'package:flutter/material.dart';
import 'package:logue/core/themes/app_colors.dart';
import '../../../data/datasources/kakao_book_api.dart';
import '../../../data/models/book_model.dart';
import '../../../data/utils/fcmPermissionUtil.dart';
import '../../../domain/usecases/add_book.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logue/domain/usecases/insert_profile.dart';
import 'package:logue/core/widgets/book/book_frame.dart';

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
      final rawResults = await KakaoBookApi().searchBooks(query);

      final results =
          rawResults.map((data) => BookModel.fromJson(data)).toList();
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

  String generateRandomUsername() {
    final random = DateTime.now().millisecondsSinceEpoch;
    return 'log_${random.toString().substring(7)}';
  }

  String generateRandomProfileUrl() {
    final random = DateTime.now().millisecondsSinceEpoch;
    return 'log-${random.toString().substring(5)}';
  }

  bool _isSelected(BookModel book) {
    return _selectedBooks.any((b) => b.image == book.image);
  }

  Future<String> _getOrInsertBookId(BookModel book) async {
    final client = Supabase.instance.client;

    Map<String, dynamic>? existing;

    // ✅ ISBN이 유효할 때만 중복 확인
    final hasValidIsbn = book.isbn.isNotEmpty;

    if (hasValidIsbn) {
      existing = await client
          .from('books')
          .select('id')
          .eq('isbn', book.isbn!)
          .maybeSingle();

      if (existing != null && existing['id'] != null) {
        return existing['id'];
      }
    }

    // ✅ ISBN 외 정보로도 중복 체크 (title + author)
    if (!hasValidIsbn || existing == null || existing['id'] == null) {
      existing = await client
          .from('books')
          .select('id')
          .eq('title', book.title)
          .eq('author', book.author)
          .maybeSingle();

      if (existing != null && existing['id'] != null) {
        return existing['id'];
      }
    }

    try {
      final inserted = await client
          .from('books')
          .insert(book.toBookMap())
          .select('id')
          .maybeSingle();

      if (inserted == null || inserted['id'] == null) {
        throw Exception('책 저장 실패');
      }

      return inserted['id'];
    } on PostgrestException catch (e) {
      if (e.code == '23505' && hasValidIsbn) {
        // 중복 ISBN으로 insert 실패했을 때 재조회
        final retry = await client
            .from('books')
            .select('id')
            .eq('isbn', book.isbn!)
            .maybeSingle();
        if (retry != null && retry['id'] != null) {
          return retry['id'];
        }
      }

      rethrow; // 다른 오류는 다시 던짐
    }
  }

  Future<void> _submitBooks() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;

    if (user == null) return;

    final insertProfile = InsertProfileUseCase(client);

    // 1. 프로필 insert
    await insertProfile(
      id: user.id,
      username: generateRandomUsername(),
      name: user.userMetadata?['full_name'] ?? '이름 없음',
      job: '사용자',
      bio: '',
      profileUrl: generateRandomProfileUrl(),
      avatarUrl: 'basic',
    );

    try {
      await client.rpc('increment_job_tag_count', params: {'input_job_name': '사용자'});
    } catch (e) {
      debugPrint('job_tags 증가 실패: $e');
    }

    try {
      await client.rpc('increment_all_order_indices', params: {'uid': user.id});

      for (int i = 0; i < _selectedBooks.length; i++) {
        final book = _selectedBooks[i];
        final bookId = await _getOrInsertBookId(book);

        await client.from('user_books').insert({
          'user_id': user.id,
          'book_id': bookId,
          'isbn': book.isbn.isNotEmpty ? book.isbn : '',
          'order_index': i,
          'review_title': '',
          'review_content': '',
        });
      }

      if (context.mounted) {
        await FcmPermissionUtil.requestOnceIfNeeded();
        Navigator.pushReplacementNamed(context, '/main');
      }
    } catch (e) {
      debugPrint('❌ 책 저장 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('저장에 실패했어요. 다시 시도해주세요.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isQueryEmpty = _searchController.text.isEmpty;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: Text(
          "인생 책 3권을 선택해주세요",
          style: TextStyle(fontSize: 16, color: AppColors.black900),
        ),
        actions: [
          TextButton(
            onPressed: _selectedBooks.length == 3 ? _submitBooks : null,
            child: Text(
              "확인",
              style: TextStyle(
                color: _selectedBooks.length == 3
                    ? Color(0xFF0055FF)
                    : Colors.grey,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 3, 22, 0),
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
                filled: true,
                fillColor: AppColors.black200,
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.black200, width: 1.0),
                  borderRadius: BorderRadius.circular(5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.black200, width: 1.0),
                  borderRadius: BorderRadius.circular(5),
                ),
                contentPadding:
                    EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 31, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (!isQueryEmpty)
                  Text(
                    '“$_currentQuery” 검색결과',
                    style: TextStyle(fontSize: 12, color: AppColors.black500),
                  )
                else
                  const SizedBox(), // 자리 유지를 위한 빈 위젯

                Text(
                  '${_selectedBooks.length}/3',
                  style: TextStyle(fontSize: 12, color: AppColors.black500),
                ),
              ],
            ),
          ),
          Expanded(
            child: isQueryEmpty
                ? const Center(
                    child: Text(
                      "프로필에서 언제든 수정이 가능해요.",
                      style: TextStyle(fontSize: 12, color: AppColors.black500),
                    ),
                  )
                : _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _results.isEmpty
                        ? const Center(child: Text("검색 결과가 없습니다."))
                        : GridView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 21, vertical: 20),
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
