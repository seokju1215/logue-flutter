import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/utils/firebase_analytics_util.dart';

mixin AnalyticsScreenMixin<T extends StatefulWidget> on State<T> {
  String get screenName;
  String? get screenClass => runtimeType.toString();

  @override
  void initState() {
    super.initState();
    _logScreenView();
  }

  @override
  void dispose() {
    _logScreenExit();
    super.dispose();
  }

  /// 화면 진입 이벤트 로깅
  Future<void> _logScreenView() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      await FirebaseAnalyticsUtil.logScreenView(
        screenName: screenName,
        screenClass: screenClass,
        userId: userId,
      );
    } catch (e) {
      print('❌ 화면 진입 이벤트 로깅 실패: $e');
    }
  }

  /// 화면 나감 이벤트 로깅
  Future<void> _logScreenExit() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      await FirebaseAnalyticsUtil.logEvent(
        name: 'screen_exit',
        parameters: {
          'screen_name': screenName,
          'screen_class': screenClass ?? '',
          'user_id': userId ?? '',
          'timestamp': DateTime.now().toIso8601String(),
          'date': DateTime.now().toIso8601String().split('T')[0],
        },
      );
    } catch (e) {
      print('❌ 화면 나감 이벤트 로깅 실패: $e');
    }
  }

  /// 커스텀 이벤트 로깅 헬퍼
  Future<void> logCustomEvent({
    required String eventName,
    Map<String, dynamic>? parameters,
  }) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      final allParameters = <String, Object>{
        'screen_name': screenName,
        'screen_class': screenClass ?? '',
        'user_id': userId ?? '',
        'timestamp': DateTime.now().toIso8601String(),
        'date': DateTime.now().toIso8601String().split('T')[0],
      };

      // parameters의 모든 값을 Object로 변환
      if (parameters != null) {
        for (final entry in parameters.entries) {
          allParameters[entry.key] = entry.value ?? '';
        }
      }

      await FirebaseAnalyticsUtil.logEvent(
        name: eventName,
        parameters: allParameters,
      );
    } catch (e) {
      print('❌ 커스텀 이벤트 로깅 실패: $e');
    }
  }
} 