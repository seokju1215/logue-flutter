import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:my_logue/core/themes/app_colors.dart';
import 'package:my_logue/presentation/screens/add_book/add_book_screen.dart';
import 'package:my_logue/presentation/screens/setting/setting_screen.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_logue/data/datasources/user_book_api.dart';
import 'package:my_logue/domain/usecases/get_user_books.dart';
import 'package:my_logue/core/widgets/book/user_book_grid.dart';
import 'package:my_logue/data/utils/fetch_profile.dart';
import 'package:my_logue/data/utils/firebase_analytics_util.dart';
import 'package:my_logue/presentation/screens/profile/profile_edit/profile_edit_screen.dart';
import 'dart:ui'; // 맨 위에 추가

import '../../../core/widgets/profile/bio_content.dart';
import '../main_navigation_screen.dart';
import '../add_book/add_book_screen.dart';
import '../post/my_post_screen.dart';
import 'follow/follow_tab_screen.dart';
import 'follow_list_screen.dart';
import 'notification_screen.dart';
import 'profile_view.dart';
import 'package:flutter/gestures.dart';
import 'widgets/profile_books_tab_view.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  static Future<void> loadBooksFromContext(BuildContext context) async {
    // context를 통해 profile_screen의 State를 찾아서 loadBooks 호출
    debugPrint('🔍 ProfileScreen.loadBooksFromContext 호출됨');

    // 먼저 ProfileScreenState를 찾아보기
    final profileScreenState =
        context.findAncestorStateOfType<ProfileScreenState>();
    if (profileScreenState != null) {
      debugPrint('🔍 ProfileScreenState 찾음, loadBooks 호출');
      await profileScreenState.loadBooks();
      return;
    }

    // ProfileScreenState를 찾을 수 없으면 ProfileViewState를 찾아서 Navigator를 통해 접근
    final profileViewState =
        context.findAncestorStateOfType<ProfileViewState>();
    if (profileViewState != null) {
      debugPrint('🔍 ProfileViewState 찾음, Navigator를 통해 ProfileScreen 접근');
      final navigatorState = profileViewState.widget.navigatorKey.currentState;
      if (navigatorState != null) {
        // Navigator의 context를 통해 ProfileScreen에 접근
        final profileContext = navigatorState.context;
        final profileScreenState =
            profileContext.findAncestorStateOfType<ProfileScreenState>();
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
      final profileScreenState =
          context.findAncestorStateOfType<ProfileScreenState>();
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

class ProfileScreenState extends State<ProfileScreen> with WidgetsBindingObserver {
  final client = Supabase.instance.client;
  late final ScrollController _scrollController;

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
    _scrollController = ScrollController();
    _checkUnreadNotifications();
    _getUserBooks = GetUserBooks(UserBookApi(client));
    _fetchProfile();
    loadBooks();
    _subscribeToProfileUpdates();
    _subscribeToBookUpdates();
    _subscribeToFollowUpdates(); // 팔로우 변경사항 실시간 감지



    client.auth.onAuthStateChange.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // 앱이 포그라운드로 돌아올 때 UI 새로고침
    if (state == AppLifecycleState.resumed) {
      debugPrint('🔄 앱 포그라운드 복귀 - UI 새로고침');
      setState(() {}); // UI 새로고침으로 _getFollowCounts() 재호출
    }
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

  double _calculateProfileBooksTabHeight() {
    final screenHeight = MediaQuery.of(context).size.height;
    final paddingTop = MediaQuery.of(context).padding.top;
    final paddingBottom = MediaQuery.of(context).padding.bottom;
    final appBarHeight = kToolbarHeight;
    
    // 기본 높이 (화면 높이에서 상단/하단 패딩과 앱바 높이 제외)
    final baseHeight = screenHeight - paddingTop - appBarHeight - paddingBottom;
    
    // 프로필 헤더와 액션 버튼의 대략적인 높이 (약 200px)
    final headerHeight = 275.0;
    
    // 책이 6권 이하면 모든 높이 사용, 6권 초과면 화면의 80% 사용
    if (books.length <= 6) {
      // 6권 이하: 헤더 높이를 제외한 나머지 높이 사용
      return (baseHeight - headerHeight).clamp(200.0, baseHeight * 0.8);
    } else {
      // 6권 초과: 화면의 대부분을 사용 (기본 높이의 80%)
      return (baseHeight * 0.8).clamp(300.0, baseHeight * 0.9);
    }
  }

  Future<void> _fetchProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      // 프로필 기본 정보 가져오기
      final data = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (mounted) {
        setState(() {
          profile = data;
        });
      }
    } catch (e) {
      debugPrint('❌ 프로필 로드 실패: $e');
    }
  }

  // 프로필 전체를 새로고침하는 함수
  Future<void> refreshProfile() async {
    debugPrint('🔍 프로필 전체 새로고침 시작');
    await _fetchProfile();
    await loadBooks();
    await _checkUnreadNotifications();
    debugPrint('🔍 프로필 전체 새로고침 완료');
  }

  // 팔로워/팔로잉 카운트를 실시간으로 가져오는 함수
  Future<Map<String, int>> _getFollowCounts([String? userId]) async {
    final targetUserId = userId ?? Supabase.instance.client.auth.currentUser?.id;
    if (targetUserId == null) return {'followers': 0, 'following': 0};

    try {
      final followerRes = await Supabase.instance.client
          .from('follows')
          .select('id')
          .eq('following_id', targetUserId);
      final followerCount = followerRes.length;

      final followingRes = await Supabase.instance.client
          .from('follows')
          .select('id')
          .eq('follower_id', targetUserId);
      final followingCount = followingRes.length;

      return {'followers': followerCount, 'following': followingCount};
    } catch (e) {
      debugPrint('❌ 팔로워/팔로잉 카운트 조회 실패: $e');
      return {'followers': 0, 'following': 0};
    }
  }



  Future<void> loadBooks() async {
    final user = client.auth.currentUser;
    if (user == null) return;

    final result = await _getUserBooks(user.id);
    result.sort(
        (a, b) => (a['order_index'] as int).compareTo(b['order_index'] as int));

    setState(() {
      books = result;
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

  void _subscribeToFollowUpdates() {
    final user = client.auth.currentUser;
    if (user == null) return;

    // 팔로우 테이블 변경사항을 실시간으로 감지
    client.channel('public:follows')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'follows',
        callback: (payload) async {
          if (!mounted) return;
          
          // 팔로우/언팔로우 변경사항이 발생하면 UI 새로고침
          debugPrint('🔄 팔로우 테이블 변경 감지: ${payload.eventType}');
          setState(() {}); // UI 새로고침으로 _getFollowCounts() 재호출
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
        title: Text(
          profile?['username'] ?? 'User',
          style: TextStyle(
            fontSize: 16,
            color: AppColors.black900,
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
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
            padding: const EdgeInsets.only(right: 12),
            child: Transform.scale(
              scale: 1,
              child: IconButton(
                icon: SvgPicture.asset('assets/edit_icon.svg'),
                onPressed: () async {
                  setState(() => _showFullBio = false);
                  final result =
                      await Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute(
                      builder: (_) => SettingScreen(),
                    ),
                  );
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
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(25, 9, 25, 7),
                      child: _buildProfileHeader(),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 0, horizontal: 16),
                      child: _buildActionButtons(),
                    ),
                    if ((profile?['show_archived_books'] as bool?) ?? false) ...[
                      SizedBox(
                        height: _calculateProfileBooksTabHeight(),
                        child: ProfileBooksTabView(
                          nonArchivedBooks: books,
                          userId: profile?['id'] as String,
                          parentScrollController: _scrollController,
                          isOtherUser: false,
                        ),
                      ),
                    ] else ...[
                if (books.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 20, horizontal: 26),
                    child: SizedBox(
                      height: null,
                      child: _buildBookGrid(),
                    ),
                  ),
                  const SizedBox(height: 20),
                ] else ...[
                  const SizedBox(height: 76),
                  Center(
                    child: Column(
                      children: [
                        Builder(
                          builder: (context) {
                            return TextButton(
                              onPressed: () async {
                                // MainNavigationScreen의 AddBookView로 이동
                                final mainNavigationState = context.findAncestorStateOfType<MainNavigationScreenState>();
                                if (mainNavigationState != null) {
                                  mainNavigationState.navigateToAddBookProfileTab();
                                }
                              },
                              child: const Text(
                                "책 추가 +",
                                style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.black900,
                                    fontWeight: FontWeight.w400),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ],
            ],
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
                      style:
                          TextStyle(fontSize: 22, color: AppColors.black900)),
                  const SizedBox(height: 3),
                  if (profile?['job'] == '')
                    const SizedBox(height:4),
                  if (profile?['job'] != '')
                    Text(profile?['job'] ?? '',
                        style: TextStyle(fontSize: 15, color: AppColors.black500)),
                  if (profile?['job'] != '')
                    const SizedBox(height: 9),
                  _buildBio(context),
                  if (profile?['job'] == '')
                    const SizedBox(height : 5),
                  if (profile?['job'] == '')
                    Text('', style: TextStyle(fontSize: 15, color: AppColors.black500)),
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
        FutureBuilder<Map<String, int>>(
          future: _getFollowCounts(),
          builder: (context, snapshot) {
            final followerCount = snapshot.data?['followers'] ?? 0;
            final followingCount = snapshot.data?['following'] ?? 0;
            
            return Row(
              children: [
                GestureDetector(
                  onTap: () {
                    final userId = profile?['id'];
                    final username = profile?['username'];
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
                        // 팔로우 탭에서 돌아올 때 UI 새로고침
                        setState(() {});
                      });
                    }
                  },
                  child: _buildCount("팔로워", followerCount),
                ),
                const SizedBox(width: 27),
                GestureDetector(
                  onTap: () {
                    final userId = profile?['id'];
                    final username = profile?['username'];
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
                            username: username,
                            followerCount: followerCount,
                            followingCount: followingCount,
                            isMyProfile: isMyProfile,
                          ), // 팔로잉 탭
                        ),
                      ).then((_) {
                        // 팔로우 탭에서 돌아올 때 UI 새로고침
                        setState(() {});
                      });
                    }
                  },
                  child: _buildCount("팔로잉", followingCount),
                ),
              ],
            );
          },
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
              final result =
                  await Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute(
                  builder: (_) => ProfileEditScreen(initialProfile: profile!),
                ),
              );
              if (result == true) {
                _fetchProfile();
              }
            },
            child: const Text("프로필 편집",
                style: TextStyle(color: AppColors.black900, fontSize: 13)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton(
            style: _outlinedStyle(context),
            onPressed: () async {
              final profileLink =
                  'https://www.logue.it.kr/${profile?['username']}';
              final userId = profile?['id'];
              if (profileLink != null && profileLink.isNotEmpty) {
                // 클립보드에 복사
                await Clipboard.setData(ClipboardData(text: profileLink));
                
                // 스낵바 표시
                _showSnackBar('링크를 복사했어요');
                
                // Firebase Analytics 이벤트 전송
                try {
                  debugPrint('🚀🚀🚀 프로필 화면에서 공유 이벤트 전송 시도');
                  await FirebaseAnalyticsUtil.logProfileShare(
                    sourceScreen: 'profile_screen',
                    sharedUserId: userId,
                    sharedUsername: profile?['username'] ?? '',
                    shareMethod: 'copy_button',
                  );
                  debugPrint('🎯🎯🎯 프로필 화면에서 공유 이벤트 전송 완료');
                } catch (analyticsError) {
                  debugPrint('❌ 프로필 공유 이벤트 전송 실패: $analyticsError');
                }
              }
            },
            child: const Text("링크 복사",
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
        final availableWidth =
            constraints.maxWidth - avatarSize - horizontalPadding;
        return BioContent(bio: bio, maxWidth: availableWidth);
      },
    );
  }

  Widget _buildCount(String label, int count, {bool isTappable = true}) {
    final content = Column(
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13, color: AppColors.black500, height: 1)),
        const SizedBox(height: 6),
        Text(formatCount(count),
            style: const TextStyle(
                fontSize: 13, color: AppColors.black500, height: 1)),
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
      minimumSize: MaterialStateProperty.all(const Size.fromHeight(34)),
      textStyle: MaterialStateProperty.all(
        const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          height: 1.25,
        ),
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Center(child: Text(message, style: const TextStyle(fontSize: 16, height: 1.1))),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 90, vertical: 44 ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        backgroundColor: AppColors.black500,
      ),
    );
  }
}
