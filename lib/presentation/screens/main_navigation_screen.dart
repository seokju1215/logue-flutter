import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:logue/core/themes/app_colors.dart';
import 'package:logue/presentation/screens/home/home_screen.dart';
import 'package:logue/presentation/screens/profile/profile_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  final int initialIndex;
  final Widget? child; // ✅ SearchScreen 같은 외부 child

  const MainNavigationScreen({
    Key? key,
    this.initialIndex = 0,
    this.child,
  }) : super(key: key);

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  late int _selectedIndex;
  bool _overrideWithChild = true; // ✅ 처음에만 child 보여줄지 여부

  final List<Widget> _screens = [
    const HomeScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      _overrideWithChild = false; // ✅ 탭 클릭 시 child 무시하고 기본 화면 보여줌
    });
  }

  @override
  Widget build(BuildContext context) {
    final Widget body = (_overrideWithChild && widget.child != null)
        ? widget.child!
        : _screens[_selectedIndex];

    return Scaffold(
      body: body,
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          backgroundColor: Colors.transparent,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: AppColors.black900,
          unselectedItemColor: AppColors.black500,
          selectedLabelStyle: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppColors.black900,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w400,
            color: AppColors.black500,
          ),
          items: [
            BottomNavigationBarItem(
              icon: SvgPicture.asset(
                'assets/home_bottomnavi.svg',
                width: 30,
                height: 30,
                color: _selectedIndex == 0
                    ? AppColors.black900
                    : AppColors.black500,
              ),
              label: '홈',
            ),
            BottomNavigationBarItem(
              icon: SvgPicture.asset(
                'assets/profile_bottomnavi.svg',
                width: 30,
                height: 30,
                color: _selectedIndex == 1
                    ? AppColors.black900
                    : AppColors.black500,
              ),
              label: '프로필',
            ),
          ],
        ),
      ),
    );
  }
}