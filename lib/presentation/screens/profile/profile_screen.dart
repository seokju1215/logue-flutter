import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:logue/core/themes/app_colors.dart';
import 'package:logue/presentation/screens/profile/add_book/add_book_screen.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logue/data/datasources/user_book_api.dart';
import 'package:logue/domain/usecases/get_user_books.dart';
import 'package:logue/core/widgets/book/user_book_grid.dart';
import 'package:logue/data/utils/fetch_profile.dart';
import 'package:logue/presentation/screens/profile/profile_edit/profile_edit_screen.dart';
import 'dart:ui'; // 맨 위에 추가

import '../../../core/widgets/common/custom_app_bar.dart';
import '../../../domain/entities/follow_list_type.dart';
import '../main_navigation_screen.dart';
import '../post/my_post_screen.dart';
import 'follow/follow_tab_screen.dart';
import 'follow_list_screen.dart';
import 'notification_screen.dart';
import 'package:flutter/gestures.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final client = Supabase.instance.client;
  final ScrollController _scrollController = ScrollController();
  bool _isScrollable = false;

  Map<String, dynamic>? profile;
  late final RealtimeChannel _profileChannel;
  late final RealtimeChannel _bookChannel;
  late final GetUserBooks _getUserBooks;
  bool _showFullBio = false;
  List<Map<String, dynamic>> books = [];

  @override
  void initState() {
    super.initState();
    _getUserBooks = GetUserBooks(UserBookApi(client));
    _fetchProfile();
    _loadBooks();
    _subscribeToProfileUpdates();
    _subscribeToBookUpdates();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkIfScrollable();
    });

    client.auth.onAuthStateChange.listen((_) {
      if (mounted) setState(() {});
    });
  }

  void _checkIfScrollable() {
    if (!_scrollController.hasClients) return;
    final isNowScrollable = _scrollController.position.maxScrollExtent > 0;
    if (mounted && isNowScrollable != _isScrollable) {
      setState(() => _isScrollable = isNowScrollable);
    }
  }
  String _truncateTextToFit(
      String text,
      TextStyle style,
      double maxWidth,
      int maxLines,
      String trailingText,
      ) {
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      maxLines: maxLines,
    );

    String current = text;
    int min = 0;
    int max = text.length;
    int mid = 0;

    while (min < max) {
      mid = (min + max) ~/ 2;
      final testStr = text.substring(0, mid);
      textPainter.text = TextSpan(
        text: testStr + trailingText,
        style: style,
      );
      textPainter.layout(maxWidth: maxWidth);
      if (textPainter.didExceedMaxLines) {
        max = mid;
      } else {
        min = mid + 1;
      }
    }

    return text.substring(0, max - 1); // 최대 들어가는 위치까지 자름
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _profileChannel.unsubscribe();
    _bookChannel.unsubscribe();
    super.dispose();
  }

  Future<void> _fetchProfile() async {
    final data = await fetchCurrentUserProfile();
    setState(() => profile = data);
  }

  Future<void> _loadBooks() async {
    final user = client.auth.currentUser;
    if (user == null) return;

    final result = await _getUserBooks(user.id);
    result.sort((a, b) => (a['order_index'] as int).compareTo(b['order_index'] as int));

    setState(() {
      books = result;
      // ✅ 스크롤 가능 여부 즉시 반영
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkIfScrollable();
      });
    });
  }

  void _subscribeToBookUpdates() {
    final user = client.auth.currentUser;
    if (user == null) return;

    _bookChannel = client.channel('public:user_books')
      ..on(
        RealtimeListenTypes.postgresChanges,
        ChannelFilter(
          event: '*',
          schema: 'public',
          table: 'user_books',
          filter: 'user_id=eq.${user.id}',
        ),
        (payload, [ref]) async {
          if (!mounted) return;
          final data = await _getUserBooks(user.id);
          data.sort((a, b) =>
              (a['order_index'] as int).compareTo(b['order_index'] as int));
          setState(() => books = data);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _checkIfScrollable();
          });
        },
      )
      ..subscribe();
  }

  void _subscribeToProfileUpdates() {
    final user = client.auth.currentUser;
    if (user == null) return;

    _profileChannel = client.channel('public:profiles')
      ..on(
        RealtimeListenTypes.postgresChanges,
        ChannelFilter(
          event: 'UPDATE',
          schema: 'public',
          table: 'profiles',
          filter: 'id=eq.${user.id}',
        ),
        (payload, [ref]) {
          final newProfile = payload['new'];
          if (mounted && newProfile != null) {
            setState(() => profile = newProfile as Map<String, dynamic>);
          }
        },
      )
      ..subscribe();
  }

  @override
  Widget build(BuildContext context) {
    if (profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(40),
        child: CustomAppBar(
          title: profile?['username'] ?? '사용자',
          leadingIconPath: 'assets/bell_icon.svg',
          onLeadingTap: () {
            Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute(builder: (_) => const NotificationScreen()),
            );
            setState(() => _showFullBio = false);
          },
          trailingIconPath: 'assets/edit_icon.svg',
          onTrailingTap: () {
            setState(() => _showFullBio = false);
            Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute(
                builder: (_) => ProfileEditScreen(initialProfile: profile!),
              ),
            );
          },
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: NotificationListener<ScrollNotification>(
                onNotification: (_) {
                  _checkIfScrollable();
                  return false;
                },
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: EdgeInsets.zero,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 25),
                        child: _buildProfileHeader(),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                        child: _buildActionButtons(),
                      ),
                      const SizedBox(height: 10),
                      if (books.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 0, horizontal:26),
                          child: _buildBookGrid(),
                        ),
                        const SizedBox(height: 20),
                      ] else ...[
                        const SizedBox(height: 95),
                        Center(
                          child: Column(
                            children: [
                              const Text(
                                '인생 책을 소개해보세요.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 12, color: AppColors.black500),
                              ),
                              const SizedBox(height: 5),
                              Builder(
                                builder: (context) {
                                  return TextButton(
                                    onPressed: () async {
                                      final result = await Navigator.of(context, rootNavigator: true).push(
                                        MaterialPageRoute(builder: (_) => const AddBookScreen()),
                                      );
                                      if (result == true) {
                                        _loadBooks(); // ✅ 책 목록 다시 불러오기
                                      }
                                    },
                                    child: const Text(
                                      "책 추가 +",
                                      style: TextStyle(fontSize: 12, color: AppColors.black900),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 90),
                      ]
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    final avatarUrl = profile?['avatar_url'] ?? 'basic';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(profile?['name'] ?? '',
                      style: TextStyle(fontSize: 20, color: AppColors.black900)),
                  const SizedBox(height: 6),
                  Text(profile?['job'] ?? '',
                      style: TextStyle(fontSize: 14, color: AppColors.black500)),
                  const SizedBox(height: 9),
                  _buildBio(context),
                  const SizedBox(height: 9),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => _showZoomedAvatar(avatarUrl),
              child: Hero(
                tag: 'profile-avatar',
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.black100, width: 1),
                  ),
                  child: CircleAvatar(
                    radius: 81,
                    backgroundImage:
                    avatarUrl == 'basic' ? null : NetworkImage(avatarUrl),
                    child: avatarUrl == 'basic'
                        ? Image.asset('assets/basic_avatar.png',
                        width: 80, height: 80)
                        : null,
                  ),
                ),
              ),
            ),
          ],
        ),
        Row(
          children: [
            GestureDetector(
              onTap: () {
                final userId = profile?['id'];
                final username = profile?['username'];
                final followerCount = profile?['followers'] ?? 0;
                final followingCount = profile?['following'] ?? 0;
                final currentUserId =
                    Supabase.instance.client.auth.currentUser?.id;
                final isMyProfile = currentUserId == userId;
                if (userId != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FollowTabScreen(
                        userId: userId,
                        initialTabIndex: 0,
                        username: username,
                        followerCount: followerCount,
                        followingCount: followingCount,
                        isMyProfile: isMyProfile,
                      ), // 팔로워 탭
                    ),
                  );
                }
              },
              child: _buildCount("팔로워", profile?['followers'] ?? 0),
            ),
            const SizedBox(width: 27),
            GestureDetector(
              onTap: () {
                final userId = profile?['id'];
                final username = profile?['username'];
                final followerCount = profile?['followers'] ?? 0;
                final followingCount = profile?['following'] ?? 0;
                final currentUserId =
                    Supabase.instance.client.auth.currentUser?.id;
                final isMyProfile = currentUserId == userId;
                if (userId != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FollowTabScreen(
                        userId: userId,
                        initialTabIndex: 1,
                        // or 1
                        username: username,
                        followerCount: followerCount,
                        followingCount: followingCount,
                        isMyProfile: isMyProfile,
                      ), // 팔로잉 탭
                    ),
                  );
                }
              },
              child: _buildCount("팔로잉", profile?['following'] ?? 0),
            ),
            const SizedBox(width: 27),
            _buildCount("방문자", profile?['visitors'] ?? 0, isTappable: false),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            style: _outlinedStyle(context),
            onPressed: () async {
              setState(() => _showFullBio = false);
              final result = await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AddBookScreen()),
              );
              if (result == true) {
                _loadBooks(); // ✅ 변경사항 반영
              }
            },
            child: const Text("책 추가 +",
                style: TextStyle(color: AppColors.black900, fontSize: 12)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton(
            style: _outlinedStyle(context),
            onPressed: () {
              final profileLink = 'https://www.logue.it.kr/u/${profile?['username']}';
              if (profileLink != null && profileLink.isNotEmpty) {
                Share.share(profileLink);
              }
            },
            child: const Text("프로필 공유",
                style: TextStyle(color: AppColors.black900, fontSize: 12)),
          ),
        ),
      ],
    );
  }

  Widget _buildBookGrid() {
    return UserBookGrid(
      books: books,
      onTap: (book) async {
        print("bookId : ${book['id']}");
        final result = await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MyBookPostScreen(
              bookId: book['book_id'] as String,
              userBookId: book['id'] as String,
              // ✅ 이걸 꼭 넘겨야 정확히 이동 가능!
            ),
          ),
        );
        if (result == true) {
          _loadBooks();
        }
      },
    );
  }
  void _showZoomedAvatar(String avatarUrl) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Stack(
          children: [
            // 🔹 배경 블러 처리
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                color: Colors.black.withOpacity(0.4), // 블러 + 반투명 배경
              ),
            ),
            Center(
              child: Hero(
                tag: 'profile-avatar',
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    image: DecorationImage(
                      fit: BoxFit.cover,
                      image: avatarUrl == 'basic'
                          ? const AssetImage('assets/basic_avatar.png')
                      as ImageProvider
                          : NetworkImage(avatarUrl),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildBio(BuildContext context) {
    final bio = profile?['bio'] ?? '';
    if (bio.isEmpty) return const SizedBox();

    const maxLines = 2;
    const maxWidth = 200.0;
    const textStyle = TextStyle(
      fontSize: 12,
      color: AppColors.black900,
      fontFamily: 'Inter',
      fontWeight: FontWeight.w400,
      height: 1.2,
    );

    if (_showFullBio) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: maxWidth, maxHeight: 150),
        child: SingleChildScrollView(
          child: Text(bio, style: textStyle),
        ),
      );
    }

    // bio가 overflow 되는지 판단
    final tp = TextPainter(
      text: TextSpan(text: bio, style: textStyle),
      maxLines: maxLines,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);

    final isOverflow = tp.didExceedMaxLines;

    // ...더보기를 텍스트 마지막 줄에 자연스럽게 붙이기
    if (!isOverflow) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: maxWidth),
        child: Text(
          bio,
          style: textStyle,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
        ),
      );
    }

    // 텍스트가 잘리는 경우 → RichText로 ...더보기 붙이기
    final truncatedText = _truncateTextToFit(bio, textStyle, maxWidth, maxLines, "... 더보기");

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: maxWidth),
      child: GestureDetector(
        onTap: () {
          setState(() => _showFullBio = true);
        },
        child: RichText(
          text: TextSpan(
            text: truncatedText,
            style: textStyle,
            children: [
              const TextSpan(
                text: '... 더보기',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.black900,
                ),
              ),
            ],
          ),
          maxLines: maxLines,
          overflow: TextOverflow.clip,
        ),
      ),
    );
  }

  Widget _buildCount(String label, int count, {bool isTappable = true}) {
    final content = Column(
      children: [
        Text(label,
            style: const TextStyle(fontSize: 12, color: AppColors.black500, height: 1)),
        const SizedBox(height: 6),
        Text('$count',
            style: const TextStyle(fontSize: 12, color: AppColors.black500, height: 1)),
      ],
    );

    return isTappable
        ? MouseRegion(
      cursor: SystemMouseCursors.click,
      child: content,
    )
        : content;
  }

  ButtonStyle _outlinedStyle(BuildContext context) {
    return ButtonStyle(
      foregroundColor: MaterialStateProperty.all(AppColors.black900),
      backgroundColor: MaterialStateProperty.all(Colors.white),
      overlayColor: MaterialStateProperty.resolveWith<Color?>(
            (states) {
          if (states.contains(MaterialState.pressed)) {
            return AppColors.black100;
          }
          return null;
        },
      ),
      side: MaterialStateProperty.all(
        const BorderSide(color: AppColors.black500, width: 1),
      ),
      shape: MaterialStateProperty.all(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      padding: MaterialStateProperty.all(
        EdgeInsets.symmetric(horizontal: 9),
      ),
      minimumSize: MaterialStateProperty.all(
        const Size(0, 34), // ✅ 원하는 높이로 강제 지정
      ),
      textStyle: MaterialStateProperty.all(
        const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          height: 1.0, // ✅ 텍스트 줄 간격 없애기
        ),
      ),
    );
  }
}
