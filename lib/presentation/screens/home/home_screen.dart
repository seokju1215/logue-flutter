import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:logue/core/themes/app_colors.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(left: 20),
          child: SvgPicture.asset(
            'assets/logue_logo.svg',
            height: 24,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.pushNamed(context, '/search');
            },
            icon: const Icon(Icons.search, color: Colors.black, size: 28),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(80),
          child: Stack(
            children: [
              // ⚫ 얇은 전체 구분선
              const Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: AppColors.black500
                ),
              ),
              // ⚫ 커스텀 탭바
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
                      padding: EdgeInsets.only(
                        left: index == 0 ? 11 : 0,
                        right: 0,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(height: 19), // 여유 공간 위에 줌
                          Text(
                            labels[index],
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isSelected ? AppColors.black900 : AppColors.black500,
                              fontSize: 14
                            ),
                          ),
                          const SizedBox(height: 6), // 텍스트와 밑줄 간격
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
      ),
      body: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(),
        children: const [
          Center(child: Text('추천 탭')),
          Center(child: Text('팔로잉 탭')),
          Center(child: Text('인기 탭')),
        ],
      ),
    );
  }
}