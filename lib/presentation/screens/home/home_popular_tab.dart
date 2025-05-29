import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logue/core/widgets/banner/banner_slider.dart';
import 'package:logue/data/models/book_post_model.dart';
import 'package:logue/core/widgets/book/book_ranking_slider.dart';

class HomePopularTab extends StatefulWidget {
  const HomePopularTab({super.key});

  @override
  State<HomePopularTab> createState() => _HomePopularTabState();
}

class _HomePopularTabState extends State<HomePopularTab> {
  final client = Supabase.instance.client;
  List<Map<String, dynamic>> banners = [];
  List<BookPostModel> posts = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  List<Map<String, dynamic>> rankedBooks = [];

  Future<void> fetchData() async {
    try {
      final bannerRes = await client
          .from('banner_ads')
          .select()
          .order('order_index', ascending: true);

      final rankingRes = await client
          .from('book_ranking')
          .select()
          .order('count', ascending: false)
          .limit(15);

      setState(() {
        banners = List<Map<String, dynamic>>.from(bannerRes);
        rankedBooks = List<Map<String, dynamic>>.from(rankingRes);
        isLoading = false;
      });
    } catch (e) {
      debugPrint('🔥 fetch popular data error: $e');
    }
  }


  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      children: [
        if (banners.isNotEmpty)
          BannerSlider(banners: banners),
        const SizedBox(height: 12),
        if (rankedBooks.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: SizedBox(
              height: 460,
              child: BookRankingSlider(books: rankedBooks),
            ),
          ),
      ],
    );
  }
}