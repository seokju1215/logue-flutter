import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:my_logue/presentation/screens/book/life_book_users_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/widgets/book/book_frame.dart';
import '../../../core/widgets/common/custom_app_bar.dart';
import '../../../core/widgets/follow/follow_user_tile.dart';
import 'package:my_logue/data/datasources/aladin_book_api.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/providers/follow_state_provider.dart';
import '../profile/other_profile_screen.dart';
import 'package:html_unescape/html_unescape.dart';

class BookDetailScreen extends ConsumerStatefulWidget {
  final String bookId;

  const BookDetailScreen({super.key, required this.bookId});

  @override
  ConsumerState<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends ConsumerState<BookDetailScreen> {
  String? currentUserId;
  Map<String, dynamic>? book;
  List<dynamic> lifebookUsers = [];
  String? errorMessage;
  bool isLoading = true;
  bool showFullDescription = false;
  bool showFullToc = false;
  bool showAllAuthors = false;
  Map<String, List<Map<String, dynamic>>> authorBooks = {};
  final HtmlUnescape _unescape = HtmlUnescape();
  String truncatedText = '';
  bool shouldShowMoreButton = false;

  @override
  void initState() {
    super.initState();
    currentUserId = Supabase.instance.client.auth.currentUser?.id;
    _fetchBookOnly();
  }

  List<Map<String, dynamic>> _getSortedUsers(List<dynamic> users) {
    final sortedUsers = users.map((user) {
      final isFollowing = ref.read(followStateProvider(user['id']));
      return Map<String, dynamic>.from({
        ...user,
        'isFollowing': isFollowing,
      });
    }).toList();
    
    sortedUsers.sort((a, b) {
      // 내 프로필이 최상단
      if (a['id'] == currentUserId) return -1;
      if (b['id'] == currentUserId) return 1;
      
      // 팔로우한 사람이 위로
      if (a['isFollowing'] == true && b['isFollowing'] != true) return -1;
      if (a['isFollowing'] != true && b['isFollowing'] == true) return 1;
      
      return 0;
    });
    
    return sortedUsers;
  }

  Future<void> _launchAladinLink(String? url) async {
    if (url == null || url.isEmpty) return;
    final cleanedUrl = url.replaceAll('&amp;', '&');
    final uri = Uri.parse(cleanedUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _fetchLifebookUsersOnly() async {
    try {
      final body = {
        if (widget.bookId.length == 36) 'book_id': widget.bookId,
        if (widget.bookId.length != 36) 'isbn': widget.bookId,
      };

      final res = await Supabase.instance.client.functions.invoke(
        'get-book-detail',
        body: body,
      );

      final decoded = res.data as Map<String, dynamic>;
      final rawUsers = decoded['lifebooks'] ?? [];
      final seenIds = <String>{};
      final uniqueUsers = <dynamic>[];

      for (final u in rawUsers) {
        if (u is Map && seenIds.add(u['id'])) {
          uniqueUsers.add(u);
        }
      }

      if (!mounted) return;

      setState(() {
        lifebookUsers = uniqueUsers;
      });
    } catch (e) {
      debugPrint('❌ 인생책 유저 조회 실패: $e');
    }
  }

  Future<void> _fetchBookOnly() async {
    try {
      final body = {
        if (widget.bookId.length == 36) 'book_id': widget.bookId,
        if (widget.bookId.length != 36) 'isbn': widget.bookId,
      };

      final res = await Supabase.instance.client.functions.invoke(
        'get-book-detail',
        body: body,
      );

      final decoded = res.data as Map<String, dynamic>;
      final bookData = decoded['book'];
      final authors = _extractAuthors(bookData['author']?.toString() ?? '');

      final rawUsers = decoded['lifebooks'] ?? [];
      final seenIds = <String>{};
      final uniqueUsers = <dynamic>[];

      for (final u in rawUsers) {
        if (u is Map && seenIds.add(u['id'])) {
          uniqueUsers.add(u);
        }
      }

      setState(() {
        book = bookData;
        lifebookUsers = _getSortedUsers(uniqueUsers);
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

    final endIdx = authorString.indexOf('(지은이)');
    String onlyAuthors = endIdx != -1
        ? authorString.substring(0, endIdx).trim()
        : authorString;

    if (onlyAuthors.endsWith(',')) {
      onlyAuthors = onlyAuthors.substring(0, onlyAuthors.length - 1).trim();
    }

    List<String> authorList = onlyAuthors.split(',').map((e) => e.trim()).toList();
    authorList = authorList.where((author) => author.isNotEmpty).toList();

    return authorList;
  }

  Future<void> _fetchOtherBooks(List<String> authors) async {
    if (authors.isEmpty) {
      return;
    }

    final api = AladinBookApi();
    Map<String, List<Map<String, dynamic>>> result = {};
    for (final author in authors) {
      try {
        final books = await api.searchBooksByAuthor(author);
        if (books.isNotEmpty) {
          result[author] = books;
        }
      } catch (e) {
        debugPrint('❌ 저자 "$author"의 책 검색 실패: $e');
      }
    }
    if (mounted) {
      setState(() {
        authorBooks = result;
      });
    }
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
                Text(book?['title'] ?? '',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                if (book?['subtitle'] != null &&
                    (book?['subtitle'] ?? '').toString().trim().isNotEmpty) ...[
                  Text(book?['subtitle'],
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.black500)),
                  const SizedBox(height: 10),
                ] else
                  const SizedBox(height: 35),
                Text(book?['author'] ?? '',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.black500)),
                const SizedBox(height: 2),
                Text(
                    '${book?['publisher'] ?? ''} | ${book?['published_date']?.toString().split("-").take(2).join(". ") ?? ''}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.black500)),
                const SizedBox(height: 2),
                if (book?['page_count'] != null)
                  Text('${book?['page_count']} P',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.black500)),
                const SizedBox(height: 2),
                Text('도서 정보: 알라딘 제공',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.black500)),
                const SizedBox(height: 2),
                TextButton(
                  onPressed: () => _launchAladinLink(book?['link']),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('알라딘에서 보기 >',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.blue500, height: 1.5)),
                )
              ],
            ),
          ),
          const SizedBox(width: 20),
          SizedBox(
              width: 103,
              height: 153,
              child: BookFrame(
                imageUrl: book?['image'] ?? '',
              )),
        ],
      ),
    );
  }

  Widget _buildLifeBookSection() {
    if (lifebookUsers.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 0),
      );
    }

    // 팔로우 상태 감지를 위해 Provider watch (정렬은 하지 않음)
    for (final user in lifebookUsers) {
      ref.watch(followStateProvider(user['id']));
    }
    
    final shownUsers = lifebookUsers.take(3).toList();
    final moreThanThree = lifebookUsers.length > 3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('이 책을 인생 책으로 설정한 사람',
                  style: TextStyle(color: AppColors.black900, fontSize: 14)),
              Text('${lifebookUsers.length}명',
                  style:
                      const TextStyle(fontSize: 14, color: AppColors.black500)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Column(
          children: shownUsers.map((user) {
            final isFollowing = ref.watch(followStateProvider(user['id']));
            return FollowUserTile(
              currentUserId: currentUserId ?? '',
              userId: user['id'],
              username: user['username'],
              name: user['name'],
              avatarUrl: user['avatar_url'] ?? 'basic',
              isMyProfile: false,
              onTapFollow: () async {
                final followNotifier = ref.read(followStateProvider(user['id']).notifier);
                followNotifier.optimisticFollow();
                try {
                  await followNotifier.follow();
                } catch (e) {
                  followNotifier.optimisticUnfollow();
                }
              },
              onTapProfile: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OtherProfileScreen(userId: user['id']),
                  ),
                );
              },
              isFollowing: isFollowing,
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
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LifebookUsersScreen(
                            users: lifebookUsers.map((e) => Map<String, dynamic>.from(e)).toList(),
                          ),
                        ),
                      );
                      setState(() {}); // Provider 상태로만 UI 갱신
                    },
                    child: const Text("더보기",
                        style:
                            TextStyle(color: AppColors.black900, fontSize: 12,fontWeight: FontWeight.w400)),
                  ),
                ),
              lifebookUsers.length>3?
              SizedBox(
                height: 0,
              ):SizedBox(
                height: 30,
              ),
              const Divider(height: 1, color: AppColors.black300),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildExpandableText(String title, String? content, int maxLines,
      bool expanded, VoidCallback onToggle) {
    if (content == null || content.trim().isEmpty)
      return const SizedBox.shrink();

    final lines = content.trim().split(RegExp(r'\r?\n'));
    final showMore = lines.length > maxLines;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22,),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              title == "목차"
              ? const SizedBox(height : 39)
              : const SizedBox(height : 22),
              Text(title,
                  style:
                      const TextStyle(color: AppColors.black900, fontSize: 14)),
              const SizedBox(height: 12),
              ...lines
                  .take(expanded ? lines.length : maxLines)
                  .map((line) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(line,
                            style: const TextStyle(
                                fontSize: 14, color: AppColors.black500, height : 2)),
                      )),
              const SizedBox(height: 30),
              if (showMore && !expanded)
                Center(
                  child: TextButton(
                    onPressed: onToggle,
                    child: const Text("더보기",
                        style:
                            TextStyle(color: AppColors.black900, fontSize: 12, fontWeight: FontWeight.w400)),
                  ),
                ),
              const SizedBox(height: 10),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.black300),
      ],
    );
  }

  Widget _buildOtherWorksSection() {
    if (authorBooks.isEmpty) return const SizedBox.shrink();
    final authors = authorBooks.keys.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 22),
          child: Text('저자의 다른 작품',
              style: TextStyle(fontSize: 14, color: AppColors.black900)),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Text('${authors.first}',
              style: const TextStyle(fontSize: 16, color: AppColors.black900)),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 240,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 22, right: 10.5),
            children: authorBooks[authors.first]!
                .map((book) => _buildBookCard(book))
                .toList(),
          ),
        ),
        if (authors.length > 1 && !showAllAuthors)
          Center(
            child: TextButton(
              onPressed: () => setState(() => showAllAuthors = true),
              child: const Text("더보기",
                  style: TextStyle(color: AppColors.black900, fontSize: 12,fontWeight: FontWeight.w400)),
            ),
          ),
        if (showAllAuthors && authors.length > 1)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: authors.skip(1).map((author) {
              final books = authorBooks[author]!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    child: Text('$author',
                        style: const TextStyle(
                            fontSize: 16, color: AppColors.black900)),
                  ),
                  SizedBox(
                    height: 240,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children:
                          books.map((book) => _buildBookCard(book)).toList(),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        const SizedBox(height: 12),
        const Divider(height: 1, color: AppColors.black300),
      ],
    );
  }

  Widget _buildBookCard(Map<String, dynamic> book) {
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = 26.0;
    final spacing = 23.0;
    final itemCountPerRow = 3;

    final totalSpacing = (itemCountPerRow - 1) * spacing;
    final availableWidth = screenWidth - (2 * horizontalPadding) - totalSpacing;
    final bookWidth = availableWidth / itemCountPerRow;
    final bookHeight = bookWidth * 1.5;

    return GestureDetector(
      onTap: () {
        final bookId = book['isbn13'] ?? book['isbn'] ?? '';
        if (bookId.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BookDetailScreen(bookId: bookId),
            ),
          );
        }
      },
      child: Container(
        width: bookWidth,
        margin: const EdgeInsets.only(right: 23),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: bookWidth,
              height: bookHeight,
              child: BookFrame(imageUrl: book['image'] ?? ''),
            ),
            const SizedBox(height: 8),
            Text(
              book['title'] ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: AppColors.black500),
            ),
          ],
        ),
      ),
    );
  }

  String cleanToc(String? rawToc) {
    if (rawToc == null || rawToc.trim().isEmpty) return '';

    return rawToc
        .replaceAll(RegExp(r'<[^>]+>'), '') // 나머지 HTML 태그 제거
        .trim();
  }

  String cleanDescription(String? rawDescription) {
    if (rawDescription == null || rawDescription.trim().isEmpty) return '';
    return _unescape.convert(rawDescription).trim();
  }

  void _truncateToFitWithButton() {
    final fullText = book?['reviewContent'] ?? '';
    final textStyle = const TextStyle(fontSize: 14, color: AppColors.black500, height: 2, letterSpacing: -0.32);

    // "더보기"가 붙은 텍스트로 줄 수 계산
    final testText = fullText + '... 더보기';
    final testSpan = TextSpan(text: testText, style: textStyle);
    final testTp = TextPainter(
      text: testSpan,
      textDirection: TextDirection.ltr,
      maxLines: null, // 줄 수 제한 없이 전체 줄 수 계산
    );
    testTp.layout(maxWidth: MediaQuery.of(context).size.width - 56);

    // 실제 줄 수 계산
    final lineCount = testTp.computeLineMetrics().length;

    if (lineCount <= 6) {
      setState(() {
        truncatedText = fullText;
        shouldShowMoreButton = false;
      });
      return;
    }

    // 6줄에 맞게 자르기
    int endIndex = fullText.length;
    while (endIndex > 0) {
      final cutText = fullText.substring(0, endIndex) + '... 더보기';
      final cutSpan = TextSpan(text: cutText, style: textStyle);
      final cutTp = TextPainter(
        text: cutSpan,
        textDirection: TextDirection.ltr,
        maxLines: null,
      );
      cutTp.layout(maxWidth: MediaQuery.of(context).size.width - 56);

      if (cutTp.computeLineMetrics().length <= 6) break;
      endIndex--;
    }

    setState(() {
      truncatedText = fullText.substring(0, endIndex) + '... ';
      shouldShowMoreButton = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (book == null) {
      return Scaffold(
          body: Center(child: Text(errorMessage ?? '책 정보를 불러오지 못했어요.')));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          '책 정보',
          style: TextStyle(
            fontSize: 16,
            color: AppColors.black900,
            fontWeight: FontWeight.w500,
          ),
        ),
        leading: IconButton(
          icon: SvgPicture.asset('assets/back_arrow.svg'),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            lifebookUsers.isEmpty? const SizedBox(height:0): const SizedBox(height: 37),
            _buildLifeBookSection(),
            lifebookUsers.length > 3
                ? const SizedBox(height: 37)
                : const SizedBox(height: 0),
            _buildExpandableText(
              "책 정보",
              cleanDescription(book?['description']),
              5,
              showFullDescription,
                  () {
                setState(() => showFullDescription = true);
              },
            ),
            book?['toc'] == ''
                ? const SizedBox(height: 37)
                : const SizedBox.shrink(),
            _buildExpandableText(
              "목차",
              cleanToc(book?['toc']),
              7,
              showFullToc,
                  () => setState(() => showFullToc = true),
            ),
            const SizedBox(height: 37),
            _buildOtherWorksSection(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
