import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:logue/core/themes/app_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logue/data/datasources/user_book_api.dart';
import 'package:logue/domain/usecases/get_user_books.dart';
import 'package:logue/core/widgets/book/user_book_grid.dart';
import 'package:logue/core/widgets/book/book_frame.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final client = Supabase.instance.client;
  Map<String, dynamic>? profile;
  late final RealtimeChannel _channel;
  late final GetUserBooks _getUserBooks;
  bool _showFullBio = false;

  @override
  void initState() {
    super.initState();
    _getUserBooks = GetUserBooks(UserBookApi(client));
    _fetchProfile();
    _subscribeToProfileUpdates();

    // 로그인 후 상태 반영
    client.auth.onAuthStateChange.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _channel.unsubscribe();
    super.dispose();
  }

  Future<void> _fetchProfile() async {
    final user = client.auth.currentUser;
    if (user == null) return;

    final data = await client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    setState(() {
      profile = data;
    });
  }

  void _subscribeToProfileUpdates() {
    final user = client.auth.currentUser;
    if (user == null) return;

    _channel = client.channel('public:profiles')
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
            setState(() {
              profile = newProfile as Map<String, dynamic>;
            });
          }
        },
      )
      ..subscribe();
  }

  Future<List<Map<String, dynamic>>> _loadBooks() async {
    final user = client.auth.currentUser;
    if (user == null) {
      return [];
    }


    return await _getUserBooks(user.id);
  }


  @override
  Widget build(BuildContext context) {
    if (profile == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final avatarUrl = profile?['avatar_url'] ?? 'basic';
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(90), // Adjusted height
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7), // ✅ 여백 통일
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
                Text(
                  profile?['username'] ?? '사용자',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                IconButton(
                  icon: SvgPicture.asset('assets/edit_icon.svg'),
                  onPressed: () {
                    setState(() => _showFullBio = false);
                    Navigator.pushNamed(context, '/profile_edit');
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 21),
          child: Column(
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
                    width: 71, // 원하는 크기
                    height: 71,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.black100, // 테두리 색상
                        width: 1, // 테두리 두께
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 70,
                      backgroundImage: avatarUrl == 'basic'
                          ? null
                          : NetworkImage(avatarUrl),
                      child: avatarUrl == 'basic'
                          ? Image.asset(
                        'assets/basic_avatar.png',
                        width: 70,
                        height: 70,)
                          : null,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  _buildCount("팔로워", profile?['followers'] ?? 0),
                  const SizedBox(width: 24),
                  _buildCount("팔로잉", profile?['followings'] ?? 0),
                  const SizedBox(width: 24),
                  _buildCount("방문자", profile?['visitors'] ?? 0),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: _outlinedStyle(context),
                      onPressed: () => Navigator.pushNamed(context, '/add_book_screen'),
                      child: const Text("책 추가 +"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      style: _outlinedStyle(context),
                      onPressed: () {},
                      child: const Text("프로필 공유"),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _loadBooks(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(child: Text('저장된 책이 없습니다.'));
                    }

                    final sortedBooks = List<Map<String, dynamic>>.from(snapshot.data!)
                      ..sort((a, b) => (a['order_index'] as int).compareTo(b['order_index'] as int));

                    return UserBookGrid(books: sortedBooks);
                  },
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Wrap(
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: () {}, // 노션 링크
                      child: const Text(
                        '개인정보 처리방침',
                        style: TextStyle(fontSize: 12, color: AppColors.black500),
                      ),
                    ),
                    const Text('|', style: TextStyle(color: AppColors.black500, fontSize: 12, height: 4)),
                    TextButton(
                      onPressed: () {}, // 노션 링크
                      child: const Text(
                        '이용약관',
                        style: TextStyle(fontSize: 12, color: AppColors.black500),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
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
                  tp.getPositionForOffset(
                    Offset(constraints.maxWidth, 28 * 2),
                  ).offset,
                ) + '...',
                style: const TextStyle(fontSize: 12, color: AppColors.black900),
              ),
              if (showMore)
                WidgetSpan(
                  child: GestureDetector(
                    onTap: () => setState(() => _showFullBio = true),
                    child: const Text(
                      ' 더보기',
                      style: TextStyle(fontSize: 12, color: AppColors.black900),
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(count.toString(), style: Theme.of(context).textTheme.bodySmall),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  ButtonStyle _outlinedStyle(BuildContext context) {
    return OutlinedButton.styleFrom(
      foregroundColor: AppColors.black500,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(5),
      ),
      textStyle: Theme.of(context).textTheme.bodySmall,
    );
  }
}