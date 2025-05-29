import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logue/core/widgets/banner/banner_slider.dart';
import 'package:logue/data/models/book_post_model.dart';

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

  Future<void> fetchData() async {
    try {
      final bannerRes = await client
          .from('banner_ads')
          .select()
          .order('order_index', ascending: true);


      setState(() {
        banners = List<Map<String, dynamic>>.from(bannerRes);
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
      ],
    );
  }
}