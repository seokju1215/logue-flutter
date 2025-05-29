// ✅ MainNavigationWrapper.dart
import 'package:flutter/material.dart';
import 'package:logue/presentation/screens/main_navigation_screen.dart';

class MainNavigationWrapper extends StatelessWidget {
  final Widget child;
  final String currentRoute;

  const MainNavigationWrapper({
    Key? key,
    required this.child,
    required this.currentRoute,
  }) : super(key: key);

  int getTabIndex() {
    if (currentRoute.startsWith('/main/profile') || currentRoute == '/profile') {
      return 1;
    }
    return 0; // 기본: 홈
  }

  @override
  Widget build(BuildContext context) {
    return MainNavigationScreen(
      initialIndex: getTabIndex(),
      child: child,
    );
  }
}
