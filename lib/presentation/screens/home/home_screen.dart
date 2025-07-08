import 'package:flutter/material.dart';
import 'home_main_view.dart';

class HomeScreen extends StatelessWidget {
  final GlobalKey<NavigatorState> navigatorKey;

  const HomeScreen({super.key, required this.navigatorKey}); // ✅ 필드 저장

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey, // ✅ key 설정해야 popUntil이 작동함!
      onGenerateRoute: (_) => MaterialPageRoute(
        builder: (_) => const HomeMainView(),
      ),
    );
  }
}