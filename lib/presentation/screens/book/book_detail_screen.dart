import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:logue/presentation/screens/book/life_book_users_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/widgets/book/book_frame.dart';
import '../../../core/widgets/common/custom_app_bar.dart';
import '../../../core/widgets/follow/follow_user_tile.dart';
import 'package:logue/data/datasources/aladin_book_api.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/repositories/follow_repository.dart';
import '../../../domain/usecases/follows/follow_user.dart';
import '../profile/other_profile_screen.dart';

class BookDetailScreen extends StatefulWidget {
  final String bookId;

  const BookDetailScreen({super.key, required this.bookId});

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen> {
  late final FollowRepository _followRepo;
  late final FollowUser _followUser;
  String? currentUserId;
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
    currentUserId = Supabase.instance.client.auth.currentUser?.id;
    _followRepo = FollowRepository(
      client: Supabase.instance.client,
      functionBaseUrl: dotenv.env['FUNCTION_BASE_URL']!,
    );
    _followUser = FollowUser(_followRepo);

    _fetchBookOnly();
  }

  Future<void> _launchAladinLink(String? url) async {
    if (url == null || url.isEmpty) return;
    final cleanedUrl = url.replaceAll('&amp;', '&');
    final uri = Uri.parse(cleanedUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _handleFollow(String userId) async {
    // 원래 상태 백업
    final originalUsers = [...lifebookUsers];

    // 먼저 optimistic하게 UI 업데이트
    final updatedUsers = lifebookUsers.map((user) {
      if (user['id'] == userId) {
        return {
          ...user,
          'is_following': true,
        };
      }
      return user;
    }).toList();

    setState(() {
      lifebookUsers = updatedUsers;
    });

    try {
      await _followUser(userId);
      // 성공 시 추가 동작이 필요하면 여기
    } catch (e) {
      // 실패 시 UI 롤백
      setState(() {
        lifebookUsers = originalUsers;
      });
      debugPrint('❌ 팔로우 실패: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('팔로우에 실패했어요. 다시 시도해 주세요.')),
      );
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
        lifebookUsers = uniqueUsers;
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

    final regex = RegExp(r'([^,(]+)\s+\(([^)]+)\)');
    final matches = regex.allMatches(authorString);

    return matches
        .where((m) {
          final role = m.group(2)?.toLowerCase() ?? '';
          return !role.contains('옮긴이') && !role.contains('엮음');
        })
        .map((m) => m.group(1)!.trim())
        .toList();
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

    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final sortedUsers = [...lifebookUsers]..sort((a, b) {
        final myId = currentUserId;
        final aId = a['id'];
        final bId = b['id'];

        // 1. 나 자신을 맨 앞으로
        if (aId == myId) return -1;
        if (bId == myId) return 1;

        // 2. 팔로우 여부 기준 정렬
        final aFollowing = (a['is_following'] ?? false) as bool;
        final bFollowing = (b['is_following'] ?? false) as bool;

        if (aFollowing && !bFollowing) return -1;
        if (!aFollowing && bFollowing) return 1;

        return 0; // 그대로
      });
    final shownUsers = sortedUsers.take(3).toList();
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
            return FollowUserTile(
              currentUserId:
                  Supabase.instance.client.auth.currentUser?.id ?? '',
              userId: user['id'],
              username: user['username'],
              name: user['name'],
              avatarUrl: user['avatar_url'] ?? 'basic',
              isFollowing: user['is_following'] ?? false,
              isMyProfile: false,
              onTapFollow: () => _handleFollow(user['id']),
              onTapProfile: () async {
                final result = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OtherProfileScreen(userId: user['id']),
                  ),
                );

                if (mounted) {
                  await _fetchLifebookUsersOnly();
                }
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
                    onPressed: () async {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LifebookUsersScreen(
                            users: lifebookUsers.cast<Map<String, dynamic>>(),
                          ),
                        ),
                      );
                      if (mounted) {
                        await _fetchLifebookUsersOnly();
                      }
                    },
                    child: const Text("더보기",
                        style:
                            TextStyle(color: AppColors.black900, fontSize: 12,fontWeight: FontWeight.w400)),
                  ),
                ),
              lifebookUsers.length>=3?
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
              const SizedBox(height : 22),
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
                                fontSize: 14, color: AppColors.black500)),
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
      appBar: CustomAppBar(
        title: '책 정보',
        leadingIconPath: 'assets/back_arrow.svg',
        onLeadingTap: () => Navigator.pop(context),
        trailingIconPath: '',
        // ❌ 안 씀
        onTrailingTap: () {}, // ❌ 안 씀
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            lifebookUsers.isEmpty? const SizedBox(height:0): const SizedBox(height: 37),
            _buildLifeBookSection(),
            lifebookUsers.length >= 3
                ? const SizedBox(height: 37)
                : const SizedBox(height: 0),
            _buildExpandableText(
                "책 정보", book?['description'], 5, showFullDescription, () {
              setState(() => showFullDescription = true);
            }),
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
