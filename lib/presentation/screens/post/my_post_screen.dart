import 'package:flutter/material.dart';
import 'package:logue/core/themes/app_colors.dart';
import 'package:logue/data/models/book_post_model.dart';
import 'package:logue/core/widgets/post/post_item.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MyBookPostScreen extends StatefulWidget {
  final String bookId;
  final String? userId;

  const MyBookPostScreen({Key? key, required this.bookId, this.userId}) : super(key: key);

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
    if (userId == null) return;

    try {
      final response = await client
          .rpc('get_user_books_with_profiles', params: {'target_user_id': userId})
          .execute();

      if (response.data == null) throw Exception('데이터를 불러올 수 없습니다.');

      final fetched = List<Map<String, dynamic>>.from(response.data);
      final userPosts = fetched.where((e) => e['user_id'] == userId).toList();
      final mappedPosts = userPosts.map((e) => BookPostModel.fromMap(e)).toList();

      debugPrint('📌 전달받은 bookId: ${widget.bookId}');
      debugPrint('📌 mappedPosts: ${mappedPosts.map((e) => e.bookId)}');

      final index = mappedPosts.indexWhere((post) => post.bookId == widget.bookId);

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
    await Future.delayed(const Duration(milliseconds: 10));
    if (_scrollController.hasClients) {
      final RenderBox? firstItemBox = _itemKeys.first.currentContext?.findRenderObject() as RenderBox?;
      final RenderBox? targetBox = _itemKeys[initialIndex].currentContext?.findRenderObject() as RenderBox?;

      if (firstItemBox != null && targetBox != null) {
        final offset = targetBox.localToGlobal(Offset.zero).dy - firstItemBox.localToGlobal(Offset.zero).dy;
        _scrollController.jumpTo(offset);
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
    final String appBarTitle = (posts.isNotEmpty && posts[initialIndex].userName != null)
        ? posts[initialIndex].userName!
        : '사용자';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        title: Text(appBarTitle, style: const TextStyle(fontSize: 18, color: AppColors.black900)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context, _hasDeleted),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(vertical: 16),
        cacheExtent: 2000,
        children: List.generate(posts.length, (index) {
          final post = posts[index];
          final currentUserId = client.auth.currentUser?.id;
          final isMyPost = currentUserId != null && currentUserId == post.userId;

          return KeyedSubtree(
            key: _itemKeys[index],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
              child: PostItem(
                isMyPost: isMyPost,
                post: post,
                onDeleteSuccess: () {
                  setState(() {
                    posts.removeAt(index);
                    _itemKeys.removeAt(index);
                    _hasDeleted = true;
                  });
                  if (posts.isEmpty) {
                    Navigator.pop(context, true);
                  }
                },
                onEditSuccess: _fetchPosts,
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