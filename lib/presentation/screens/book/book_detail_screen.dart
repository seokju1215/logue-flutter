import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/widgets/book/book_frame.dart';
import '../../../core/widgets/follow/follow_user_tile.dart';
import 'package:logue/data/datasources/aladin_book_api.dart';

class BookDetailScreen extends StatefulWidget {
  final String bookId; // UUID로 변경
  const BookDetailScreen({super.key,  required this.bookId});

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen> {
  Map<String, dynamic>? book;
  List<dynamic> lifebookUsers = [];
  String? errorMessage;
  bool isLoading = true;
  bool showFullDescription = false;
  bool showFullToc = false;
  bool showAllAuthors = false;
  Map<String, List<Map<String, dynamic>>> authorBooks = {};

  @override
  void initState() {
    super.initState();
    _fetchBookOnly();
  }

  Future<void> _fetchBookOnly() async {
    try {
      final res = await Supabase.instance.client.functions.invoke(
        'get-book-detail',
        body: {'book_id': widget.bookId},
      );

      final decoded = res.data as Map<String, dynamic>;
      final bookData = decoded['book'];
      print("bookData = ${jsonEncode(bookData)}");
      final authors = _extractAuthors(bookData['author']?.toString() ?? '');

      setState(() {
        book = bookData;
        lifebookUsers = decoded['lifebooks'] ?? [];
        errorMessage = decoded['error'];
        isLoading = false;
      });
      await _fetchOtherBooks(authors);

    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }
  List<String> _extractAuthors(String? authorString) {
    if (authorString == null || authorString.isEmpty) return [];

    final regex = RegExp(r'([^,(]+)\s+\([^)]+\)');
    final matches = regex.allMatches(authorString);
    return matches.map((m) => m.group(1)!.trim()).toList();
  }
  Future<void> _fetchOtherBooks(List<String> authors) async {
    final api = AladinBookApi();
    Map<String, List<Map<String, dynamic>>> result = {};
    for (final author in authors) {
      final books = await api.searchBooksByAuthor(author);
      if (books.isNotEmpty) {
        result[author] = books;
      }
    }
    setState(() {
      authorBooks = result;
    });
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(book?['title'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text(book?['subTitle'] ?? '', style: const TextStyle(fontSize: 12, color: AppColors.black500)),
                const SizedBox(height: 12),
                Text(book?['author'] ?? '', style: const TextStyle(fontSize: 12, color: AppColors.black500)),
                Text('${book?['publisher'] ?? ''} | ${book?['published_date']?.toString().split("-").take(2).join(". ") ?? ''}',
                    style: const TextStyle(fontSize: 12, color: AppColors.black500)),
                if (book?['page_count'] != null)
                  Text('${book?['page_count']} P', style: const TextStyle(fontSize: 12, color: AppColors.black500)),
              ],
            ),
          ),
          const SizedBox(width: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(0),
            child: Image.network(
              book?['image'] ?? '',
              width: 120,
              height: 180,
              fit: BoxFit.cover,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLifeBookSection() {
    if (lifebookUsers.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Divider(height: 40, color: AppColors.black100),
      );
    }

    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final sortedUsers = [...lifebookUsers]..sort((a, b) {
      if (a['id'] == currentUserId) return -1;
      if (b['id'] == currentUserId) return 1;
      return 0;
    });

    final shownUsers = sortedUsers.take(3).toList();
    final moreThanThree = lifebookUsers.length > 3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('이 책을 인생 책으로 설정한 사람', style: TextStyle(color:AppColors.black900,fontSize: 14)),
              Text('${lifebookUsers.length}명', style: const TextStyle(fontSize: 14, color: AppColors.black500)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Column(
          children: shownUsers.map((user) {
            return FollowUserTile(
              userId: user['id'],
              username: user['username'],
              name: user['name'],
              avatarUrl: user['avatar_url'] ?? 'basic',
              isFollowing: user['is_following'] ?? false,
              showActions: user['id'] != currentUserId,
              showdelete: false,
              onTapFollow: () {},
              onTapProfile: () {
                Navigator.pushNamed(context, '/other_profile', arguments: user['id']);
              },
            );
          }).toList(),
        ),
        SizedBox(
          height: 50,
          child: Column(
            children: [
              if (moreThanThree)
                Center(
                  child: TextButton(
                    onPressed: () {},
                    child: const Text("더보기", style: TextStyle(color: AppColors.black500)),
                  ),
                ),
              const Spacer(),
              const Divider(height: 1, color: AppColors.black300),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildExpandableText(String title, String? content, int maxLines, bool expanded, VoidCallback onToggle) {
    if (content == null || content.trim().isEmpty) return const SizedBox.shrink();

    final lines = content.trim().split(RegExp(r'\r?\n'));
    final showMore = lines.length > maxLines;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: AppColors.black900, fontSize: 14)),
          const SizedBox(height: 12),
          ...lines.take(expanded ? lines.length : maxLines).map((line) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(line, style: const TextStyle(fontSize: 14, color: AppColors.black500)),
          )),
          SizedBox(
            height: 50,
            child: Column(
              children: [
                if (showMore && !expanded)
                  Center(
                    child: TextButton(
                      onPressed: onToggle,
                      child: const Text("더보기"),
                    ),
                  ),
                const Spacer(),
                const Divider(height: 1, color: AppColors.black300),
              ],
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildOtherWorksSection() {
    if (authorBooks.isEmpty) return const SizedBox.shrink();
    final authors = authorBooks.keys.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text('저자의 다른 작품', style: TextStyle(fontSize: 14, color: AppColors.black900)),
        ),
        const SizedBox(height: 12),

        // 첫 번째 저자 책 목록
        SizedBox(
          height: 240,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: authorBooks[authors.first]!
                .map((book) => _buildBookCard(book))
                .toList(),
          ),
        ),

        // 더보기 버튼
        if (authors.length > 1 && !showAllAuthors)
          Center(
            child: TextButton(
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () {
                setState(() => showAllAuthors = true);
              },
              child: const Text("더보기"),
            ),
          ),

        // 추가 저자들 (더보기 누른 후)
        if (showAllAuthors && authors.length > 1)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: authors.skip(1).map((author) {
              final books = authorBooks[author]!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Text('$author 저자의 다른 책',
                        style: const TextStyle(fontSize: 14, color: AppColors.black900)),
                  ),
                  SizedBox(
                    height: 240,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children: books.map((book) => _buildBookCard(book)).toList(),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),

        // 마지막 Divider는 항상 하단에 고정
        const SizedBox(height: 12),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Divider(height: 1, color: AppColors.black300),
        ),
      ],
    );
  }

  Widget _buildBookCard(Map<String, dynamic> book) {
    return Container(
      width: 120,
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            height: 180,
            child: BookFrame(imageUrl: book['image'] ?? ''),
          ),
          const SizedBox(height: 8),
          Text(
            book['title'] ?? '',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: AppColors.black900),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (book == null) {
      return Scaffold(body: Center(child: Text(errorMessage ?? '책 정보를 불러오지 못했어요.')));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        title: const Text('책 정보', style: TextStyle(fontSize: 18, color: AppColors.black900)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.black900),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 37),
            _buildLifeBookSection(),
            const SizedBox(height: 37),
            _buildExpandableText("책 정보", book?['description'], 5, showFullDescription, () {
              setState(() => showFullDescription = true);
            }),
            book?['toc'] == '' ? const SizedBox(height: 37) : const SizedBox.shrink(),
            _buildExpandableText("목차", book?['toc'], 7, showFullToc, () {
              setState(() => showFullToc = true);
            }),
            const SizedBox(height: 37),
            _buildOtherWorksSection(),
            const SizedBox(height: 40),
          ],

        ),
      ),
    );
  }
}
