import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:logue/core/themes/app_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logue/data/datasources/user_book_api.dart';
import 'package:logue/domain/usecases/get_user_books.dart';
import 'package:logue/core/widgets/book/user_book_grid.dart';
import 'package:logue/data/utils/fetch_profile.dart';
import 'package:logue/presentation/screens/profile/profile_edit/profile_edit_screen.dart';

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
    result.sort((a, b) => (a['order_index'] as int).compareTo(b['order_index'] as int));
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
          data.sort((a, b) => (a['order_index'] as int).compareTo(b['order_index'] as int));
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
                    Navigator.pushNamed(context, '/notification');
                    setState(() => _showFullBio = false);
                  },
                ),
                Text(profile?['username'] ?? '사용자', style: Theme.of(context).textTheme.titleMedium),
                IconButton(
                  icon: SvgPicture.asset('assets/edit_icon.svg'),
                  onPressed: () {
                    setState(() => _showFullBio = false);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProfileEditScreen(initialProfile: profile!),
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
                  padding: const EdgeInsets.symmetric(horizontal: 21, vertical: 24),
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
                        if (_isScrollable)
                          Center(child: _buildPolicyLinks()), // 스크롤 있음
                      ] else ...[
                        const SizedBox(height: 95),
                        Center(
                          child: Column(
                            children: [
                              const Text(
                                '인생 책을 소개해보세요.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12, color: AppColors.black500),
                              ),
                              const SizedBox(height: 5),
                              TextButton(
                                onPressed: () => Navigator.pushNamed(context, '/add_book_screen'),
                                child: const Text("책 추가 +", style: TextStyle(fontSize: 12, color: AppColors.black900)),
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
            if (!_isScrollable)
              Positioned(
                bottom: 16,
                left: 0,
                right: 0,
                child: Center(child: _buildPolicyLinks()), // 스크롤 없음
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
                  Text(profile?['name'] ?? '', style: Theme.of(context).textTheme.bodyLarge),
                  Text(profile?['job'] ?? '', style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 10),
                  _buildBio(context),
                  const SizedBox(height: 20),
                ],
              ),
            ),
            Container(
              width: 71,
              height: 71,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.black100, width: 1),
              ),
              child: CircleAvatar(
                radius: 70,
                backgroundImage: avatarUrl == 'basic' ? null : NetworkImage(avatarUrl),
                child: avatarUrl == 'basic'
                    ? Image.asset('assets/basic_avatar.png', width: 70, height: 70)
                    : null,
              ),
            ),
          ],
        ),
        Row(
          children: [
            _buildCount("팔로워", profile?['followers'] ?? 0),
            const SizedBox(width: 24),
            _buildCount("팔로잉", profile?['following'] ?? 0),
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
              await Navigator.pushNamed(context, '/add_book_screen');
              _loadBooks();
            },
            child: const Text("책 추가 +", style: TextStyle(color: AppColors.black900, fontSize: 12)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton(
            style: _outlinedStyle(context),
            onPressed: () {},
            child: const Text("프로필 공유", style: TextStyle(color: AppColors.black900, fontSize: 12)),
          ),
        ),
      ],
    );
  }

  Widget _buildBookGrid() {
    return UserBookGrid(
      books: books,
      onTap: (book) {
        final bookId = book['id'] as String;
        Navigator.pushNamed(context, '/my_post_screen', arguments: {'bookId': bookId});
      },
    );
  }

  Widget _buildPolicyLinks() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      children: [
        TextButton(
          onPressed: () {},
          child: const Text('개인정보 처리방침', style: TextStyle(fontSize: 12, color: AppColors.black500)),
        ),
        const Text('|', style: TextStyle(color: AppColors.black500, fontSize: 12, height: 4)),
        TextButton(
          onPressed: () {},
          child: const Text('이용약관', style: TextStyle(fontSize: 12, color: AppColors.black500)),
        ),
      ],
    );
  }

  Widget _buildBio(BuildContext context) {
    final bio = profile?['bio'] ?? '';
    final showMore = !_showFullBio && bio.length > 40;

    return LayoutBuilder(
      builder: (context, constraints) {
        final textSpan = TextSpan(
          text: bio,
          style: const TextStyle(fontSize: 12, color: AppColors.black900),
        );

        final tp = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
          maxLines: _showFullBio ? null : 2,
          ellipsis: showMore ? '...' : null,
        )..layout(maxWidth: constraints.maxWidth);

        final isOverflowing = tp.didExceedMaxLines;

        return RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: _showFullBio || !isOverflowing
                    ? bio
                    : bio.substring(
                  0,
                  tp.getPositionForOffset(Offset(constraints.maxWidth, 28 * 2)).offset,
                ) + '...',
                style: const TextStyle(fontSize: 12, color: AppColors.black900),
              ),
              if (showMore)
                WidgetSpan(
                  child: GestureDetector(
                    onTap: () => setState(() => _showFullBio = true),
                    child: const Text(' 더보기', style: TextStyle(fontSize: 12, color: AppColors.black900)),
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
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.black500)),
        Text('$count', style: const TextStyle(fontSize: 12, color: AppColors.black500)),
      ],
    );
  }

  ButtonStyle _outlinedStyle(BuildContext context) {
    return OutlinedButton.styleFrom(
      foregroundColor: AppColors.black500,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      textStyle: Theme.of(context).textTheme.bodySmall,
    );
  }
}
