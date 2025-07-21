import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:my_logue/core/themes/app_colors.dart';
import 'package:my_logue/presentation/screens/profile/add_book/add_book_screen.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_logue/data/datasources/user_book_api.dart';
import 'package:my_logue/domain/usecases/get_user_books.dart';
import 'package:my_logue/core/widgets/book/user_book_grid.dart';
import 'package:my_logue/data/utils/fetch_profile.dart';
import 'package:my_logue/presentation/screens/profile/profile_edit/profile_edit_screen.dart';
import 'dart:ui'; // 맨 위에 추가


import '../../../core/widgets/profile/bio_content.dart';
import '../main_navigation_screen.dart';
import '../post/my_post_screen.dart';
import 'follow/follow_tab_screen.dart';
import 'follow_list_screen.dart';
import 'notification_screen.dart';
import 'profile_view.dart';
import 'package:flutter/gestures.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  static Future<void> loadBooksFromContext(BuildContext context) async {
    // context를 통해 profile_screen의 State를 찾아서 loadBooks 호출
    debugPrint('🔍 ProfileScreen.loadBooksFromContext 호출됨');
    
    // 먼저 ProfileScreenState를 찾아보기
    final profileScreenState = context.findAncestorStateOfType<ProfileScreenState>();
    if (profileScreenState != null) {
      debugPrint('🔍 ProfileScreenState 찾음, loadBooks 호출');
      await profileScreenState.loadBooks();
      return;
    }
    
    // ProfileScreenState를 찾을 수 없으면 ProfileViewState를 찾아서 Navigator를 통해 접근
    final profileViewState = context.findAncestorStateOfType<ProfileViewState>();
    if (profileViewState != null) {
      debugPrint('🔍 ProfileViewState 찾음, Navigator를 통해 ProfileScreen 접근');
      final navigatorState = profileViewState.widget.navigatorKey.currentState;
      if (navigatorState != null) {
        // Navigator의 context를 통해 ProfileScreen에 접근
        final profileContext = navigatorState.context;
        final profileScreenState = profileContext.findAncestorStateOfType<ProfileScreenState>();
        if (profileScreenState != null) {
          debugPrint('🔍 Navigator를 통해 ProfileScreenState 찾음, loadBooks 호출');
          await profileScreenState.loadBooks();
          return;
        }
      }
    }
    
    debugPrint('🔍 ProfileScreenState를 찾을 수 없음');
  }

  static Future<void> navigateToMyBookPostScreen(BuildContext context) async {
    debugPrint('🔍 ProfileScreen.navigateToMyBookPostScreen 호출됨');
    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MyBookPostScreen()),
    );
    debugPrint('🔍 MyBookPostScreen 결과: $result');
    if (result == true) {
      debugPrint('🔍 포스트 삭제됨, profile_screen 새로고침 시도');
      // profile_screen의 State를 찾아서 loadBooks 호출
      final profileScreenState = context.findAncestorStateOfType<ProfileScreenState>();
      if (profileScreenState != null) {
        debugPrint('🔍 ProfileScreenState 찾음, loadBooks 호출');
        await profileScreenState.loadBooks();
      } else {
        debugPrint('🔍 ProfileScreenState를 찾을 수 없음');
      }
    }
  }

  @override
  State<ProfileScreen> createState() => ProfileScreenState();
}

class ProfileScreenState extends State<ProfileScreen> {
  final client = Supabase.instance.client;
  final ScrollController _scrollController = ScrollController();
  bool _isScrollable = false;

  Map<String, dynamic>? profile;
  late final RealtimeChannel _profileChannel;
  late final RealtimeChannel _bookChannel;
  late final GetUserBooks _getUserBooks;
  bool _showFullBio = false;
  List<Map<String, dynamic>> books = [];
  bool _hasUnreadNotifications = false;

