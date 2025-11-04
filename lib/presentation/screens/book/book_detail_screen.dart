import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:my_logue/presentation/screens/book/life_book_users_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/widgets/book/book_frame.dart';

import '../../../core/widgets/follow/follow_user_tile.dart';
import 'package:my_logue/data/datasources/aladin_book_api.dart';
import 'package:my_logue/data/datasources/user_book_api.dart';
import '../../../data/models/book_model.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/providers/follow_state_provider.dart';
import '../profile/other_profile_screen.dart';
import 'package:html_unescape/html_unescape.dart';

class BookDetailScreen extends ConsumerStatefulWidget {
  final String? bookId;
  final BookModel? bookModel; // ✅ BookModel 옵션 추가

  const BookDetailScreen({super.key, this.bookId, this.bookModel});

  @override
  ConsumerState<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends ConsumerState<BookDetailScreen> {
  String? currentUserId;
  Map<String, dynamic>? book;
  List<dynamic> lifebookUsers = [];
  String? errorMessage;
  bool isLoading = true;
  bool isLoadingLifebookUsers = true; // ✅ 인생책 친구 목록 로딩 상태
  bool showFullDescription = false;
  bool showFullToc = false;
  bool showAllAuthors = false;
  Map<String, List<Map<String, dynamic>>> authorBooks = {};
  final HtmlUnescape _unescape = HtmlUnescape();

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
      String? bookIdOrIsbn;
      
      // ✅ bookModel이 있으면 ISBN 사용, 없으면 widget.bookId 사용
      if (widget.bookModel != null) {
        bookIdOrIsbn = widget.bookModel!.isbn;
      } else if (widget.bookId != null) {
        bookIdOrIsbn = widget.bookId;
      } else {
        return; // 둘 다 없으면 리턴
      }
      
      final body = {
        if (bookIdOrIsbn!.length == 36) 'book_id': bookIdOrIsbn,
        if (bookIdOrIsbn.length != 36) 'isbn': bookIdOrIsbn,
      };

      // TODO: edge function에서 is_archived = false 조건 추가 필요
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
        lifebookUsers = _getSortedUsers(uniqueUsers);
        isLoadingLifebookUsers = false; // ✅ 로딩 완료
      });
    } catch (e) {
      debugPrint('❌ 인생책 유저 조회 실패: $e');
      if (mounted) {
        setState(() {
          isLoadingLifebookUsers = false; // ✅ 에러 시에도 로딩 완료
        });
      }
    }
  }

  Future<void> _fetchBookOnly() async {
    // ✅ bookModel이 있으면 즉시 사용
    if (widget.bookModel != null) {
      final bookModel = widget.bookModel!;
      final authors = _extractAuthors(bookModel.author);
      
      setState(() {
        book = bookModel.toBookMap();
        errorMessage = null;
        isLoading = false;
      });
      
      // ✅ 인생책 친구 목록도 가져오기
      await _fetchLifebookUsersOnly();
      await _fetchOtherBooks(authors);
      return;
    }
    
    // ✅ bookModel이 없으면 기존 방식으로 네트워크 요청
    try {
      final body = {
        if (widget.bookId!.length == 36) 'book_id': widget.bookId,
        if (widget.bookId!.length != 36) 'isbn': widget.bookId,
      };

      // TODO: edge function에서 is_archived = false 조건 추가 필요
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
        isLoadingLifebookUsers = false; // ✅ 기존 방식에서도 로딩 완료
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
    final userBookApi = UserBookApi(Supabase.instance.client);
    Map<String, List<Map<String, dynamic>>> result = {};
    
    for (final author in authors) {
      try {
        // 1️⃣ 내 DB에서 저자로 책 검색
        final dbResults = await userBookApi.searchBooksFromDB(author);
        
        // 결과 합치기 및 중복 제거
        final allBooks = <Map<String, dynamic>>[];
        final seenIsbns = <String>{};
        final seenTitles = <String>{};
        
        // DB 결과 먼저 추가
        for (final dbBook in dbResults) {
          final isbn = dbBook['isbn']?.toString() ?? '';
          final title = dbBook['title']?.toString().toLowerCase() ?? '';
          
          if (isbn.isNotEmpty && !seenIsbns.contains(isbn)) {
            allBooks.add(dbBook);
            seenIsbns.add(isbn);
          } else if (isbn.isEmpty && !seenTitles.contains(title)) {
            allBooks.add(dbBook);
            seenTitles.add(title);
          }
        }
        
        // 2️⃣ 알라딘 API에서 저자로 책 검색 (실패해도 DB 결과는 표시)
        try {
          final aladinResults = await api.searchBooksByAuthor(author);
          
          // 알라딘 결과 추가 (DB에 이미 있는 ISBN과 겹치는 것은 제외)
          // search_screen과 동일한 로직: DB 결과의 ISBN과 겹치는 알라딘 책은 검색 결과에서 제외
          for (final aladinBook in aladinResults) {
            // 알라딘 API는 isbn13을 반환하므로, isbn13 우선으로 ISBN 가져오기
            final isbn = (aladinBook['isbn13'] ?? aladinBook['isbn'] ?? '').toString();
            final title = aladinBook['title']?.toString().toLowerCase() ?? '';
            
            // DB에 이미 있는 ISBN과 겹치지 않는 경우만 추가
            if (isbn.isNotEmpty && !seenIsbns.contains(isbn)) {
              allBooks.add(aladinBook);
              seenIsbns.add(isbn);
            } else if (isbn.isEmpty && !seenTitles.contains(title)) {
              allBooks.add(aladinBook);
              seenTitles.add(title);
            }
          }
        } catch (e) {
          debugPrint('❌ 알라딘 API 실패 (저자: $author): $e');
          // 알라딘 API 실패해도 DB 결과는 계속 사용
        }
        
        if (allBooks.isNotEmpty) {
          result[author] = allBooks;
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
    // ✅ 로딩 중이면 로딩 인디케이터 표시
    if (isLoadingLifebookUsers) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 22),
            child: Text('이 책을 인생 책으로 설정한 친구',
                style: TextStyle(color: AppColors.black900, fontSize: 15)),
          ),
          const SizedBox(height: 12),
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
              ),
            ),
          ),
        ],
      );
    }
    
    // ✅ 로딩 완료 후 친구가 없으면 빈 섹션
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
              const Text('이 책을 인생 책으로 설정한 친구',
                  style: TextStyle(color: AppColors.black900, fontSize: 15)),
              Text('${lifebookUsers.length}명',
                  style:
                      const TextStyle(fontSize: 15, color: AppColors.black500)),
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

    // 실제 화면에서의 줄 수를 정확히 계산
    final textStyle = const TextStyle(fontSize: 14, color: AppColors.black500, height: 2);
    final screenWidth = MediaQuery.of(context).size.width;
    final availableWidth = screenWidth - 44; // 좌우 패딩 22 * 2

    final textSpan = TextSpan(text: content, style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      maxLines: null,
    );
    textPainter.layout(maxWidth: availableWidth);
    
    final actualLineCount = textPainter.computeLineMetrics().length;
    final showMore = actualLineCount > maxLines;

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
                      const TextStyle(color: AppColors.black900, fontSize: 15)),
              const SizedBox(height: 12),
              Text(
                content,
                style: textStyle,
                maxLines: expanded ? null : maxLines,
                overflow: expanded ? null : TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        SizedBox(
          height: 50,
          child: Column(
            children: [
              if (showMore && !expanded)
                Center(
                  child: TextButton(
                    onPressed: onToggle,
                    child: const Text("더보기",
                        style:
                        TextStyle(color: AppColors.black900, fontSize: 12, fontWeight: FontWeight.w400)),
                  ),
                ),
              showMore && !expanded ?
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

  Widget _buildOtherWorksSection() {
    if (authorBooks.isEmpty) return const SizedBox.shrink();
    final authors = authorBooks.keys.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 22),
          child: Text('저자의 다른 작품',
              style: TextStyle(fontSize: 15, color: AppColors.black900)),
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
