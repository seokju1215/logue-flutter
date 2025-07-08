import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:my_logue/core/themes/app_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_logue/core/widgets/post/post_item.dart';
import '../../../data/models/book_post_model.dart';

class HomeRecommendTab extends StatefulWidget {
  const HomeRecommendTab({super.key});

  @override
  State<HomeRecommendTab> createState() => _HomeRecommendTabState();
}

class _HomeRecommendTabState extends State<HomeRecommendTab> {
  final List<BookPostModel> posts = [];
  final ScrollController _scrollController = ScrollController();

  final int _limit = 10;
  bool _hasMore = true;
  bool _isFetching = false;
  bool isInitialLoading = true;
  int _offset = 0;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    fetchPosts();

    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 500 &&
        !_isFetching &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMorePosts();
    }
  }

  Future<void> _loadMorePosts() async {
    if (_isFetching || _isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);
    await fetchPosts();
    setState(() => _isLoadingMore = false);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> fetchPosts() async {
    if (_isFetching || !_hasMore) return;

    setState(() => _isFetching = true);

    try {
      final client = Supabase.instance.client;
      final accessToken = client.auth.currentSession?.accessToken;

      final response = await http.get(
        Uri.parse(
          'https://tbuoutcwvalrcdlajobk.supabase.co/functions/v1/rapid-function?startOffset=$_offset&limit=$_limit',
        ),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        final List data = result['posts'] ?? [];

        final fetchedPosts =
        data.map((e) => BookPostModel.fromMap(e)).toList();

        if (mounted) {
          setState(() {
            posts.addAll(fetchedPosts);
            _offset = result['nextOffset'] ?? _offset;
            _hasMore = result['nextOffset'] != null;
            isInitialLoading = false;
            _isFetching = false;
          });
        }
      } else {
        throw Exception('Edge Function error ${response.statusCode}');
      }
    } catch (e) {
      print('🔥 fetchPosts error: $e');
      if (mounted) {
        setState(() {
          _isFetching = false;
          isInitialLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isInitialLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (posts.isEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: const [
          Text(
            "추천할 후기가 아직 없어요",
            style:
            TextStyle(fontSize: 12, color: AppColors.black500),
          ),
          SizedBox(height: 50,)
        ],
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 16),
      cacheExtent: 1000,
      itemCount: posts.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == posts.length) {
          return Container(
            height: 60,
            alignment: Alignment.center,
            child: const CircularProgressIndicator(),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(
            left: 22,
            right: 22,
            top: 51,
            bottom: 27,
          ),
          child: PostItem(post: posts[index], isMyPost: false),
        );
      },
    );
  }
}