  @override
  void initState() {
    super.initState();
    _checkUnreadNotifications();
    _getUserBooks = GetUserBooks(UserBookApi(client));
    _fetchProfile();
    loadBooks();
    _subscribeToProfileUpdates();
    _subscribeToBookUpdates();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkIfScrollable();
    });

    client.auth.onAuthStateChange.listen((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _checkUnreadNotifications() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    final res = await Supabase.instance.client
        .from('notifications')
        .select('id')
        .eq('recipient_id', userId)
        .eq('is_read', false)
        .limit(1);

    setState(() {
      _hasUnreadNotifications = res.isNotEmpty;
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
  String formatCount(int count) {
    if (count >= 1000) {
      double divided = count / 1000;
      double floored = (divided * 10).floorToDouble() / 10;
      return '${floored.toStringAsFixed(1)}k';
    } else {
      return count.toString();
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
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final data = await Supabase.instance.client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    // 실시간 팔로워/팔로잉 카운트 가져오기
    final followerRes = await Supabase.instance.client
        .from('follows')
        .select('id')
        .eq('following_id', user.id);
    final followerCount = followerRes.length;

    final followingRes = await Supabase.instance.client
        .from('follows')
        .select('id')
        .eq('follower_id', user.id);
    final followingCount = followingRes.length;

    setState(() {
      profile = {
        ...?data,
        'followers': followerCount,
        'following': followingCount,
      };
    });
  }

  // 프로필 전체를 새로고침하는 함수
  Future<void> refreshProfile() async {
    debugPrint('🔍 프로필 전체 새로고침 시작');
    await _fetchProfile();
    await loadBooks();
    await _checkUnreadNotifications();
    debugPrint('🔍 프로필 전체 새로고침 완료');
  }

  Future<void> _updateFollowCounts() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || profile == null) return;

    // 실시간 팔로워/팔로잉 카운트 업데이트
    final followerRes = await Supabase.instance.client
        .from('follows')
        .select('id')
        .eq('following_id', user.id);
    final followerCount = followerRes.length;

    final followingRes = await Supabase.instance.client
        .from('follows')
        .select('id')
        .eq('follower_id', user.id);
    final followingCount = followingRes.length;

    setState(() {
      profile = {
        ...profile!,
        'followers': followerCount,
        'following': followingCount,
      };
    });
  }

  Future<void> loadBooks() async {
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
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'user_books',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'user_id',
          value: user.id,
        ),
        callback: (payload) async {
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
      ..onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'profiles',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'id',
          value: user.id,
        ),
        callback: (payload) {
          final newProfile = payload.newRecord;
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
      appBar: AppBar(
        title: Text(profile?['username'] ?? 'User', style: TextStyle(fontSize: 16, color: AppColors.black900, fontWeight: FontWeight.w500,),),
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.only(left:16),
          child: IconButton(
            icon: Transform.scale(
              scale: 1.08,
              child: SvgPicture.asset(_hasUnreadNotifications
                  ? 'assets/noticed_alarm_icon.svg'
                  : 'assets/bell_icon.svg'),
            ),
            onPressed: () async {
              final result = await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NotificationScreen()),
              );
              _checkUnreadNotifications(); // 읽지 않은 알림 다시 체크
              setState(() => _showFullBio = false);
            },
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right:12),
            child: Transform.scale(
              scale: 1.1,
              child: IconButton(
                icon: SvgPicture.asset('assets/edit_icon.svg'),
                onPressed: () async {
                  setState(() => _showFullBio = false);
                  final result = await Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute(
                      builder: (_) => ProfileEditScreen(initialProfile: profile!),
                    ),
                  );
                  print('👈 result 받음: $result');
                  if (result == true) {
                    _fetchProfile();
                  }
                },
              ),
            ),
          ),
        ],
        backgroundColor: Colors.white,
        elevation: 0,
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
                        padding: const EdgeInsets.fromLTRB(25, 9, 25, 7),
                        child: _buildProfileHeader(),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                        child: _buildActionButtons(),
                      ),
                      const SizedBox(height: 20),
                      if (books.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 0, horizontal:26),
                          child: _buildBookGrid(),
                        ),
                        const SizedBox(height: 20),
                      ] else ...[
                        const SizedBox(height: 55),
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
                                        MaterialPageRoute(builder: (_) => AddBookScreen(isLimitReached: books.length >= 9,)),
                                      );
                                      if (result == true) {
                                        loadBooks(); // ✅ 책 목록 다시 불러오기
                                      }
                                    },
                                    child: const Text(
                                      "책 추가 +",
                                      style: TextStyle(fontSize: 12, color: AppColors.black900, fontWeight: FontWeight.w400),
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
                  const SizedBox(height: 3),
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
                    radius: 40.5,
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
                  ).then((_) {
                    // 팔로우 탭에서 돌아올 때 카운트 업데이트
                    _updateFollowCounts();
                  });
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
                  ).then((_) {
                    // 팔로우 탭에서 돌아올 때 카운트 업데이트
                    _updateFollowCounts();
                  });
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
                MaterialPageRoute(builder: (_) => AddBookScreen(isLimitReached: books.length >= 9,)),
              );
              if (result == true) {
                loadBooks(); // ✅ 변경사항 반영
              }
            },
            child: const Text("책 추가 +",
                style: TextStyle(color: AppColors.black900, fontSize: 13)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton(
            style: _outlinedStyle(context),
            onPressed: () async {
              final profileLink = 'https://www.logue.it.kr/u/${profile?['username']}';
              final userId = profile?['id'];
              if (profileLink != null && profileLink.isNotEmpty) {
                Share.share(profileLink);
              }
            },
            child: const Text("프로필 공유",
                style: TextStyle(color: AppColors.black900, fontSize: 13)),
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
          loadBooks();
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
    const avatarSize = 40.0;
    const horizontalPadding = 11.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth - avatarSize - horizontalPadding;
        return BioContent(bio: bio, maxWidth: availableWidth);
      },
    );
  }


  Widget _buildCount(String label, int count, {bool isTappable = true}) {
    final content = Column(
      children: [
        Text(label,
            style: const TextStyle(fontSize: 13, color: AppColors.black500, height: 1)),
        const SizedBox(height: 6),
        Text(formatCount(count),
            style: const TextStyle(fontSize: 13, color: AppColors.black500, height: 1)),
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
        EdgeInsets.symmetric(vertical: 8),
      ),
      minimumSize: MaterialStateProperty.all(
          const Size.fromHeight(34)
      ),
      textStyle: MaterialStateProperty.all(
        const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          height: 1.25,
        ),
      ),
    );
  }
}
