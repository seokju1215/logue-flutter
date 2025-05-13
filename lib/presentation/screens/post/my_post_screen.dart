import 'package:flutter/material.dart';
import 'package:logue/core/themes/app_colors.dart';
import 'package:logue/data/models/book_post_model.dart';
import 'package:logue/core/widgets/post/post_item.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logue/presentation/screens/post/comment_screen.dart';
class MyBookPostScreen extends StatefulWidget {
  final String bookId;

  const MyBookPostScreen({Key? key, required this.bookId}) : super(key: key);

  @override
  State<MyBookPostScreen> createState() => _MyBookPostScreenState();
}

class _MyBookPostScreenState extends State<MyBookPostScreen> {
  final client = Supabase.instance.client;
  List<BookPostModel> posts = [];
  bool isLoading = true;
  final ScrollController _scrollController = ScrollController();
  int initialIndex = 0;

  @override
  void initState() {
    super.initState();
    _fetchPosts();
  }

  Future<void> _fetchPosts() async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final response = await client
          .rpc('get_user_books_with_profiles') // Supabase Function 호출
          .execute();

      if (response.data == null) {
        throw Exception('데이터를 불러올 수 없습니다.');
      }

      final fetched = List<Map<String, dynamic>>.from(response.data);

      final userPosts = fetched.where((e) => e['user_id'] == userId).toList();
      final mappedPosts = userPosts.map((e) => BookPostModel.fromMap(e)).toList();


      // ✅ 정렬 이후 클릭한 책(bookId)의 인덱스 찾기
      final index = mappedPosts.indexWhere((post) => post.id == widget.bookId);

      setState(() {
        posts = mappedPosts;
        initialIndex = index >= 0 ? index : 0;
        isLoading = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(initialIndex * 450); // 대략 하나 높이
        }
      });
    } catch (e) {
      debugPrint('❌ 게시글 불러오기 실패: $e');
      if (mounted) setState(() => isLoading = false);
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
        backgroundColor: Colors.white, // 배경 흰색
        elevation: 0,                  // 그림자 제거
        surfaceTintColor: Colors.white,
        title: Text(appBarTitle, style: TextStyle(fontSize: 18, color: AppColors.black900),),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(vertical: 16),
        itemCount: posts.length,
        itemBuilder: (context, index) {
          final post = posts[index];
          final isMyPost = post.userId == client.auth.currentUser?.id;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
            child: PostItem(
              isMyPost: isMyPost,
              post: post,
              onTapComment: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CommentScreen(post: post),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}