import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../utils/firebase_analytics_util.dart';

class AnalyticsSessionService {
  static final AnalyticsSessionService _instance = AnalyticsSessionService._internal();
  factory AnalyticsSessionService() => _instance;
  AnalyticsSessionService._internal();

  Timer? _sessionTimer;
  DateTime? _sessionStartTime;
  String? _currentUserId;
  String? _currentSessionId;

  /// 세션 시작
  Future<void> startSession({String? userId}) async {
    try {
      _currentUserId = userId;
      _currentSessionId = _generateSessionId();
      _sessionStartTime = DateTime.now();

      // Firebase Analytics에 세션 시작 이벤트 전송
      await FirebaseAnalyticsUtil.logSessionStart(
        userId: userId,
        sessionId: _currentSessionId,
      );

      // 앱 버전 정보 전송
      await _logAppVersionInfo(userId: userId);

      // 세션 타이머 시작 (5분마다 하트비트)
      _startSessionTimer();

      print('✅ 세션 시작: ${_currentSessionId}');
    } catch (e) {
      print('❌ 세션 시작 실패: $e');
    }
  }

  /// 세션 종료
  Future<void> endSession() async {
    try {
      if (_sessionStartTime != null) {
        final duration = DateTime.now().difference(_sessionStartTime!);
        final durationMinutes = duration.inMinutes;

        // Firebase Analytics에 세션 종료 이벤트 전송
        await FirebaseAnalyticsUtil.logSessionEnd(
          userId: _currentUserId,
          sessionId: _currentSessionId,
          durationMinutes: durationMinutes,
        );

        // 세션 정보 저장
        await _saveSessionData(durationMinutes);

        print('✅ 세션 종료: ${_currentSessionId}, 지속시간: ${durationMinutes}분');
      }

      // 타이머 정리
      _sessionTimer?.cancel();
      _sessionTimer = null;
      _sessionStartTime = null;
      _currentSessionId = null;
    } catch (e) {
      print('❌ 세션 종료 실패: $e');
    }
  }

