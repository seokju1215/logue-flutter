import 'package:flutter/material.dart';
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
  const MyBookPostScreen({Key? key, this.bookId, this.userBookId, this.userId}) : super(key: key);

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

  @override
  void initState() {
    super.initState();
    _fetchPosts();
  }

  Future<void> _fetchPosts() async {
    final userId = widget.userId ?? client.auth.currentUser?.id;
    debugPrint('🔍 MyBookPostScreen - userId: $userId, bookId: ${widget.bookId}, userBookId: ${widget.userBookId}');
    
    if (userId == null || !mounted) {
      debugPrint('❌ userId가 null이거나 mounted가 false입니다.');
      return;
    }

    try {
      debugPrint('🔍 get_visible_user_books 호출 중...');
      final response = await client
          .rpc('get_visible_user_books', params: {'target_user_id': userId});

      if (!mounted) return;

      debugPrint('🔍 응답 데이터: ${response.length}개 항목');
      
      // response 자체가 List<dynamic>
      if (response.isEmpty) {
        debugPrint('❌ 응답이 비어있습니다.');
        throw Exception('데이터를 불러올 수 없습니다.');
      }

      final fetched = List<Map<String, dynamic>>.from(response);
      debugPrint('🔍 변환된 데이터: ${fetched.length}개 항목');
      
      final userPosts = fetched.where((e) => e['user_id'] == userId).toList();
      debugPrint('🔍 해당 사용자 포스트: ${userPosts.length}개');
      
      if (userPosts.isEmpty) {
        debugPrint('❌ 해당 사용자의 포스트가 없습니다.');
        throw Exception('해당 사용자의 게시글이 없습니다.');
      }
      
      final mappedPosts = userPosts.map((e) {
        final post = BookPostModel.fromMap(e);
        return post;
      }).toList();

      int index = 0;
      if (widget.userBookId != null) {
        debugPrint('🔍 userBookId로 검색: ${widget.userBookId}');
        final foundIndex = mappedPosts.indexWhere((post) => post.id == widget.userBookId);
        if (foundIndex != -1) {
          index = foundIndex;
          debugPrint('✅ userBookId로 찾은 인덱스: $index');
        } else {
          debugPrint('❌ userBookId로 찾을 수 없음');
        }
      } else if (widget.bookId != null) {
        debugPrint('🔍 bookId로 검색: ${widget.bookId}');
        final foundIndex = mappedPosts.indexWhere((post) => post.bookId == widget.bookId);
        if (foundIndex != -1) {
          index = foundIndex;
          debugPrint('✅ bookId로 찾은 인덱스: $index');
        } else {
          debugPrint('❌ bookId로 찾을 수 없음');
        }
      }

      if (!mounted) return;

      debugPrint('🔍 최종 설정 - posts: ${mappedPosts.length}개, initialIndex: $index');
      
      setState(() {
        posts = mappedPosts;
        initialIndex = index >= 0 ? index : 0;
        _itemKeys = List.generate(mappedPosts.length, (_) => GlobalKey());
        isLoading = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToInitialIndex());
    } catch (e) {
      debugPrint('❌ 게시글 불러오기 실패: $e');
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _scrollToInitialIndex() async {
    await Future.delayed(const Duration(milliseconds: 120));

    if (_scrollController.hasClients && initialIndex < _itemKeys.length) {
      final keyContext = _itemKeys[initialIndex].currentContext;
      if (keyContext != null) {
        Scrollable.ensureVisible(
          keyContext,
          duration: Duration.zero,
          alignment: 0.1, // 상단에 가깝게 붙이기
        );
      }
    }
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
        title: Text(appBarTitle, style: const TextStyle(fontSize: 16, color: AppColors.black900, fontWeight: FontWeight.w500,)),
        leading: IconButton(
          icon: SvgPicture.asset('assets/back_arrow.svg'),
          onPressed: () => Navigator.pop(context, _hasDeleted),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(vertical: 16),
        cacheExtent: 5000,
        children: List.generate(posts.length, (index) {
          final post = posts[index];
          final currentUserId = client.auth.currentUser?.id;
          final isMyPost = currentUserId != null && currentUserId == post.userId;

          return KeyedSubtree(
            key: _itemKeys[index],
            child: Padding(
              padding: const EdgeInsets.only(
                left: 22,
                right: 22,
                top: 51,
                bottom: 27,
              ),
                                      child: PostItem(
                          isMyPost: false,
                          post: post,
                          onDeleteSuccess: () {
                            setState(() {
                              posts.removeAt(index);
                              _itemKeys.removeAt(index);
                              _hasDeleted = true;
                            });
                            Navigator.pop(context, true);
                          },
                          onArchiveSuccess: () {
                            setState(() {
                              posts.removeAt(index);
                              _itemKeys.removeAt(index);
                              _hasDeleted = true;
                            });
                            // 보관함으로 이동한 경우에는 Navigator.pop을 호출하지 않음
                          },
                          onEditSuccess: () async {
                            // my_post_screen에서 직접 편집 화면 호출
                            final result = await Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => EditReviewScreen(
                                  post: post,
                                  fromScreen: 'my_post_screen',
                                ),
                              ),
                            );
                            if (result == true) {
                              await _fetchPosts();
                              setState(() => _hasDeleted = true);
                            }
                          },
                onTap: () async {
                  final result = await Navigator.pushNamed(
                    context,
                    '/post_detail',
                    arguments: post,
                  );

                  if (result == true) {
                    await _fetchPosts();
                    setState(() => _hasDeleted = true);
                  }
                },
              ),
            ),
          );
        }),
      ),
    );
  }
}