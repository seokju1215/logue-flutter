import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:my_logue/core/themes/app_colors.dart';
import 'package:my_logue/presentation/screens/post/my_post_screen.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_logue/data/datasources/user_book_api.dart';
import 'package:my_logue/domain/usecases/get_user_books.dart';
import 'package:my_logue/core/widgets/book/user_book_grid.dart';
import 'package:my_logue/data/repositories/follow_repository.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../../core/providers/follow_state_provider.dart';

import '../../../core/widgets/profile/bio_content.dart';
// import 'package:logue/data/utils/amplitude_util.dart';
import 'follow/follow_tab_screen.dart';

class OtherProfileScreen extends ConsumerStatefulWidget {
  final String userId;

  const OtherProfileScreen({Key? key, required this.userId}) : super(key: key);

  @override
  ConsumerState<OtherProfileScreen> createState() => _OtherProfileScreenState();
}

class _OtherProfileScreenState extends ConsumerState<OtherProfileScreen> {
  final client = Supabase.instance.client;
  final ScrollController _scrollController = ScrollController();
  late final FollowRepository _followRepo;
  bool _isScrollable = false;
  bool _hasFollowStateChanged = false; // 팔로우 상태 변경 추적
  bool _isFollowActionInProgress = false; // 팔로우 액션 중복 방지

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

    final followerRes = await client
        .from('follows')
        .select('*')
        .eq('following_id', userId);
    final followerCount = followerRes.length;

    final followingRes = await client
        .from('follows')
        .select('*')
        .eq('follower_id', userId);
    final followingCount = followingRes.length;

