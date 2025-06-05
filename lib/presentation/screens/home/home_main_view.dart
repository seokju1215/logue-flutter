import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:logue/core/themes/app_colors.dart';
import 'package:logue/presentation/screens/home/home_recommand_tab.dart';
import 'package:logue/presentation/screens/home/search/search_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logue/presentation/screens/home/home_following_tab.dart';
import 'package:logue/presentation/screens/home/home_popular_tab.dart';

import '../main_navigation_screen.dart';

class HomeMainView extends StatefulWidget {
  const HomeMainView({super.key});

  @override
  State<HomeMainView> createState() => _HomeMainViewState();
}

class _HomeMainViewState extends State<HomeMainView> with TickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: NestedScrollView(
          floatHeaderSlivers: true,
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverAppBar(
              surfaceTintColor: Colors.white,
              backgroundColor: Colors.white,
              floating: true,
              snap: true,
              pinned: false,
              elevation: 0,
              titleSpacing: 0, // ✅ leading과의 간격 제거
              leadingWidth: 120,
              leading: Padding(
                padding: const EdgeInsets.only(left: 20),
                child: GestureDetector(
                  onTap: () async {
                    await Supabase.instance.client.auth.signOut();
                    if (context.mounted) {
                      Navigator.pushReplacementNamed(context, '/splash');
                    }
                  },
                  child: SvgPicture.asset('assets/logue_logo.svg', width: 92, height: 28,),
                ),
              ),
              title: const SizedBox(),
              actions: [
                IconButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SearchScreen(), // 또는 BookDetailScreen(...)
                      ),
                    );
                  },
                  icon: const Icon(Icons.search, color: Colors.black, size: 28),
                ),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(40),
                child: Stack(
                  children: [
                    const Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Divider(height: 1, thickness: 1, color: AppColors.black500),
                    ),
                    Row(
                      children: List.generate(3, (index) {
                        final labels = ['추천', '팔로잉', '인기'];
                        final isSelected = _tabController.index == index;

                        return GestureDetector(
                          onTap: () {
                            _tabController.animateTo(index);
                            setState(() {});
                          },
                          child: Padding(
                            padding: EdgeInsets.only(left: index == 0 ? 11 : 0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const SizedBox(height: 19),
                                Text(
                                  labels[index],
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? AppColors.black900 : AppColors.black500,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  height: 2,
                                  width: 56,
                                  color: isSelected ? AppColors.black900 : Colors.transparent,
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
            )
          ],
          body: TabBarView(
            controller: _tabController,
            physics: const NeverScrollableScrollPhysics(),
            children: const [
              HomeRecommendTab(),
              HomeFollowingTab(),
              HomePopularTab(),
            ],
          ),
        ),
      ),
    );
  }
}