import 'package:flutter/material.dart';
import 'package:logue/core/themes/app_colors.dart';
import 'package:flutter_svg/flutter_svg.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          automaticallyImplyLeading: false,
          titleSpacing: 0, // 👈 로고가 왼쪽에 딱 붙게
          title: Padding(
            padding: const EdgeInsets.only(left: 20), // ← 로고 왼쪽 여백
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
            preferredSize: const Size.fromHeight(48),
            child: Container(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(left: 20), // 👈 탭바 전체 왼쪽 여백
              child: TabBar(
                isScrollable: true,
                labelPadding: const EdgeInsets.only(right: 24), // 👈 탭 간 간격
                labelColor: Colors.black,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Colors.black,
                indicatorWeight: 2.0,
                indicatorSize: TabBarIndicatorSize.label,
                overlayColor: const MaterialStatePropertyAll(Colors.transparent),
                splashFactory: NoSplash.splashFactory,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                tabs: const [
                  Tab(text: '추천'),
                  Tab(text: '팔로잉'),
                  Tab(text: '인기'),
                ],
              ),
            ),
          ),
        ),
        body: const TabBarView(
          physics: NeverScrollableScrollPhysics(), // 👉 옆으로 넘기는 제스처 제거
          children: [
            Center(child: Text('추천 탭')),
            Center(child: Text('팔로잉 탭')),
            Center(child: Text('인기 탭')),
          ],
        ),
      ),
    );
  }
}