import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:logue/core/themes/app_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logue/core/widgets/post/post_item.dart';
import '../../../data/models/book_post_model.dart';

class HomeFollowingTab extends StatefulWidget {
  const HomeFollowingTab({super.key});

  @override
  State<HomeFollowingTab> createState() => _HomeFollowingTabState();
}

class _HomeFollowingTabState extends State<HomeFollowingTab> {
  List<BookPostModel> posts = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchFollowingPosts();
  }

  Future<void> fetchFollowingPosts() async {
    try {
      final client = Supabase.instance.client;
      final accessToken = client.auth.currentSession?.accessToken;

      final response = await http.get(
        Uri.parse('https://tbuoutcwvalrcdlajobk.supabase.co/functions/v1/following-posts'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        setState(() {
          posts = data.map((e) => BookPostModel.fromMap(e)).toList();
          isLoading = false;
        });
      } else {
        throw Exception('Edge Function error ${response.statusCode}');
      }
    } catch (e, stack) {
      print('🔥 fetchFollowingPosts error: $e');
      print(stack);
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (posts.isEmpty) {
      return const Center(
        child: Text(
          '친구를 추가해 서로의 인생 책을 공유해보세요',
          style: TextStyle(color: AppColors.black500, fontSize: 12),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      itemCount: posts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 40),
      itemBuilder: (context, index) {
        return PostItem(
          post: posts[index],
          isMyPost: false,
        );
      },
    );
  }
}