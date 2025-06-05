import 'package:flutter/material.dart';
import 'profile_screen.dart';

class ProfileView extends StatelessWidget {
  final GlobalKey<NavigatorState> navigatorKey;

  const ProfileView({super.key, required this.navigatorKey});

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey,
      onGenerateRoute: (settings) {
        return MaterialPageRoute(
          builder: (_) => const ProfileScreen(),
        );
      },
    );
  }
}