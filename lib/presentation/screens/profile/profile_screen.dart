import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:logue/core/themes/app_colors.dart';
import 'package:logue/presentation/screens/profile/add_book/add_book_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logue/data/datasources/user_book_api.dart';
import 'package:logue/domain/usecases/get_user_books.dart';
import 'package:logue/core/widgets/book/user_book_grid.dart';
import 'package:logue/data/utils/fetch_profile.dart';
import 'package:logue/presentation/screens/profile/profile_edit/profile_edit_screen.dart';
import 'dart:ui'; // 맨 위에 추가

import '../../../domain/entities/follow_list_type.dart';
import '../main_navigation_screen.dart';
import '../post/my_post_screen.dart';
import 'follow/follow_tab_screen.dart';
import 'follow_list_screen.dart';
import 'notification_screen.dart';

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
    result.sort(
        (a, b) => (a['order_index'] as int).compareTo(b['order_index'] as int));
    setState(() => books = result);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkIfScrollable();
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
        preferredSize: const Size.fromHeight(90),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: SvgPicture.asset('assets/bell_icon.svg'),
                  onPressed: () {
                    Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute(builder: (_) => const NotificationScreen()),
                    );
                    setState(() => _showFullBio = false);
                  },
                ),
                Text(profile?['username'] ?? '사용자',
                    style: Theme.of(context).textTheme.titleMedium),
                IconButton(
                  icon: SvgPicture.asset('assets/edit_icon.svg'),
                  onPressed: () {
                    setState(() => _showFullBio = false);
                    Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            ProfileEditScreen(initialProfile: profile!),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 21, vertical: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildProfileHeader(),
                      const SizedBox(height: 24),
                      _buildActionButtons(),
                      const SizedBox(height: 24),
                      if (books.isNotEmpty) ...[
                        _buildBookGrid(),
                        const SizedBox(height: 32),
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
                                    onPressed: () {
                                      Navigator.of(context, rootNavigator: true).push(
                                        MaterialPageRoute(builder: (_) => const AddBookScreen()),
                                      );
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
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(profile?['name'] ?? '',
                      style: Theme.of(context).textTheme.bodyLarge),
                  Text(profile?['job'] ?? '',
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 10),
                  _buildBio(context),
                  const SizedBox(height: 20),
                ],
              ),
            ),
            GestureDetector(
              onLongPress: () => _showZoomedAvatar(avatarUrl),
              child: Hero(
                tag: 'profile-avatar',
                child: Container(
                  width: 71,
                  height: 71,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.black100, width: 1),
                  ),
                  child: CircleAvatar(
                    radius: 70,
                    backgroundImage:
                    avatarUrl == 'basic' ? null : NetworkImage(avatarUrl),
                    child: avatarUrl == 'basic'
                        ? Image.asset('assets/basic_avatar.png',
                        width: 70, height: 70)
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
            const SizedBox(width: 24),
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
            const SizedBox(width: 24),
            _buildCount("방문자", profile?['visitors'] ?? 0),
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
            onPressed: () {},
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

    final textStyle = const TextStyle(fontSize: 12, color: AppColors.black900);
    final moreText = ' 더보기';

    return LayoutBuilder(
      builder: (context, constraints) {
        if (_showFullBio) {
          return Text(bio, style: textStyle);
        }

        // 전체 텍스트를 먼저 계산
        final fullTextSpan = TextSpan(text: bio, style: textStyle);
        final fullPainter = TextPainter(
          text: fullTextSpan,
          maxLines: 2,
          ellipsis: '',
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: constraints.maxWidth);

        // 2줄 초과가 아니면 전체 텍스트만 보여줌
        if (!fullPainter.didExceedMaxLines) {
          return Text(bio, style: textStyle);
        }

        // "더보기" 길이 측정
        final morePainter = TextPainter(
          text: TextSpan(text: moreText, style: textStyle),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: constraints.maxWidth);
        final moreWidth = morePainter.width;

        // 줄어든 공간만큼 bio를 자름
        String trimmed = bio;
        final textPainter = TextPainter(
          text: TextSpan(text: trimmed, style: textStyle),
          maxLines: 2,
          textDirection: TextDirection.ltr,
        );

        while (trimmed.isNotEmpty) {
          final candidate = trimmed + '...';
          textPainter.text = TextSpan(text: candidate + moreText, style: textStyle);
          textPainter.layout(maxWidth: constraints.maxWidth);

          if (!textPainter.didExceedMaxLines) {
            break;
          }

          trimmed = trimmed.substring(0, trimmed.length - 1);
        }

        return RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: trimmed.trimRight() + '...',
                style: textStyle,
              ),
              WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: GestureDetector(
                  onTap: () => setState(() => _showFullBio = true),
                  child: Text(
                    moreText,
                    style: textStyle.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCount(String label, int count) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(fontSize: 12, color: AppColors.black500)),
        Text('$count',
            style: const TextStyle(fontSize: 12, color: AppColors.black500)),
      ],
    );
  }

  ButtonStyle _outlinedStyle(BuildContext context) {
    return OutlinedButton.styleFrom(
      foregroundColor: AppColors.black900,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      textStyle: Theme.of(context).textTheme.bodySmall,
    );
  }
}
