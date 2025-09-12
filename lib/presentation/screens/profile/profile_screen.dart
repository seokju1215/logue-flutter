import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

// SliverPersistentHeaderDelegate 클래스 추가
class _ProfileBooksTabViewDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;

  _ProfileBooksTabViewDelegate({required this.child, required this.height});

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox(
      height: height,
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return oldDelegate is _ProfileBooksTabViewDelegate && oldDelegate.height != height;
  }
}

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
  bool _hasShownProfileAnnouncement = false; // 프로필 안내 표시 여부
  final GlobalKey<ProfileBooksTabViewState> _profileBooksTabViewKey = GlobalKey<ProfileBooksTabViewState>();
  bool _isBubbleVisible = false;
  final ValueNotifier<int> _currentTabIndexNotifier = ValueNotifier<int>(0);

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

    // 프로필 안내 표시 체크
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowProfileAnnouncement();
    });

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

  /// 프로필 안내 표시 체크 및 표시
  Future<void> _checkAndShowProfileAnnouncement() async {
    // 디자인을 위해 제한 제거 - 매번 표시
    if (mounted) {
      setState(() {
        _hasShownProfileAnnouncement = true;
      });
      debugPrint('📢 프로필 안내 표시 (디자인 모드)');
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
    _currentTabIndexNotifier.dispose();
    super.dispose();
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
        callback: (payload) async {
          final newProfile = payload.newRecord;
          if (mounted && newProfile != null) {
            final oldShowArchivedBooks = profile?['show_archived_books'] as bool?;
            final newShowArchivedBooks = newProfile['show_archived_books'] as bool?;
            
            // show_archived_books 값이 변경되었는지 체크
            if (oldShowArchivedBooks != null && 
                newShowArchivedBooks != null && 
                oldShowArchivedBooks != newShowArchivedBooks) {
              debugPrint('🔄 show_archived_books 변경 감지: $oldShowArchivedBooks -> $newShowArchivedBooks');
              await _markShowArchivedBooksChanged();
            }
            
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

  // show_archived_books 변경을 SharedPreferences에 기록
  Future<void> _markShowArchivedBooksChanged() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_changed_show_archived_books', true);
      debugPrint('✅ show_archived_books 변경 기록됨 - 말풍선 더 이상 표시 안함');
    } catch (e) {
      debugPrint('❌ show_archived_books 변경 기록 실패: $e');
    }
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
              if (_isBubbleVisible) {
                // 말풍선이 보이는 상태면 말풍선만 숨기기
                _profileBooksTabViewKey.currentState?.hideBubble();
                return;
              }
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
                  if (_isBubbleVisible) {
                    // 말풍선이 보이는 상태면 말풍선만 숨기기
                    _profileBooksTabViewKey.currentState?.hideBubble();
                    return;
                  }
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
        child: GestureDetector(
          onTap: _isBubbleVisible ? () {
            // ProfileBooksTabView의 말풍선 숨기기
            _profileBooksTabViewKey.currentState?.hideBubble();
          } : null,
          child: NotificationListener<ScrollNotification>(
            onNotification: (ScrollNotification notification) {
              // 스크롤 이벤트가 발생하면 말풍선 숨기기
              if (_isBubbleVisible && notification is ScrollUpdateNotification) {
                _profileBooksTabViewKey.currentState?.hideBubble();
                // 스크롤을 막기 위해 위치를 원래대로 되돌림
                _scrollController.jumpTo(0);
              }
              return _isBubbleVisible; // 말풍선이 표시된 상태에서는 스크롤 이벤트를 막음
            },
            child: NestedScrollView(
              controller: _scrollController,
              headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
              // 탭바 고정 상태를 ProfileBooksTabView에 전달
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _profileBooksTabViewKey.currentState?.updateTabBarPinnedState(innerBoxIsScrolled);
              });
              
              return <Widget>[
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(25, 0, 25, 7),
                        child: _buildProfileHeader(),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 0, horizontal: 16),
                        child: _buildActionButtons(),
                      ),
                    ],
                  ),
                ),
                if ((profile?['show_archived_books'] as bool?) ?? false)
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _ProfileBooksTabViewDelegate(
                      height: 30.0, // 탭바 높이만
                      child: _buildTabsOnly(),
                    ),
                  ),
              ];
            },
            body: (profile?['show_archived_books'] as bool?) ?? false
                ? GestureDetector(
                    onTap: _isBubbleVisible ? () {
                      // ProfileBooksTabView의 말풍선 숨기기
                      _profileBooksTabViewKey.currentState?.hideBubble();
                    } : null,
                    child: ProfileBooksTabView(
                      key: _profileBooksTabViewKey,
                      nonArchivedBooks: books,
                      userId: profile?['id'] as String,
                      parentScrollController: _scrollController,
                      isOtherUser: false,
                      profile: profile,
                      onBubbleStateChanged: (isVisible) {
                        setState(() {
                          _isBubbleVisible = isVisible;
                        });
                      },
                      onTabChanged: (index) {
                        _currentTabIndexNotifier.value = index;
                      },
                    ),
                  )
                : SingleChildScrollView(
                    child: Column(
                      children: [
                        if (books.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 20, horizontal: 26),
                            child: _buildBookGrid(),
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
                                      onPressed: _isBubbleVisible ? null : () async {
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
                    ),
                  ),
            ),
          ),
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
              onTap: _isBubbleVisible ? null : () => _showZoomedAvatar(avatarUrl),
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
                  onTap: _isBubbleVisible ? null : () {
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
                  onTap: _isBubbleVisible ? null : () {
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
            onPressed: _isBubbleVisible ? null : () async {
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
            onPressed: _isBubbleVisible ? null : () async {
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
      onTap: _isBubbleVisible ? null : (book) async {
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

  Widget _buildTabsOnly() {
    return Material(
      color: Colors.white,
      child: SizedBox(
        height: 30.0,
        child: Row(
          children: [
            _buildTab('대표', 0),
            _buildTab('책장', 1),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(String label, int index) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          _profileBooksTabViewKey.currentState?.pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeInOut,
          );
        },
        child: ValueListenableBuilder<int>(
          valueListenable: _currentTabIndexNotifier,
          builder: (context, currentIndex, child) {
            final isSelected = currentIndex == index;
            
            return Stack(
              alignment: Alignment.bottomCenter,
              children: [
                Container(
                  height: 30,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: AppColors.black500, width: 1),
                    ),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isSelected ? AppColors.black900 : AppColors.black500,
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
                if (isSelected)
                  const Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Divider(
                      thickness: 2,
                      height: 0,
                      color: AppColors.black900,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}