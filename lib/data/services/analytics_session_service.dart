import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/firebase_analytics_util.dart';

class AnalyticsSessionService {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  static final SupabaseClient _supabase = Supabase.instance.client;
  bool _active = false;

  DateTime? _sessionStartTime;
  String? _currentUserId;
  String? _sessionId;

  // ===== 세션 관리 =====
  
  /// 세션 시작
  Future<void> startSession({String? userId}) async {
    if (_active) return; // ✅ 이미 시작되어 있으면 무시
    _active = true;

    _sessionStartTime = DateTime.now();
    _currentUserId = userId;
    _sessionId = DateTime.now().millisecondsSinceEpoch.toString();

    await FirebaseAnalyticsUtil.logSessionStart(
      userId: userId,
      sessionId: _sessionId,
    );

    // 시간대 이벤트 + DAU/WAU/MAU
    final now = DateTime.now();
    await FirebaseAnalyticsUtil.logTimeBasedAccess(
      dayOfWeek: ['monday','tuesday','wednesday','thursday','friday','saturday','sunday'][now.weekday-1],
      hour: now.hour,
      userId: userId,
    );
    if (userId != null) {
      await _logUserActivityMetrics(userId);
    }
  }

  /// 세션 종료
  Future<void> endSession() async {
    if (!_active) return; // ✅ 시작 안 했으면 무시
    if (_sessionStartTime != null && _currentUserId != null) {
      final duration = DateTime.now().difference(_sessionStartTime!).inMinutes;
      await FirebaseAnalyticsUtil.logSessionEnd(
        userId: _currentUserId,
        sessionId: _sessionId,
        durationMinutes: duration,
      );
      await FirebaseAnalyticsUtil.logAppUsageTime(
        userId: _currentUserId!,
        sessionDurationMinutes: duration,
        sessionType: 'active',
      );
    }
    _active = false;
    _sessionStartTime = null;
    _currentUserId = null;
    _sessionId = null;
  }

  // ===== 사용자 활동 메트릭 =====
  
  /// 사용자 활동 메트릭 로깅 (DAU, WAU, MAU)
  Future<void> _logUserActivityMetrics(String userId) async {
    try {
      // 사용자 정보 가져오기 (created_at만 사용)
      final userResponse = await _supabase
          .from('profiles')
          .select('created_at')
          .eq('id', userId)
          .single();
      
      final createdAt = DateTime.parse(userResponse['created_at']);
      final now = DateTime.now();
      final daysSinceCreation = now.difference(createdAt).inDays;
      
      // DAU 이벤트 - 생성일 기준으로 판단
      String userType = 'returning';
      if (daysSinceCreation <= 1) {
        userType = 'new';
      } else if (daysSinceCreation <= 7) {
        userType = 'active';
      }
      
      await FirebaseAnalyticsUtil.logDailyActiveUser(
        userId: userId,
        userType: userType,
      );
      
      // WAU 이벤트 - 생성일 기준으로 판단
      if (daysSinceCreation <= 7) {
        await FirebaseAnalyticsUtil.logWeeklyActiveUser(
          userId: userId,
          userType: userType,
        );
      }
      
      // MAU 이벤트 - 생성일 기준으로 판단
      if (daysSinceCreation <= 30) {
        await FirebaseAnalyticsUtil.logMonthlyActiveUser(
          userId: userId,
          userType: userType,
        );
      }
      
    } catch (e) {
      print('❌ 사용자 활동 메트릭 로깅 실패: $e');
    }
  }

  // ===== 사용자 속성 설정 =====
  
  /// 사용자 기본 속성 설정
  Future<void> setUserProperties({
    String? age,
    String? gender,
    String? job,
    String? appVersion,
    String? userId,
  }) async {
    await FirebaseAnalyticsUtil.setUserProperties(
      age: age,
      gender: gender,
      job: job,
      appVersion: appVersion,
      userId: userId,
    );
  }

  // ===== UGC 분석 =====
  
  /// UGC 생성 이벤트 로깅
  Future<void> logUGCGeneration({
    required String contentType,
    required String contentId,
    required Map<String, dynamic> contentMetadata,
  }) async {
    if (_currentUserId != null) {
      await FirebaseAnalyticsUtil.logUGCGeneration(
        userId: _currentUserId!,
        contentType: contentType,
        contentId: contentId,
        contentMetadata: contentMetadata,
      );
    }
  }

  /// UGC 상호작용 이벤트 로깅
  Future<void> logUGCInteraction({
    required String contentType,
    required String contentId,
    required String interactionType,
  }) async {
    if (_currentUserId != null) {
      await FirebaseAnalyticsUtil.logUGCInteraction(
        userId: _currentUserId!,
        contentType: contentType,
        contentId: contentId,
        interactionType: interactionType,
      );
    }
  }

  // ===== 기능 사용 빈도 =====
  
  /// 기능 사용 빈도 로깅
  Future<void> logFeatureUsage({
    required String featureName,
    required int usageCount,
    required String timePeriod,
  }) async {
    if (_currentUserId != null) {
      await FirebaseAnalyticsUtil.logFeatureUsageFrequency(
        userId: _currentUserId!,
        featureName: featureName,
        usageCount: usageCount,
        timePeriod: timePeriod,
      );
    }
  }

  // ===== 리텐션 및 이탈 분석 =====
  
  /// 사용자 리텐션 로깅
  Future<void> logUserRetention({
    required int daysSinceLastVisit,
    required String retentionType,
  }) async {
    if (_currentUserId != null) {
      await FirebaseAnalyticsUtil.logUserRetention(
        userId: _currentUserId!,
        daysSinceLastVisit: daysSinceLastVisit,
        retentionType: retentionType,
      );
    }
  }

  /// 사용자 이탈 로깅
  Future<void> logUserChurn({
    required int daysInactive,
    required String churnReason,
  }) async {
    if (_currentUserId != null) {
      await FirebaseAnalyticsUtil.logUserChurn(
        userId: _currentUserId!,
        daysInactive: daysInactive,
        churnReason: churnReason,
      );
    }
  }

  // ===== 앱 버전 정보 =====
  
  /// 앱 버전 정보 로깅
  Future<void> logAppVersion({
    required String appVersion,
    required String buildNumber,
  }) async {
    await FirebaseAnalyticsUtil.logAppVersion(
      appVersion: appVersion,
      buildNumber: buildNumber,
      userId: _currentUserId,
    );
  }

  // ===== 커스텀 이벤트 =====
  
  /// 커스텀 이벤트 로깅
  Future<void> logCustomEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    await FirebaseAnalyticsUtil.logEvent(
      name: name,
      parameters: parameters,
    );
  }

  // ===== 헬퍼 메서드 =====
  
  /// 현재 사용자 ID 반환
  String? get currentUserId => _currentUserId;
  
  /// 현재 세션 ID 반환
  String? get sessionId => _sessionId;
  
  /// 세션 시작 시간 반환
  DateTime? get sessionStartTime => _sessionStartTime;
} 