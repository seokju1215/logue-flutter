import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:my_logue/core/themes/app_colors.dart';
import 'package:my_logue/presentation/screens/home/home_screen.dart';
import 'package:my_logue/presentation/screens/profile/profile_view.dart';
import 'package:my_logue/presentation/screens/profile/profile_screen.dart';
import 'package:my_logue/presentation/screens/post/my_post_screen.dart';
import 'package:my_logue/presentation/screens/profile/add_book/add_book_screen.dart';

import '../../data/utils/announcement_dialog_util.dart';
import '../../data/utils/update_check_util.dart';

class MainNavigationScreen extends StatefulWidget {
  static int lastSelectedIndex = 0;

  final Widget? child;
  final int initialTabIndex;
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
    GlobalKey<NavigatorState>(),
  ];

  late final List<Widget> _screens = [
    HomeScreen(navigatorKey: _navigatorKeys[0]),
    ProfileView(navigatorKey: _navigatorKeys[1]),
    ProfileView(navigatorKey: _navigatorKeys[2]), // 중간 버튼용 (실제로는 사용하지 않음)
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

    if (!_hasNavigatedToPostScreen && widget.goToMyBookPostScreen == true) {
      _hasNavigatedToPostScreen = true;

                  WidgetsBinding.instance.addPostFrameCallback((_) async {
        // profile_screen의 context를 사용하여 MyBookPostScreen으로 이동
        final profileContext = _navigatorKeys[1].currentState?.context;
        if (profileContext != null) {
          // profile_screen의 onTap 콜백을 직접 호출하는 방식으로 변경
          final result = await Navigator.of(profileContext).push(
          MaterialPageRoute(builder: (_) => const MyBookPostScreen()),
        );
          
          // 포스트 삭제 후 홈으로 이동했다가 프로필로 이동
          if (result == true) {
            debugPrint('🔍 포스트 삭제됨, 홈으로 이동 후 프로필로 이동');
            
            // 먼저 홈으로 이동
            setState(() {
              _selectedIndex = 0;
              MainNavigationScreen.lastSelectedIndex = 0;
            });
            
            // 잠시 후에 프로필로 이동
            Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted) {
                debugPrint('🔍 100ms 후 프로필로 이동');
                setState(() {
                  _selectedIndex = 1;
                  MainNavigationScreen.lastSelectedIndex = 1;
                });
              }
            });
          }
        }
      });
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
    if (index == 1) {
      // 중간 버튼 (책 추가) 클릭 시
      _showAddBookDialog();
      return;
    }
    
    // 인덱스 조정 (중간 버튼 때문에)
    int actualIndex = index > 1 ? index - 1 : index;
    
    if (_selectedIndex == actualIndex) {
      _navigatorKeys[actualIndex].currentState?.popUntil((route) => route.isFirst);
    } else {
      setState(() {
        _selectedIndex = actualIndex;
        MainNavigationScreen.lastSelectedIndex = actualIndex;
        _overrideWithChild = false;
      });
    }
  }

  void _showAddBookDialog() {
    // 책 추가 화면으로 이동
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AddBookScreen(isLimitReached: false),
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return Theme(
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
              width: 32,
              height: 32,
              color: _selectedIndex == 0
                  ? AppColors.black900
                  : AppColors.black500,
            ),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Container(
              width: 32,
              height: 32,
              child: SvgPicture.asset(
                'assets/add_book_icon.svg',
                width: 32,
                height: 32,
              ),
            ),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: SvgPicture.asset(
              'assets/profile_bottomnavi.svg',
              width: 32,
              height: 32,
              color: _selectedIndex == 2
                  ? AppColors.black900
                  : AppColors.black500,
            ),
            label: '',
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget body = (_overrideWithChild && widget.child != null)
        ? widget.child!
        : _screens[_selectedIndex];

    if (_overrideWithChild && widget.child != null) {
      debugPrint('🔍 child를 보여주므로 MainNavigationScreen WillPopScope 비활성화');
      return Scaffold(
        body: body,
        bottomNavigationBar: _buildBottomNavBar(),
      );
    }

    return WillPopScope(
      onWillPop: () async {
        debugPrint('🔍 MainNavigationScreen WillPopScope 호출됨');

        final currentNavigator = _navigatorKeys[_selectedIndex].currentState!;
        if (currentNavigator.canPop()) {
          // pop할 화면이 있으면 직접 pop 호출
          currentNavigator.pop();
          return false;
        }
        // pop할 화면이 없으면 앱 종료 허용
        return true;
      },
      child: Scaffold(
        body: body,
        bottomNavigationBar: _buildBottomNavBar(),
      ),
    );
  }
}