import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logue/core/themes/app_colors.dart';
import 'package:logue/core/widgets/post/post_item.dart';
import '../../../core/providers/follow_state_provider.dart';
import '../../../data/models/book_post_model.dart';

class HomeFollowingTab extends StatefulWidget {
  const HomeFollowingTab({super.key});

  @override
  State<HomeFollowingTab> createState() => _HomeFollowingTabState();
}

class _HomeFollowingTabState extends State<HomeFollowingTab> {
  final ScrollController _scrollController = ScrollController();
  List<BookPostModel> posts = [];

  bool isLoading = true;
  bool isFetching = false;
  bool hasMore = true;

  int page = 0;
  final int limit = 10;

  @override
  void initState() {
    super.initState();
    fetchFollowingPosts();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200 &&
          !isFetching &&
          hasMore) {
        fetchFollowingPosts();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> fetchFollowingPosts() async {
    setState(() {
      isFetching = true;
    });

    try {
      final client = Supabase.instance.client;
      final accessToken = client.auth.currentSession?.accessToken;

      final response = await http.get(
        Uri.parse(
          'https://tbuoutcwvalrcdlajobk.supabase.co/functions/v1/following-posts?page=$page&limit=$limit',
        ),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        final List<BookPostModel> fetched =
        data.map((e) => BookPostModel.fromMap(e)).toList();

        setState(() {
          posts.addAll(fetched);
          page += 1;
          hasMore = fetched.length == limit;
          isLoading = false;
          isFetching = false;
        });
      } else {
        throw Exception('Edge Function error ${response.statusCode}');
      }
    } catch (e, stack) {
      print('🔥 fetchFollowingPosts error: $e');
      print(stack);
      setState(() {
        isLoading = false;
        isFetching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final myUserId = Supabase.instance.client.auth.currentUser!.id;

        // 팔로우 상태 확인
        final filteredPosts = posts.where((post) {
          final userId = post.userId;
          if (userId == myUserId) return true; // 내 글은 항상 보여줌
          return ref.watch(followStateProvider(userId));
        }).toList();

        if (isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (filteredPosts.isEmpty) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: const [
              Text(
                "친구를 팔로우해 서로의 인생 책을 공유해보세요",
                style: TextStyle(fontSize: 12, color: AppColors.black500),
              ),
              SizedBox(height: 50),
            ],
          );
        }

        return ListView.separated(
          controller: _scrollController,
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
          itemCount: filteredPosts.length + (hasMore ? 1 : 0),
          separatorBuilder: (_, __) => const SizedBox(height: 40),
          itemBuilder: (context, index) {
            if (index == filteredPosts.length) {
              // 로딩 인디케이터 (무한 스크롤)
              return const Center(child: CircularProgressIndicator());
            }

            final post = filteredPosts[index];
            return PostItem(
              post: post,
              isMyPost: false,
              onEditSuccess: () {
                setState(() {
                  isLoading = true;
                  posts = [];
                  page = 0;
                  hasMore = true;
                });
                fetchFollowingPosts();
              },
            );
          },
        );
      },
    );
  }
}