    if (mounted) {
      setState(() {
        profile = {
          ...?data,
          'followers': followerCount,
          'following': followingCount,
        };
      });
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
  void dispose() {
    debugPrint('🔍 OtherProfileScreen dispose: ${widget.userId}');
    _scrollController.dispose();
    
    // 화면이 dispose될 때도 상태 변경 여부를 반환
    if (_hasFollowStateChanged && mounted) {
      // 릴리즈 모드에서 네트워크 요청 완료를 보장하기 위한 대기
      Future.delayed(const Duration(milliseconds: 800)).then((_) {
        if (mounted) {
          Navigator.pop(context, true);
        }
      });
    }
    
    super.dispose();
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
        leading: IconButton(
          icon: SvgPicture.asset('assets/back_arrow.svg'),
          onPressed: () {
            debugPrint('🔍 ===== 앱바 뒤로가기 버튼 눌림 =====');
            _handleBackNavigation();
          },
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton(
              icon: SvgPicture.asset('assets/share_button.svg'),
              onPressed: () {
                final profileLink = 'https://www.logue.it.kr/u/${profile?['username']}';
                if (profileLink.isNotEmpty) {
                  Share.share(profileLink);
                }
              },
            ),
          ),
        ],
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProfileHeader(),
              const SizedBox(height: 20),
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
    
    // StateProvider에서 팔로우 상태 가져오기
    final riverpodIsFollowing = ref.watch(followStateProvider(widget.userId));
    final isFollowing = riverpodIsFollowing;
    
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
                  ).then((_) {
                    // 팔로우 탭에서 돌아올 때 카운트 업데이트
                    _fetchProfile();
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
                  ).then((_) {
                    // 팔로우 탭에서 돌아올 때 카운트 업데이트
                    _fetchProfile();
                  });
                }
              },
              child: _buildCount("팔로잉", profile?['following'] ?? 0),
            ),
            const SizedBox(width: 24),
            const Spacer(),
            if (!isMyProfile)
              OutlinedButton(
                onPressed: () async {
                  if (_isFollowActionInProgress) {
                    debugPrint('🔴 팔로우 액션 중복 방지');
                    return;
                  }
                  
                  _isFollowActionInProgress = true;
                  debugPrint('🔍 팔로우 액션 시작: ${widget.userId}');
                  final followNotifier = ref.read(followStateProvider(widget.userId).notifier);
                  final currentFollowers = profile?['followers'] ?? 0;
                  
                  try {
                    if (isFollowing) {
                      // 언팔로우
                      debugPrint('🔍 언팔로우 버튼 클릭');
                      
                      // 팔로우 상태 변경 플래그 설정
                      _hasFollowStateChanged = true;
                      
                      // 즉시 UI 업데이트 (Optimistic Update)
                      followNotifier.optimisticUnfollow();
                      setState(() {
                        profile = {
                          ...?profile,
                          'followers': (currentFollowers - 1).clamp(0, currentFollowers),
                        };
                      });
                      
                      // 서버 요청 (백그라운드)
                      await followNotifier.unfollow();
                      debugPrint('🔍 언팔로우 서버 요청 완료');
                    } else {
                      // 팔로우
                      debugPrint('🔍 팔로우 버튼 클릭');
                      
                      // 팔로우 상태 변경 플래그 설정
                      _hasFollowStateChanged = true;
                      
                      // 즉시 UI 업데이트 (Optimistic Update)
                      followNotifier.optimisticFollow();
                      setState(() {
                        profile = {
                          ...?profile,
                          'followers': currentFollowers + 1,
                        };
                      });

                      // 서버 요청 (백그라운드)
                      await followNotifier.follow();
                      debugPrint('🔍 팔로우 서버 요청 완료');
                    }
                  } catch (e) {
                    // 실패 시 롤백
                    if (isFollowing) {
                      followNotifier.optimisticFollow();
                    } else {
                      followNotifier.optimisticUnfollow();
                    }
                    _hasFollowStateChanged = false; // 실패 시 플래그 리셋
                    if (mounted) {
                      setState(() {
                        profile = {
                          ...?profile,
                          'followers': currentFollowers,
                        };
                      });
                      debugPrint('❌ ${isFollowing ? '언팔로우' : '팔로우'} 실패: $e');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${isFollowing ? '언팔로우' : '팔로우'}에 실패했습니다: $e')),
                      );
                    }
                  } finally {
                    if (mounted) {
                      _isFollowActionInProgress = false;
                      debugPrint('🔍 팔로우 액션 완료: ${widget.userId}');
                    }
                  }
                },
                style: _outlinedStyle(context, isFollowing: isFollowing),
                child: isFollowing
                    ? const Text(
                  '팔로잉',
                  style: TextStyle(
                    color: AppColors.black500,
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    height: 1.25,
                  ),
                )
                    : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text(
                      '팔로우 +',
                      style: TextStyle(
                        color: AppColors.black900,
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        height: 1.25,
                      ),
                    ),
                    SizedBox(width: 1.8),

                  ],
                ),
              )
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
            style: const TextStyle(fontSize: 13, color: AppColors.black500)),
        Text('$count',
            style: const TextStyle(fontSize: 13, color: AppColors.black500)),
      ],
    );
  }

  Widget _buildBio(BuildContext context) {
    final bio = profile?['bio'] ?? '';
    const avatarSize = 40.0;
    const horizontalPadding = 22.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth - avatarSize - horizontalPadding;
        return BioContent(bio: bio, maxWidth: availableWidth);
      },
    );
  }

  Future<void> _handleBackNavigation() async {
    debugPrint('🔍 ===== 뒤로가기 처리 시작 =====');
    debugPrint('🔍 팔로우 상태 변경 여부: $_hasFollowStateChanged');
    debugPrint('🔍 mounted: $mounted');

    // 팔로우 상태가 변경되었을 때만 true 반환
    final result = _hasFollowStateChanged ? true : null;
    debugPrint('🔍 Navigator.pop 실행 - result: $result');
    
    if (mounted) {
      debugPrint('🔍 Navigator.pop 호출 전');
      
      // 팔로우 상태가 변경된 경우 네트워크 요청 완료 대기
      if (_hasFollowStateChanged) {
        debugPrint('🔍 팔로우 상태 변경됨 - 네트워크 요청 완료 대기');
        // 릴리즈 모드에서 네트워크 요청 완료를 보장하기 위한 대기
        await Future.delayed(const Duration(milliseconds: 800));
      }
      
      Navigator.pop(context, result);
      debugPrint('🔍 Navigator.pop 호출 후');
    }
  }


}