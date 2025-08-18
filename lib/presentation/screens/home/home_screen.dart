import 'package:flutter/material.dart';
import 'home_main_view.dart';

class HomeScreen extends StatelessWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  const HomeScreen({
    super.key,
    required this.navigatorKey,
    this.initialTab = 0,
  });

  /// 0=추천, 1=팔로잉, 2=인기
  final int initialTab;

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey, // ✅ popUntil 작동
      onGenerateRoute: (_) => MaterialPageRoute(
        builder: (_) => HomeMainView(initialTab: initialTab),
      ),
    );
  }
}