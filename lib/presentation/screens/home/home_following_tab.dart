import 'dart:convert';
import 'dart:async' show unawaited;
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_logue/core/themes/app_colors.dart';
import 'package:my_logue/core/widgets/post/post_item.dart';
import '../../../core/providers/follow_state_provider.dart';
import '../../../data/models/book_post_model.dart';
import '../../../core/constants/app_constants.dart';

class HomeFollowingTab extends StatefulWidget {
  const HomeFollowingTab({super.key});

  @override
  State<HomeFollowingTab> createState() => _HomeFollowingTabState();
}

/// JSON -> List<Map> 파싱을 메인스레드가 아닌 Isolate에서 수행
List<Map<String, dynamic>> _parseJsonToList(String body) {
  final List raw = jsonDecode(body) as List;
  return raw.cast<Map<String, dynamic>>();
}

/// Map -> Model 변환도 같은 Isolate에서 처리 (연속 변환 시 메모리 압박 낮춤)
List<BookPostModel> _mapsToModels(List<Map<String, dynamic>> list) {
  return list.map((e) => BookPostModel.fromMap(e)).toList();
}

class _HomeFollowingTabState extends State<HomeFollowingTab> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _listKey = GlobalKey(); // 리빌드 시 리스트 트리 재사용 힌트

  List<BookPostModel> _posts = [];

  bool _isInitialLoading = true;
  bool _isFetching = false;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  int _page = 0;
  final int _limit = 10;

  @override
  void initState() {
    super.initState();
    unawaited(_fetchFollowingPosts()); // 첫 로드 비동기 실행
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 400 &&
        !_isFetching &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMorePosts();
    }
  }

  Future<void> _loadMorePosts() async {
    if (_isFetching || _isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    await _fetchFollowingPosts();
    if (mounted) setState(() => _isLoadingMore = false);
  }

  Future<void> _fetchFollowingPosts() async {
    if (mounted) setState(() => _isFetching = true);

    try {
      final client = Supabase.instance.client;
      final accessToken = client.auth.currentSession?.accessToken;

      final uri = Uri.parse(
        'https://tbuoutcwvalrcdlajobk.supabase.co/functions/v1/get-visible-following-posts?page=$_page&limit=$_limit',
      );

      final resp = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      if (resp.statusCode != 200) {
        throw Exception('Edge Function error ${resp.statusCode}');
      }

      // ✅ JSON 파싱을 별도 Isolate로 이동 (안드에서 특히 효과 큼)
      final parsed = await compute(_parseJsonToList, resp.body);
      // ✅ Model 변환도 Isolate에서
      final fetched = await compute(_mapsToModels, parsed);

      if (!mounted) return;

      setState(() {
        _posts.addAll(fetched);
        _page += 1;
        _hasMore = fetched.length == _limit;
        _isInitialLoading = false;
        _isFetching = false;
      });
    } catch (e, stack) {
      debugPrint('🔥 fetchFollowingPosts error: $e\n$stack');
      if (!mounted) return;
      setState(() {
        _isInitialLoading = false;
        _isFetching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitialLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // 비어있을 때
    if (_posts.isEmpty) {
      return Center(
        child: Transform.translate(
          offset: AppConstants.getCenterOffset(context),
          child: const Text(
            "친구를 팔로우해 인생 책을 공유해보세요.",
            style: TextStyle(fontSize: 13, color: AppColors.black500),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // ✅ 전체 리스트를 한 번에 필터링하지 말고, 각 셀에서 Provider를 관찰
    //  - 안드에서 대량 where + watch 다건 호출은 리빌드 시 jank 유발
    return ListView.builder(
      key: _listKey,
      controller: _scrollController,
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 16),
      cacheExtent: 800, // 너무 크게 잡지 않기 (안드 메모리/디코딩 부하 방지)
      addAutomaticKeepAlives: false,
      addRepaintBoundaries: true,
      addSemanticIndexes: false,
      itemCount: _posts.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        // 무한 스크롤 인디케이터
        if (index == _posts.length) {
          return SizedBox(
            height: 64,
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        final post = _posts[index];

        // ✅ 셀 단위로만 followStateProvider watch (리빌드 영향 최소화)
        return Consumer(
          builder: (context, ref, _) {
            final myUserId = Supabase.instance.client.auth.currentUser?.id;
            final isMine = myUserId != null && post.userId == myUserId;
            final isFollowing = isMine
                ? true
                : ref.watch(followStateProvider(post.userId));

            if (!isFollowing) {
              // 보이지 않는 아이템은 아주 얇게 반환해 빌드/레이아웃 비용 최소화
              return const SizedBox.shrink();
            }

            // 실제 셀
            return Padding(
              padding: const EdgeInsets.only(
                left: 22,
                right: 22,
                top: 51,
                bottom: 27,
              ),
              child: RepaintBoundary( // ✅ 복잡한 셀이면 개별 래스터화로 스크롤 부드럽게
                child: PostItem(
                  post: post,
                  isMyPost: false,
                  onEditSuccess: () {
                    // 전체 리셋 후 재로드(필요 시 compute 재사용)
                    setState(() {
                      _isInitialLoading = true;
                      _posts = [];
                      _page = 0;
                      _hasMore = true;
                    });
                    unawaited(_fetchFollowingPosts());
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}