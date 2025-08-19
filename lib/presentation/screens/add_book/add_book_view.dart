import 'package:flutter/material.dart';
import 'add_book_screen.dart';

class AddBookView extends StatefulWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  final bool isLimitReached;
  final Function(bool)? onLoadingStateChanged; // 로딩 상태 변경 콜백

  const AddBookView({
    super.key,
    required this.navigatorKey,
    this.isLimitReached = false,
    this.onLoadingStateChanged,
  });

  @override
  State<AddBookView> createState() => AddBookViewState();
}

class AddBookViewState extends State<AddBookView> {
  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: widget.navigatorKey,
      onGenerateRoute: (settings) {
        return MaterialPageRoute(
          builder: (_) => AddBookScreen(
            isLimitReached: widget.isLimitReached,
            navigatorKey: widget.navigatorKey,
            onLoadingStateChanged: widget.onLoadingStateChanged,
          ),
        );
      },
    );
  }
} 