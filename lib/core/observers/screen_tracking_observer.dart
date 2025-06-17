import 'package:flutter/material.dart';
import 'package:logue/data/utils/amplitude_util.dart';

class ScreenTrackingObserver extends RouteObserver<PageRoute<dynamic>> {
  DateTime? _startTime;

  void _sendScreenView(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route.settings.name == null) return;

    final screenName = route.settings.name!;
    final fromScreen = previousRoute?.settings.name ?? 'unknown';
    final durationSeconds = _startTime != null
        ? DateTime.now().difference(_startTime!).inSeconds
        : null;

    AmplitudeUtil.log('screen_viewed', props: {
      'screen_name': screenName,
      'from_screen': fromScreen,
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
    });

    _startTime = DateTime.now(); // 다음 시작 시간 갱신
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _sendScreenView(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _sendScreenView(newRoute!, oldRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _sendScreenView(previousRoute!, route);
  }
}