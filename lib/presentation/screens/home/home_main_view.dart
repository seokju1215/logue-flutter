import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:my_logue/core/themes/app_colors.dart';
import 'package:my_logue/presentation/screens/home/home_recommand_tab.dart';
import 'package:my_logue/presentation/screens/home/search/search_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_logue/presentation/screens/home/home_following_tab.dart';
import 'package:my_logue/presentation/screens/home/home_popular_tab.dart';
import '../../../data/utils/mixpanel_util.dart';

class HomeMainView extends StatefulWidget {
  const HomeMainView({super.key, this.initialTab = 0});

  /// 0=추천, 1=팔로잉, 2=인기
  final int initialTab;

  @override
  State<HomeMainView> createState() => _HomeMainViewState();
}

class _HomeMainViewState extends State<HomeMainView> with TickerProviderStateMixin {
  late final PageController _pageController;
  final List<String> labels = ['추천', '팔로잉', '인기'];
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = (widget.initialTab >= 0 && widget.initialTab < labels.length)
        ? widget.initialTab
        : 0;
    _pageController = PageController(initialPage: _currentIndex);

    // 홈 화면 방문 트래킹
    MixpanelUtil.trackScreenView('Home');
  }

  @override
  void dispose() {
    _pageController.dispose();
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
          final isSelected = _currentIndex == index;
          return GestureDetector(
            onTap: () {
              _pageController.animateToPage(
                index,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
              setState(() {
                _currentIndex = index;
              });
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
                  Container(
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(88),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(top: 7),
            child: AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              titleSpacing: 0,
              leadingWidth: 120,
              leading: Padding(
                padding: const EdgeInsets.only(left: 22, top: 12),
                child: SvgPicture.asset('assets/logue_logo.svg', width: 92, height: 28),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 16, top: 12),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SearchScreen()),
                      );
                    },
                    child: Transform.scale(
                      scale: 1.4,
                      child: SvgPicture.asset(
                        'assets/search_icon.svg',
                        width: 32,
                        height: 32,
                      ),
                    ),
                  ),
                ),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(38),
                child: Padding(
                  padding: const EdgeInsets.only(top: 0),
                  child: _buildTabBar(),
                ),
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: PageView(
          controller: _pageController,
          onPageChanged: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          children: const [
            HomeRecommendTab(),
            HomeFollowingTab(),
            HomePopularTab(),
          ],
        ),
      ),
    );
  }
}