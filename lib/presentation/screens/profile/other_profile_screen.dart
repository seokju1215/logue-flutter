import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:logue/core/themes/app_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logue/data/datasources/user_book_api.dart';
import 'package:logue/domain/usecases/get_user_books.dart';
import 'package:logue/core/widgets/book/user_book_grid.dart';
import 'package:logue/data/repositories/follow_repository.dart';
import 'package:logue/domain/usecases/follows/follow_user.dart';
import 'package:logue/domain/usecases/follows/unfollow_user.dart';
import 'package:logue/domain/usecases/follows/is_following.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'follow/follow_tab_screen.dart';

class OtherProfileScreen extends StatefulWidget {
  final String userId;

  const OtherProfileScreen({Key? key, required this.userId}) : super(key: key);

  @override
  State<OtherProfileScreen> createState() => _OtherProfileScreenState();
}

class _OtherProfileScreenState extends State<OtherProfileScreen> {
  final client = Supabase.instance.client;
  final ScrollController _scrollController = ScrollController();
  late final FollowRepository _followRepo;
  late final FollowUser _followUser;
  late final UnfollowUser _unfollowUser;
  late final IsFollowing _isFollowing;
  bool _isScrollable = false;

  Map<String, dynamic>? profile;
  late final GetUserBooks _getUserBooks;
  List<Map<String, dynamic>> books = [];

