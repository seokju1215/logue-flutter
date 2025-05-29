import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logue/core/widgets/post/post_item.dart';
import '../../../data/models/book_post_model.dart';

class HomeRecommendTab extends StatefulWidget {
  const HomeRecommendTab({super.key});

  @override
  State<HomeRecommendTab> createState() => _HomeRecommendTabState();
}

class _HomeRecommendTabState extends State<HomeRecommendTab> {
  List<BookPostModel> posts = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchPosts();
  }

  Future<void> fetchPosts() async {
    try {
      final client = Supabase.instance.client;
      final accessToken = client.auth.currentSession?.accessToken;


      final response = await http.get(
        Uri.parse('https://tbuoutcwvalrcdlajobk.supabase.co/functions/v1/rapid-function'),
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
      print('🔥 fetchPosts error: $e');
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
          '추천할 후기가 아직 없어요 😢',
          style: TextStyle(color: Colors.grey, fontSize: 16),
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