import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:logue/core/themes/app_colors.dart';
import 'package:logue/presentation/screens/home/home_screen.dart';
import 'package:logue/presentation/screens/profile/profile_view.dart';
import 'package:logue/presentation/screens/post/my_post_screen.dart';

import '../../data/utils/announcement_dialog_util.dart';
import '../../data/utils/update_check_util.dart';

class MainNavigationScreen extends StatefulWidget {
  static int lastSelectedIndex = 0;

  final Widget? child;
  final int initialTabIndex; // ✅ 외부에서 초기 탭 지정
  final bool goToMyBookPostScreen;

  const MainNavigationScreen({
    Key? key,
    this.child,
    this.initialTabIndex = 0,
    this.goToMyBookPostScreen = false,
  }) : super(key: key);

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  late int _selectedIndex;
  bool _overrideWithChild = true;
  bool _hasNavigatedToPostScreen = false;
  bool _hasCheckedUpdate = false;
  bool _hasShownAnnouncement = false;

  final List<GlobalKey<NavigatorState>> _navigatorKeys = [
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
  ];

  late final List<Widget> _screens = [
    HomeScreen(navigatorKey: _navigatorKeys[0]),
    ProfileView(navigatorKey: _navigatorKeys[1]),
  ];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialTabIndex;
    MainNavigationScreen.lastSelectedIndex = widget.initialTabIndex;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_hasNavigatedToPostScreen) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map && args['goToMyBookPostScreen'] == true) {
        _hasNavigatedToPostScreen = true;

        // ✅ 다음 프레임에서 MyBookPostScreen push
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const MyBookPostScreen()),
          );
        });
      }
    }
    if (!_hasCheckedUpdate) {
      _hasCheckedUpdate = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        UpdateCheckUtil.checkForUpdate(context);
      });
    }
    if (!_hasShownAnnouncement) {
      _hasShownAnnouncement = true;
      AnnouncementDialogUtil.showIfNeeded(context);
    }
  }

  void _onItemTapped(int index) {
    if (_selectedIndex == index) {
      _navigatorKeys[index].currentState?.popUntil((route) => route.isFirst);
    } else {
      setState(() {
        _selectedIndex = index;
        MainNavigationScreen.lastSelectedIndex = index;
        _overrideWithChild = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget body = (_overrideWithChild && widget.child != null)
        ? widget.child!
        : _screens[_selectedIndex];

    return WillPopScope(
      onWillPop: () async {
        final currentNavigator = _navigatorKeys[_selectedIndex].currentState!;
        if (currentNavigator.canPop()) {
          currentNavigator.pop();
          return false;
        }
        return true; // 더 이상 pop할 게 없으면 시스템이 앱 종료하게 함
      },
      child: Scaffold(
        body: body,
        bottomNavigationBar: Theme(
          data: Theme.of(context).copyWith(
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
          ),
          child: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            elevation: 0,
            backgroundColor: AppColors.white500,
            selectedItemColor: AppColors.black900,
            unselectedItemColor: AppColors.black500,
            selectedFontSize: 12,
            unselectedFontSize: 12,
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
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
      ),
    );
  }
}