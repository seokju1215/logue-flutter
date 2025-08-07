import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:my_logue/core/themes/app_colors.dart';
import 'package:my_logue/data/models/book_post_model.dart';
import 'package:my_logue/core/widgets/post/post_item.dart';
import 'package:my_logue/presentation/screens/post/edit_review_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SinglePostScreen extends StatefulWidget {
  final String bookId;
  final String userBookId;
  final String? userId;

  const SinglePostScreen({
    Key? key, 
    required this.bookId, 
    required this.userBookId, 
    this.userId
  }) : super(key: key);

  @override
  State<SinglePostScreen> createState() => _SinglePostScreenState();
}

class _SinglePostScreenState extends State<SinglePostScreen> {
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
    if (userId == null || !mounted) return;

    try {
      final response = await client
          .rpc('get_user_books', params: {'target_user_id': userId});

      if (!mounted) return;

      if (response.isEmpty) throw Exception('데이터를 불러올 수 없습니다.');

      final fetched = List<Map<String, dynamic>>.from(response);
      final userPosts = fetched.where((e) => e['user_id'] == userId).toList();
      final mappedPosts = userPosts.map((e) => BookPostModel.fromMap(e)).toList();

      // 특정 userBookId에 해당하는 포스트만 필터링
      final filteredPosts = mappedPosts.where((post) => post.id == widget.userBookId).toList();

      if (!mounted) return;

      setState(() {
        posts = filteredPosts;
        _itemKeys = List.generate(filteredPosts.length, (_) => GlobalKey());
        isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ 게시글 불러오기 실패: $e');
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: SvgPicture.asset('assets/back_arrow.svg'),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '보관함',
          style: TextStyle(
            fontSize: 16,
            color: AppColors.black900,
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : posts.isEmpty
              ? const Center(
                  child: Text(
                    '포스트가 없습니다.',
                    style: TextStyle(fontSize: 14, color: AppColors.black500),
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  cacheExtent: 5000,
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
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
                          isMyPost: isMyPost,
                          post: post,
                          fromScreen: 'single_post_screen',
                          onDeleteSuccess: () {
                            setState(() {
                              posts.removeAt(index);
                              _itemKeys.removeAt(index);
                              _hasDeleted = true;
                            });
                            Navigator.pop(context, true);
                          },
                          onEditSuccess: () async {
                            // single_post_screen에서 직접 편집 화면 호출
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => EditReviewScreen(
                                  post: post,
                                  fromScreen: 'single_post_screen',
                                ),
                              ),
                            );
                            if (result == true) {
                              await _fetchPosts();
                              setState(() {});
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
                  },
                ),
    );
  }
} 