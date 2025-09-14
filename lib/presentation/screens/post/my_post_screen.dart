import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_svg/svg.dart';
import 'package:my_logue/core/themes/app_colors.dart';
import 'package:my_logue/data/models/book_post_model.dart';
import 'package:my_logue/core/widgets/post/post_item.dart';
import 'package:my_logue/presentation/screens/post/edit_review_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MyBookPostScreen extends StatefulWidget {
  final String? bookId;
  final String? userId;
  final String? userBookId;
  final List<Map<String, dynamic>>? booksData; // ✅ 기존 책 데이터 전달
  const MyBookPostScreen({Key? key, this.bookId, this.userBookId, this.userId, this.booksData}) : super(key: key);

  @override
  State<MyBookPostScreen> createState() => _MyBookPostScreenState();
}

class _MyBookPostScreenState extends State<MyBookPostScreen> {
  final client = Supabase.instance.client;
  final ScrollController _scrollController = ScrollController();

  List<BookPostModel> posts = [];
  List<GlobalKey> _itemKeys = [];

  bool isLoading = true;
  bool _hasDeleted = false;
  int initialIndex = 0;
  bool _isScrollingToTarget = false; // ✅ 특정 책으로 스크롤 중인지 확인

  // 🆕 탭 즉시 로딩 오버레이 상태
  bool _isTapLoading = false;
  static const Duration _minTapOverlay = Duration(milliseconds: 250);

  @override
  void initState() {
    super.initState();
    _fetchPosts();
  }

