import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:logue/core/themes/app_colors.dart';
import 'package:logue/presentation/screens/home/home_recommand_tab.dart';
import 'package:logue/presentation/screens/home/search/search_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logue/presentation/screens/home/home_following_tab.dart';
import 'package:logue/presentation/screens/home/home_popular_tab.dart';

class HomeMainView extends StatefulWidget {
  const HomeMainView({super.key});

  @override
  State<HomeMainView> createState() => _HomeMainViewState();
}

class _HomeMainViewState extends State<HomeMainView> with TickerProviderStateMixin {
  late final TabController _tabController;
  final List<String> labels = ['추천', '팔로잉', '인기'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: labels.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildTabBar() {
    return Container(
      height: 48,
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.black500, width: 1),
        ),
      ),
      child: Row(
        children: List.generate(labels.length, (index) {
          final isSelected = _tabController.index == index;
          return GestureDetector(
            onTap: () {
              _tabController.animateTo(index);
              setState(() {});
            },
            child: Padding(
              padding: EdgeInsets.only(left: index == 0 ? 11 : 0, right: 15),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 19),
                  Text(
                    labels[index],
                    style: TextStyle(
                      fontWeight: FontWeight.w400,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: labels.length,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(88),
          child: SafeArea( // ⛑️ 상태바 아래로 여백 자동 확보
            child: Padding(
              padding: const EdgeInsets.only(top: 7),
              child: AppBar(
                backgroundColor: Colors.white,
                elevation: 0,
                titleSpacing: 0,
                leadingWidth: 120,
                leading: Padding(
                  padding: const EdgeInsets.only(left: 22),
                  child: SvgPicture.asset('assets/logue_logo.svg', width: 92, height: 28),
                ),
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: IconButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const SearchScreen()),
                        );
                      },
                      icon: IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const SearchScreen()),
                          );
                        },
                        icon: Transform.scale(
                          scale: 1.6, // 👈 원하는 배율로 조정
                          child: SvgPicture.asset(
                            'assets/search_icon.svg',
                            width: 28, // 아이콘 자체 크기
                            height: 28,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(38),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 0), // 👈 간격 줄이고 싶으면 이걸 줄이기
                    child: _buildTabBar(),
                  ),
                ),
              ),
            ),
          ),
        ),
        body: SafeArea( // ⛑️ 오버플로 방지
          child: TabBarView(
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