  /// 세션 타이머 시작
  void _startSessionTimer() {
    _sessionTimer?.cancel();
    _sessionTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _sendSessionHeartbeat();
    });
  }

  /// 세션 하트비트 전송
  Future<void> _sendSessionHeartbeat() async {
    try {
      if (_sessionStartTime != null) {
        final duration = DateTime.now().difference(_sessionStartTime!);
        final durationMinutes = duration.inMinutes;

        // Firebase Analytics에 하트비트 이벤트 전송
        await FirebaseAnalyticsUtil.logEvent(
          name: 'session_heartbeat',
          parameters: {
            'user_id': _currentUserId ?? '',
            'session_id': _currentSessionId ?? '',
            'duration_minutes': durationMinutes,
            'timestamp': DateTime.now().toIso8601String(),
            'date': DateTime.now().toIso8601String().split('T')[0],
          },
        );
      }
    } catch (e) {
      print('❌ 세션 하트비트 전송 실패: $e');
    }
  }

  /// 앱 버전 정보 로깅
  Future<void> _logAppVersionInfo({String? userId}) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      await FirebaseAnalyticsUtil.logAppVersion(
        appVersion: packageInfo.version,
        buildNumber: packageInfo.buildNumber,
        userId: userId,
      );
    } catch (e) {
      print('❌ 앱 버전 정보 로깅 실패: $e');
    }
  }

  /// 세션 데이터 저장
  Future<void> _saveSessionData(int durationMinutes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now().toIso8601String().split('T')[0];
      
      // 오늘 날짜의 세션 수 증가
      final sessionCountKey = 'session_count_$today';
      final sessionCount = prefs.getInt(sessionCountKey) ?? 0;
      await prefs.setInt(sessionCountKey, sessionCount + 1);

      // 오늘 날짜의 총 세션 시간 증가
      final totalDurationKey = 'total_duration_$today';
      final totalDuration = prefs.getInt(totalDurationKey) ?? 0;
      await prefs.setInt(totalDurationKey, totalDuration + durationMinutes);

      // 사용자별 세션 데이터 저장
      if (_currentUserId != null) {
        final userSessionKey = 'user_session_${_currentUserId}_$today';
        final userSessionData = prefs.getString(userSessionKey);
        
        if (userSessionData != null) {
          // 기존 데이터가 있으면 업데이트
          final data = Map<String, dynamic>.from(
            userSessionData as Map<String, dynamic>
          );
          data['session_count'] = (data['session_count'] ?? 0) + 1;
          data['total_duration'] = (data['total_duration'] ?? 0) + durationMinutes;
          data['last_session_time'] = DateTime.now().toIso8601String();
          
          await prefs.setString(userSessionKey, data.toString());
        } else {
          // 새로운 사용자 세션 데이터
          final newData = {
            'user_id': _currentUserId,
            'date': today,
            'session_count': 1,
            'total_duration': durationMinutes,
            'first_session_time': DateTime.now().toIso8601String(),
            'last_session_time': DateTime.now().toIso8601String(),
          };
          
          await prefs.setString(userSessionKey, newData.toString());
        }
      }
    } catch (e) {
      print('❌ 세션 데이터 저장 실패: $e');
    }
  }

  /// 세션 ID 생성
  String _generateSessionId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (timestamp % 10000).toString().padLeft(4, '0');
    return 'session_${timestamp}_$random';
  }

  /// 사용자 변경 (로그인/로그아웃 시)
  Future<void> changeUser({String? newUserId}) async {
    // 기존 세션 종료
    await endSession();
    
    // 새 사용자로 세션 시작
    if (newUserId != null) {
      await startSession(userId: newUserId);
    }
  }

  /// 앱 포그라운드 진입
  Future<void> onAppResumed() async {
    if (_sessionStartTime == null) {
      // 세션이 없으면 새로 시작
      await startSession(userId: _currentUserId);
    }
  }

  /// 앱 백그라운드 진입
  Future<void> onAppPaused() async {
    // 세션은 유지하되 하트비트만 중단
    _sessionTimer?.cancel();
  }

  /// 앱 완전 종료
  Future<void> onAppTerminated() async {
    await endSession();
  }

  /// 사용자 속성 설정
  Future<void> setUserProperties({
    String? age,
    String? gender,
    String? job,
  }) async {
    try {
      await FirebaseAnalyticsUtil.setUserProperties(
        age: age,
        gender: gender,
        job: job,
        userId: _currentUserId,
      );
    } catch (e) {
      print('❌ 사용자 속성 설정 실패: $e');
    }
  }

  /// 사용자 행동 패턴 분석
  Future<void> analyzeUserBehavior() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now().toIso8601String().split('T')[0];
      
      if (_currentUserId != null) {
        final userSessionKey = 'user_session_${_currentUserId}_$today';
        final userSessionData = prefs.getString(userSessionKey);
        
        if (userSessionData != null) {
          final data = Map<String, dynamic>.from(
            userSessionData as Map<String, dynamic>
          );
          
          final sessionCount = data['session_count'] ?? 0;
          final totalDuration = data['total_duration'] ?? 0;
          
          String behaviorType;
          if (sessionCount >= 5 && totalDuration >= 60) {
            behaviorType = 'power_user';
          } else if (sessionCount >= 2 && totalDuration >= 20) {
            behaviorType = 'frequent_user';
          } else {
            behaviorType = 'casual_user';
          }
          
          await FirebaseAnalyticsUtil.logUserBehavior(
            behaviorType: behaviorType,
            behaviorData: {
              'daily_session_count': sessionCount,
              'daily_total_duration': totalDuration,
              'average_session_duration': sessionCount > 0 ? totalDuration / sessionCount : 0,
            },
            userId: _currentUserId,
          );
        }
      }
    } catch (e) {
      print('❌ 사용자 행동 패턴 분석 실패: $e');
    }
  }

  /// 리텐션 분석
  Future<void> analyzeRetention() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now();
      
      if (_currentUserId != null) {
        // 마지막 방문일 확인
        final lastVisitKey = 'last_visit_${_currentUserId}';
        final lastVisitString = prefs.getString(lastVisitKey);
        
        if (lastVisitString != null) {
          final lastVisit = DateTime.parse(lastVisitString);
          final daysSinceLastVisit = today.difference(lastVisit).inDays;
          
          if (daysSinceLastVisit > 0) {
            String retentionType;
            if (daysSinceLastVisit == 1) {
              retentionType = 'daily';
            } else if (daysSinceLastVisit <= 7) {
              retentionType = 'weekly';
            } else if (daysSinceLastVisit <= 30) {
              retentionType = 'monthly';
            } else {
              retentionType = 'long_term';
            }
            
            await FirebaseAnalyticsUtil.logUserRetention(
              daysSinceLastVisit: daysSinceLastVisit,
              retentionType: retentionType,
              userId: _currentUserId,
            );
          }
        }
        
        // 오늘 방문 기록
        await prefs.setString(lastVisitKey, today.toIso8601String());
      }
    } catch (e) {
      print('❌ 리텐션 분석 실패: $e');
    }
  }

  /// 이탈 분석
  Future<void> analyzeChurn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      if (_currentUserId != null) {
        // 마지막 활동일 확인
        final lastActivityKey = 'last_activity_${_currentUserId}';
        final lastActivityString = prefs.getString(lastActivityKey);
        
        if (lastActivityString != null) {
          final lastActivity = DateTime.parse(lastActivityString);
          final daysInactive = DateTime.now().difference(lastActivity).inDays;
          
          // 90일(3개월) 이상 비활성이면 이탈로 간주
          if (daysInactive >= 90) {
            await FirebaseAnalyticsUtil.logUserChurn(
              daysInactive: daysInactive,
              churnReason: 'inactive',
              userId: _currentUserId,
            );
          }
        }
        
        // 오늘 활동 기록
        await prefs.setString(lastActivityKey, DateTime.now().toIso8601String());
      }
    } catch (e) {
      print('❌ 이탈 분석 실패: $e');
    }
  }
} 