  Future<void> _fetchPosts() async {
    final userId = widget.userId ?? client.auth.currentUser?.id;

    if (userId == null || !mounted) {
      return;
    }

    try {
      // ✅ 전달된 booksData가 있으면 빠르게 사용
      if (widget.booksData != null && widget.booksData!.isNotEmpty) {
        final mappedPosts = widget.booksData!.map((e) => BookPostModel.fromMap(e)).toList();

        int index = 0;
        bool needsScroll = false;
        if (widget.userBookId != null) {
          final foundIndex = mappedPosts.indexWhere((post) => post.id == widget.userBookId);
          if (foundIndex != -1) { index = foundIndex; needsScroll = true; }
        } else if (widget.bookId != null) {
          final foundIndex = mappedPosts.indexWhere((post) => post.bookId == widget.bookId);
          if (foundIndex != -1) { index = foundIndex; needsScroll = true; }
        }

        if (!mounted) return;

        setState(() {
          posts = mappedPosts;
          initialIndex = index >= 0 ? index : 0;
          _itemKeys = List.generate(mappedPosts.length, (_) => GlobalKey());
          _isScrollingToTarget = needsScroll; // ✅ 스크롤 필요 시 오버레이 켬
          isLoading = false;                   // ✅ 리스트는 즉시 렌더(오버레이로 가림)
        });

        // 스크롤 필요하면 프레임 기준으로 예약
        if (needsScroll) {
          _scheduleTargetScrollIfNeeded();
        }
        return;
      }

      // ✅ 서버에서 가져오기
      final response = await client.rpc('get_visible_user_books', params: {'target_user_id': userId});

      if (!mounted) return;

      if (response.isEmpty) {
        throw Exception('데이터를 불러올 수 없습니다.');
      }

      final fetched = List<Map<String, dynamic>>.from(response);
      final userPosts = fetched.where((e) => e['user_id'] == userId).toList();
      if (userPosts.isEmpty) {
        throw Exception('해당 사용자의 게시글이 없습니다.');
      }

      final mappedPosts = userPosts.map((e) => BookPostModel.fromMap(e)).toList();

      int index = 0;
      bool needsScroll = false;
      if (widget.userBookId != null) {
        final foundIndex = mappedPosts.indexWhere((post) => post.id == widget.userBookId);
        if (foundIndex != -1) { index = foundIndex; needsScroll = true; }
      } else if (widget.bookId != null) {
        final foundIndex = mappedPosts.indexWhere((post) => post.bookId == widget.bookId);
        if (foundIndex != -1) { index = foundIndex; needsScroll = true; }
      }

      if (!mounted) return;

      setState(() {
        posts = mappedPosts;
        initialIndex = index >= 0 ? index : 0;
        _itemKeys = List.generate(mappedPosts.length, (_) => GlobalKey());
        _isScrollingToTarget = needsScroll; // ✅ 여기서도 오버레이 켬
        isLoading = false;                   // ✅ 리스트 즉시 렌더
      });

      // 스크롤 필요하면 프레임 기준으로 예약
      if (needsScroll) {
        _scheduleTargetScrollIfNeeded();
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  /// 프레임이 끝날 때까지 N번 대기 (레이아웃/빌드가 마무리되도록)
  Future<void> _waitFrames(int count) async {
    for (int i = 0; i < count; i++) {
      await WidgetsBinding.instance.endOfFrame; // 현재 프레임 끝날 때까지
    }
  }

  /// 타겟 아이템이 빌드/레이아웃 된 뒤에 스크롤을 보장하는 안정형 함수
  Future<void> _scrollToInitialIndexStable({int maxTries = 5}) async {
    // 1) 최소 한 프레임은 반드시 보장 (첫 빌드 끝)
    await _waitFrames(1);

    for (int tryIdx = 0; tryIdx < maxTries; tryIdx++) {
      if (!mounted) return;

      // 키가 준비되었는지 확인
      if (_scrollController.hasClients &&
          initialIndex < _itemKeys.length &&
          _itemKeys[initialIndex].currentContext != null) {
        try {
          final keyContext = _itemKeys[initialIndex].currentContext!;
          Scrollable.ensureVisible(
            keyContext,
            duration: Duration.zero, // 애니메이션 없이 즉시
            alignment: 0.1,
          );

          // 스크롤 직후 한 프레임 기다려서 화면 안정화
          await _waitFrames(1);

          if (mounted) {
            setState(() {
              _isScrollingToTarget = false; // 오버레이 해제
              isLoading = false;
            });
          }
          return;
        } catch (_) {
          // 스크롤 실패 시 다음 프레임에서 재시도
        }
      }

      // 아직 준비가 덜 되었으면 다음 프레임까지 대기하고 재시도
      await _waitFrames(1);
    }

    // 여기까지 왔으면 실패—그래도 오버레이는 걷어내자(UX 보장)
    if (mounted) {
      setState(() {
        _isScrollingToTarget = false;
        isLoading = false;
      });
    }
  }

  /// 프레임과 동기화해서 스크롤을 예약
  void _scheduleTargetScrollIfNeeded() {
    if (!_isScrollingToTarget) return;

    // 첫 프레임 커밋 이후에 실행하도록 예약
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollToInitialIndexStable();
    });
  }

  // 🆕 공통 헬퍼: 탭 오버레이를 최소 시간 보장하며 표시
  // 🆕 공통 헬퍼: 탭 오버레이를 최소 시간 보장하며 표시
  Future<T?> _runWithTapLoading<T>(Future<T?> Function() task) async {
    if (!mounted) return await task();
    final startedAt = DateTime.now();
    setState(() => _isTapLoading = true);

    T? result;
    Object? error;
    try {
      result = await task();
    } catch (e) {
      error = e;
    }

    // 최소 노출 시간 보장
    final elapsed = DateTime.now().difference(startedAt);
    if (elapsed < _minTapOverlay) {
      await Future.delayed(_minTapOverlay - elapsed);
    }

    if (mounted) setState(() => _isTapLoading = false);

    if (error != null) throw error; // ✅ 여기서 rethrow 대신 throw 사용
    return result;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String appBarTitle = (posts.isNotEmpty && posts[initialIndex.clamp(0, posts.length - 1)].userName != null)
        ? posts[initialIndex.clamp(0, posts.length - 1)].userName!
        : '사용자';

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        title: Text(
          appBarTitle,
          style: const TextStyle(fontSize: 16, color: AppColors.black900, fontWeight: FontWeight.w500),
        ),
        leading: IconButton(
          icon: SvgPicture.asset('assets/back_arrow.svg'),
          onPressed: () => Navigator.pop(context, _hasDeleted),
        ),
      ),
      body: Stack(
        children: [
          // ✅ 리스트는 항상 렌더 (키 컨텍스트 확보)
          ListView(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(vertical: 16),
            cacheExtent: 5000,
            children: List.generate(posts.length, (index) {
              final post = posts[index];
              final currentUserId = client.auth.currentUser?.id;
              final isMyPost = currentUserId != null && currentUserId == post.userId;

              return KeyedSubtree(
                key: _itemKeys.length > index ? _itemKeys[index] : GlobalKey(),
                child: Padding(
                  padding: const EdgeInsets.only(left: 22, right: 22, top: 51, bottom: 27),
                  child: PostItem(
                    isMyPost: false,
                    post: post,
                    onDeleteSuccess: () {
                      setState(() {
                        posts.removeAt(index);
                        if (_itemKeys.length > index) _itemKeys.removeAt(index);
                        _hasDeleted = true;
                      });
                      Navigator.pop(context, true);
                    },
                    onArchiveSuccess: () {
                      setState(() {
                        posts.removeAt(index);
                        if (_itemKeys.length > index) _itemKeys.removeAt(index);
                        _hasDeleted = true;
                      });
                    },
                    onEditSuccess: () async {
                      // 🆕 편집 화면으로 이동할 때도 탭 로딩 오버레이 적용
                      final result = await _runWithTapLoading(() {
                        return Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EditReviewScreen(
                              post: post,
                              fromScreen: 'my_post_screen',
                            ),
                          ),
                        );
                      });
                      if (result == true) {
                        await _fetchPosts();
                        if (mounted) setState(() => _hasDeleted = true);
                      }
                    },
                    onTap: () async {
                      // 🆕 상세 화면으로 이동 시 즉시 로딩 오버레이 표시
                      final result = await _runWithTapLoading(() {
                        return Navigator.pushNamed(
                          context,
                          '/post_detail',
                          arguments: post,
                        );
                      });
                      if (result == true) {
                        await _fetchPosts();
                        if (mounted) setState(() => _hasDeleted = true);
                      }
                    },
                  ),
                ),
              );
            }),
          ),

          // ✅ 초기 데이터 로딩 오버레이 (posts 비어있을 때 등)
          if (isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.white,
                child: const Center(
                  child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.black)),
                ),
              ),
            ),

          // ✅ 타겟 스크롤 완료 전까지 화면을 가리는 오버레이 (깜빡임 방지)
          if (_isScrollingToTarget)
            Positioned.fill(
              child: Container(
                color: Colors.white,
                child: const Center(
                  child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.black)),
                ),
              ),
            ),

          // 🆕 탭 직후 잠깐 보여주는 로딩 오버레이
          if (_isTapLoading)
            Positioned.fill(
              child: Container(
                color: Colors.white.withOpacity(0.85),
                child: const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}