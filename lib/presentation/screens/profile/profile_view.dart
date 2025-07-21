import 'package:flutter/material.dart';
import '../post/my_post_screen.dart';
import 'profile_screen.dart';

class ProfileView extends StatefulWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  final bool goToMyBookPostScreen;

  const ProfileView({
    super.key,
    required this.navigatorKey,
    this.goToMyBookPostScreen = false,
  });

  @override
  State<ProfileView> createState() => ProfileViewState();
}

class ProfileViewState extends State<ProfileView> {
  bool _hasNavigated = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    debugPrint('⚙️ didChangeDependencies 실행됨');
    debugPrint('🔎 goToMyBookPostScreen: ${widget.goToMyBookPostScreen}');
    debugPrint('🔎 _hasNavigated: $_hasNavigated');

    if (!_hasNavigated && widget.goToMyBookPostScreen) {
      _hasNavigated = true;

      Future.delayed(Duration.zero, () {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          debugPrint('🚀 MyBookPostScreen 이동 시작!');
          widget.navigatorKey.currentState?.push(
            MaterialPageRoute(builder: (_) => const MyBookPostScreen()),
          );
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: widget.navigatorKey,
      onGenerateRoute: (settings) {
        return MaterialPageRoute(
          builder: (_) => const ProfileScreen(),
        );
      },
    );
  }
}