  @override
  void initState() {
    super.initState();
    _followRepo = FollowRepository(
      client: client,
      functionBaseUrl: dotenv.env['FUNCTION_BASE_URL']!,
    );
    _followUser = FollowUser(_followRepo);
    _unfollowUser = UnfollowUser(_followRepo);
    _isFollowing = IsFollowing(_followRepo);
    _getUserBooks = GetUserBooks(UserBookApi(client));

    _increaseVisitors();
    _fetchProfile();
    _loadBooks();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkIfScrollable();
    });
  }

  void _checkIfScrollable() {
    if (!_scrollController.hasClients) return;
    final isNowScrollable = _scrollController.position.maxScrollExtent > 0;
    if (mounted && isNowScrollable != _isScrollable) {
      setState(() => _isScrollable = isNowScrollable);
    }
  }

  Future<void> _increaseVisitors() async {
    final currentUserId = client.auth.currentUser?.id;
    if (currentUserId == null || currentUserId == widget.userId) return;

    try {
      await Supabase.instance.client.rpc('increment_visitors', params: {
        'user_id': widget.userId, // ✅ 단순 문자열만 전달
      });
    } catch (e) {
      debugPrint('❌ 방문자 증가 실패: $e');
    }
  }

  Future<void> _fetchProfile() async {
    final data = await client
        .from('profiles')
        .select()
        .eq('id', widget.userId)
        .maybeSingle();

    final following = await _isFollowing(widget.userId);

    setState(() {
      profile = {
        ...?data,
        'isFollowing': following,
      };
    });
  }

  Future<void> _toggleFollow() async {
    if (client.auth.currentUser?.id == widget.userId) return;

    final isFollowing = profile?['isFollowing'] == true;

    try {
      if (isFollowing) {
        await _unfollowUser(widget.userId);
      } else {
        await _followUser(widget.userId);
      }
      await _fetchProfile();
    } catch (e) {
      debugPrint('❌ 팔로우 변경 실패: $e');
    }
  }

  Future<void> _loadBooks() async {
    final result = await _getUserBooks(widget.userId);
    result.sort((a, b) =>
        (a['order_index'] as int).compareTo(b['order_index'] as int));
    setState(() => books = result);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkIfScrollable();
    });
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
                  icon: const Icon(Icons.arrow_back, color: Colors.black),
                  onPressed: () => Navigator.pop(context),
                ),
                Text(profile?['username'] ?? '사용자',
                    style: Theme
                        .of(context)
                        .textTheme
                        .titleMedium),
                IconButton(
                  icon: SvgPicture.asset('assets/share_icon.svg'),
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 21, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProfileHeader(),
              const SizedBox(height: 24),
              if (books.isNotEmpty)
                _buildBookGrid()
              else
                ...[
                  const SizedBox(height: 95),
                  const Center(
                    child: Text(
                      '책이 아직 없습니다.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: AppColors.black500),
                    ),
                  ),
                  const SizedBox(height: 90),
                ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    final avatarUrl = profile?['avatar_url'] ?? 'basic';
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final profileUserId = profile?['id'];
    final isMyProfile = currentUserId == profileUserId;

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
                      style: Theme
                          .of(context)
                          .textTheme
                          .bodyLarge),
                  Text(profile?['job'] ?? '',
                      style: Theme
                          .of(context)
                          .textTheme
                          .bodySmall),
                  const SizedBox(height: 10),
                  _buildBio(context),
                  const SizedBox(height: 20),
                ],
              ),
            ),
            if (!isMyProfile)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    width: 71,
                    height: 71,
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.black100, width: 1),
                    ),
                    child: CircleAvatar(
                      radius: 70,
                      backgroundImage: avatarUrl == 'basic'
                          ? null
                          : NetworkImage(avatarUrl),
                      child: avatarUrl == 'basic'
                          ? Image.asset(
                          'assets/basic_avatar.png', width: 70, height: 70)
                          : null,
                    ),
                  ),

                ],
              )
            else
              Container(
                width: 71,
                height: 71,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.black100, width: 1),
                ),
                child: CircleAvatar(
                  radius: 70,
                  backgroundImage: avatarUrl == 'basic' ? null : NetworkImage(
                      avatarUrl),
                  child: avatarUrl == 'basic'
                      ? Image.asset(
                      'assets/basic_avatar.png', width: 70, height: 70)
                      : null,
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
                      ),
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

                if (userId != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FollowTabScreen(
                        userId: userId,
                        initialTabIndex: 1,
                        username: username,
                        followerCount: followerCount,
                        followingCount: followingCount,
                        isMyProfile: isMyProfile,
                      ),
                    ),
                  );
                }
              },
              child: _buildCount("팔로잉", profile?['following'] ?? 0),
            ),
            const SizedBox(width: 24),
            if (isMyProfile)
              _buildCount("방문자", profile?['visitors'] ?? 0),
            const Spacer(),
            if (!isMyProfile)
              OutlinedButton(
                onPressed: _toggleFollow,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
                  side: BorderSide(
                    color: profile?['isFollowing'] == true
                        ? AppColors.black300
                        : AppColors.black900,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                child: Text(
                  profile?['isFollowing'] == true ? '팔로잉' : '팔로우',
                  style: TextStyle(
                    fontSize: 12,
                    color: profile?['isFollowing'] == true
                        ? AppColors.black500
                        : AppColors.black900,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildBookGrid() {
    return UserBookGrid(
      books: books,
      onTap: (book) {
        final bookId = book['id'] as String;
        Navigator.pushNamed(
          context,
          '/my_post_screen',
          arguments: {'bookId': bookId, 'userId': widget.userId},
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

  Widget _buildBio(BuildContext context) {
    final bio = profile?['bio'] ?? '';
    final bool showMore = bio.length > 40;

    return LayoutBuilder(
      builder: (context, constraints) {
        final textSpan = TextSpan(
          text: bio,
          style: const TextStyle(fontSize: 12, color: AppColors.black900),
        );

        final tp = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
          maxLines: 2,
          ellipsis: showMore ? '...' : null,
        )
          ..layout(maxWidth: constraints.maxWidth);

        final isOverflowing = tp.didExceedMaxLines;

        return RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: isOverflowing
                    ? bio.substring(
                  0,
                  tp
                      .getPositionForOffset(
                      Offset(constraints.maxWidth, 28 * 2))
                      .offset,
                ) +
                    '...'
                    : bio,
                style: const TextStyle(fontSize: 12, color: AppColors.black900),
              ),
            ],
          ),
        );
      },
    );
  }
}