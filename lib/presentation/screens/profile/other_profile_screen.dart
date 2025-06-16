import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:logue/core/themes/app_colors.dart';
import 'package:logue/presentation/screens/post/my_post_screen.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logue/data/datasources/user_book_api.dart';
import 'package:logue/domain/usecases/get_user_books.dart';
import 'package:logue/core/widgets/book/user_book_grid.dart';
import 'package:logue/data/repositories/follow_repository.dart';
import 'package:logue/domain/usecases/follows/follow_user.dart';
import 'package:logue/domain/usecases/follows/unfollow_user.dart';
import 'package:logue/domain/usecases/follows/is_following.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../../core/widgets/common/custom_app_bar.dart';
import 'follow/follow_tab_screen.dart';

class OtherProfileScreen extends StatefulWidget {
  final String userId;

  const OtherProfileScreen({Key? key, required this.userId}) : super(key: key);

  @override
  State<OtherProfileScreen> createState() => _OtherProfileScreenState();
}

class _OtherProfileScreenState extends State<OtherProfileScreen> {
  bool _showFullBio = false;
  final client = Supabase.instance.client;
  final ScrollController _scrollController = ScrollController();
  late final FollowRepository _followRepo;
  late final FollowUser _followUser;
  late final UnfollowUser _unfollowUser;
  late final IsFollowing _isFollowing;
  bool _isScrollable = false;
  bool _isFollowProcessing = false;

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
        'user_id': widget.userId,
      });
    } catch (e) {
      debugPrint('❌ 방문자 증가 실패: $e');
    }
  }

  Future<void> _fetchProfile() async {
    final userId = widget.userId;

    final data = await client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();

    final following = await _isFollowing(userId);

    final followerRes = await client
        .from('follows')
        .select('*', const FetchOptions(count: CountOption.exact))
        .eq('following_id', userId);
    final followerCount = followerRes.count ?? 0;

    final followingRes = await client
        .from('follows')
        .select('*', const FetchOptions(count: CountOption.exact))
        .eq('follower_id', userId);
    final followingCount = followingRes.count ?? 0;

    setState(() {
      profile = {
        ...?data,
        'isFollowing': following,
        'followers': followerCount,
        'following': followingCount,
      };
    });
  }

  Future<void> _toggleFollow() async {
    if (_isFollowProcessing) return; // 연타 방지
    _isFollowProcessing = true;

    final currentUserId = client.auth.currentUser?.id;
    if (currentUserId == widget.userId) return;

    final prevFollowing = profile?['isFollowing'] == true;
    final currentFollowers = profile?['followers'] ?? 0;

    // 1. optimistic UI update
    setState(() {
      profile = {
        ...?profile,
        'isFollowing': !prevFollowing,
        'followers': prevFollowing
            ? (currentFollowers - 1).clamp(0, currentFollowers)
            : currentFollowers + 1,
      };
    });

    try {
      if (prevFollowing) {
        await _unfollowUser(widget.userId);
      } else {
        await _followUser(widget.userId);
      }

      // 동기화
      await _fetchProfile();
    } catch (e) {
      // rollback
      setState(() {
        profile = {
          ...?profile,
          'isFollowing': prevFollowing,
          'followers': currentFollowers,
        };
      });
      debugPrint('❌ 팔로우 변경 실패: $e');
    } finally {
      _isFollowProcessing = false;
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

    int min = 0;
    int max = text.length;

    while (min < max) {
      final mid = (min + max) ~/ 2;
      final testStr = text.substring(0, mid) + trailingText;
      textPainter.text = TextSpan(text: testStr, style: style);
      textPainter.layout(maxWidth: maxWidth);

      if (textPainter.didExceedMaxLines) {
        max = mid;
      } else {
        min = mid + 1;
      }
    }

    final safeIndex = (max - trailingText.length).clamp(0, text.length);
    return text.substring(0, safeIndex);
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


  void _showZoomedAvatar(String avatarUrl) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Stack(
          children: [
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                color: Colors.black.withOpacity(0.4),
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
          leadingIconPath: 'assets/back_arrow.svg', // 👈 원하는 백 아이콘 경로로 수정해줘
          onLeadingTap: () => Navigator.pop(context, true),
          trailingIconPath: 'assets/share_button.svg',
          onTrailingTap: () {
            final profileLink = 'https://www.logue.it.kr/u/${profile?['username']}';
            if (profileLink.isNotEmpty) {
              Share.share(profileLink);
            }
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
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
  ButtonStyle _outlinedStyle(BuildContext context, {required bool isFollowing}) {
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
        BorderSide(
          color: isFollowing ? AppColors.black300 : AppColors.black500,
          width: 1,
        ),
      ),
      shape: MaterialStateProperty.all(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      padding: MaterialStateProperty.all(
        const EdgeInsets.symmetric(horizontal: 9),
      ),
      minimumSize: MaterialStateProperty.all(
        const Size(120, 34),
      ),
      textStyle: MaterialStateProperty.all(
        const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          height: 1.0,
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
        SizedBox(height: 6),
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
                  const SizedBox(height: 10),
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
                    radius: 40.5,
                    backgroundImage: avatarUrl == 'basic'
                        ? null
                        : NetworkImage(avatarUrl),
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
        SizedBox(height: 20,),
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
            const SizedBox(width: 27),
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
            const Spacer(),
            if (!isMyProfile)
              OutlinedButton(
                onPressed: _isFollowProcessing ? null : _toggleFollow,
                style: _outlinedStyle(context, isFollowing: profile?['isFollowing'] == true),
                child: profile?['isFollowing'] == true
                    ? const Text(
                  '팔로잉',
                  style: TextStyle(
                    color: AppColors.black500,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    height: 1.0,
                  ),
                )
                    : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text(
                      '팔로우',
                      style: TextStyle(
                        color: AppColors.black900,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        height: 1.0,
                      ),
                    ),
                    SizedBox(width: 1.8),
                    Padding(
                      padding: EdgeInsets.only(top: 1.4),
                      child: Icon(
                        Icons.add,
                        size: 14,
                        color: AppColors.black900,
                      ),
                    ),
                  ],
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
        final bookId = book['book_id'] ?? book['id']; // <- 🔥 보장
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MyBookPostScreen(bookId: bookId, userId : widget.userId),
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

  Widget _buildBio(BuildContext context) {
    final bio = profile?['bio'] ?? '';

    const avatarSize = 40.0; // 아바타 크기
    const horizontalPadding = 22.0; // 아바타 오른쪽 여백
    const maxLines = 2;
    const lineHeight = 1.2;
    const fontSize = 12.0;
    const textStyle = TextStyle(
      fontSize: 12,
      color: AppColors.black900,
      fontFamily: 'Inter',
      fontWeight: FontWeight.w400,
      height: 1.2,
    );

    final fixedHeight = fontSize * lineHeight * maxLines;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth - avatarSize - horizontalPadding;

        // bio 전체 보기 모드
        if (_showFullBio && bio.isNotEmpty) {
          return SizedBox(
            height: fixedHeight,
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: availableWidth),
                child: Text(bio, style: TextStyle(
                  fontSize: 12,
                  color: AppColors.black900,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w400,
                  height: 1.2,
                )),
              ),
            ),
          );
        }

        // bio 없을 경우도 fixedHeight 확보
        if (bio.isEmpty) {
          return SizedBox(height: fixedHeight); // ✅ 공간 확보
        }

        // overflow 여부 확인
        final tp = TextPainter(
          text: TextSpan(text: bio, style: TextStyle(
            fontSize: 12,
            color: AppColors.black900,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w400,
            height: 1.2,
          )),
          maxLines: maxLines,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: availableWidth);

        final isOverflow = tp.didExceedMaxLines;

        // 잘리지 않는 경우
        if (!isOverflow) {
          return SizedBox(
            height: fixedHeight,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: availableWidth),
              child: Text(
                bio,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.black900,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w400,
                  height: 1.2,
                ),
                maxLines: maxLines,
                overflow: TextOverflow.ellipsis,
                textHeightBehavior: const TextHeightBehavior(
                  applyHeightToFirstAscent: false,
                  applyHeightToLastDescent: false,
                ),
              ),
            ),
          );
        }

        // 잘리는 경우 + ...더보기 표시
        final truncatedText = _truncateTextToFit(
          bio,
          TextStyle(
            fontSize: 12,
            color: AppColors.black900,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w400,
            height: 1.2,
          ),
          availableWidth,
          maxLines,
          '... 더보기',
        );

        return SizedBox(
          height: fixedHeight, // ✅ 항상 높이 확보
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: availableWidth),
            child: GestureDetector(
              onTap: () => setState(() => _showFullBio = true),
              child: Text(
                '$truncatedText... 더보기',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.black900,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w400,
                  height: 1.2,
                ),
                maxLines: maxLines,
                overflow: TextOverflow.ellipsis,
                textHeightBehavior: const TextHeightBehavior(
                  applyHeightToFirstAscent: false,
                  applyHeightToLastDescent: false,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}