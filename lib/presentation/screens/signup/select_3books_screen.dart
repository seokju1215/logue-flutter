import 'dart:async';
import 'package:flutter/material.dart';
import 'package:logue/core/themes/app_colors.dart';
import '../../../data/datasources/aladin_book_api.dart';
import '../../../data/models/book_model.dart';
import '../../../data/utils/amplitude_util.dart';
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
  final SupabaseClient client = Supabase.instance.client;

  List<BookModel> _results = [];
  List<BookModel> _selectedBooks = [];
  bool _isLoading = false;
  String _currentQuery = '';
  Timer? _debounce; // ✅ 디바운싱 타이머

  void _search(String query) async {
    _currentQuery = query;
    if (query.isEmpty) {
      setState(() => _results = []);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final rawResults = await AladinBookApi().searchBooks(query);
      final results =
          rawResults.map((data) => BookModel.fromJson(data)).toList();

      setState(() => _results = results);
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

  bool _isSelected(BookModel book) {
    return _selectedBooks.any((b) => b.image == book.image);
  }

  Future<String> _getOrInsertBookId(BookModel book) async {
    Map<String, dynamic>? existing;
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
        final retry = await client
            .from('books')
            .select('id')
            .eq('isbn', book.isbn!)
            .maybeSingle();
        if (retry != null && retry['id'] != null) {
          return retry['id'];
        }
      }

      rethrow;
    }
  }

  Future<void> _submitBooks() async {
    final user = client.auth.currentUser;
    if (user == null) return;

    final insertProfile = InsertProfileUseCase(client);

    await insertProfile(
      id: user.id,
      username: generateRandomUsername(),
      name: user.userMetadata?['full_name'] ?? '이름 없음',
      job: '사용자',
      bio: '',
      avatarUrl: 'basic',
    );

    try {
      await client
          .rpc('increment_job_tag_count', params: {'input_job_name': '사용자'});
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
        AmplitudeUtil.log('book_added', props: {
          'source': 'select_3books',
          'review_length': 0,
          'timestamp': DateTime.now().toIso8601String(),
        });
      }

      if (context.mounted) {
        await FcmPermissionUtil.requestOnceIfNeeded();
        Navigator.pushReplacementNamed(
          context,
          '/main',
          arguments: {
            'initialTabIndex': 1,
          },
        );
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
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
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
                    ? AppColors.blue500
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
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 0),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: _search,
              onChanged: (value) {
                if (_debounce?.isActive ?? false) _debounce!.cancel();
                _debounce = Timer(const Duration(milliseconds: 400), () {
                  _search(value);
                });
              },
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF191A1C),
              ),
              decoration: InputDecoration(
                hintText: "책 이름을 검색해주세요.",
                hintStyle: TextStyle(fontSize: 14, color: AppColors.black500),
                filled: true,
                fillColor: AppColors.black200,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 9, horizontal: 9),
                border: const OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.black200),
                ),
                enabledBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.black200),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.black200),
                ),
                isDense: true,
                counter: const SizedBox.shrink(),
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
                  const SizedBox(),
                Text(
                  '${_selectedBooks.length}/3',
                  style: TextStyle(fontSize: 12, color: AppColors.black500),
                ),
              ],
            ),
          ),
          Expanded(
            child: isQueryEmpty
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: const [
                      Text(
                        "프로필에서 언제든 수정이 가능해요.",
                        style:
                            TextStyle(fontSize: 12, color: AppColors.black500),
                      ),
                      SizedBox(height: 140,)
                    ],
                  )
                : _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _results.isEmpty
                        ? const Center(child: Text("검색 결과가 없습니다."))
                        : GridView.builder(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 21, vertical: 20),
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
                                      width: 3,
                                    ),
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
