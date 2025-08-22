import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Firebase Analytics 유틸리티 클래스
/// 
/// ⚠️ 중요: User ID 처리 방침
/// - user_id는 setUserId() 메서드로만 설정합니다
/// - 이벤트 parameters에 'user_id'를 포함하지 마세요
/// - Firebase Analytics가 자동으로 모든 이벤트에 user_id를 추가합니다
/// - 로그인 시: setUserId(id: userId)
/// - 로그아웃 시: setUserId(id: null)
class FirebaseAnalyticsUtil {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  
  // ===== 사용자 인증 및 기본 이벤트 =====
  
  /// 사용자 로그인 이벤트
  static Future<void> logLogin({
    required String method,
    String? userId,
  }) async {
    try {
      await _analytics.logLogin(loginMethod: method);
      if (userId != null) {
        await _analytics.setUserId(id: userId);
      }
    } catch (e) {
      print('❌ Firebase Analytics 로그인 이벤트 실패: $e');
    }
  }

  /// 사용자 로그아웃 이벤트
  static Future<void> logLogout({String? userId}) async {
    try {
      await _analytics.logEvent(
        name: 'user_logout',
        parameters: {}, // user_id는 setUserId()로 자동 추가됨
      );
      await _analytics.setUserId(id: null);
    } catch (e) {
      print('❌ Firebase Analytics 로그아웃 이벤트 실패: $e');
    }
  }

  /// 사용자 회원가입 이벤트
  static Future<void> logSignUp({
    required String method,
    String? userId,
  }) async {
    try {
      await _analytics.logSignUp(signUpMethod: method);
      if (userId != null) {
        await _analytics.setUserId(id: userId);
      }
    } catch (e) {
      print('❌ Firebase Analytics 회원가입 이벤트 실패: $e');
    }
  }

  /// 사용자 계정 탈퇴 이벤트
  static Future<void> logAccountDeletion({
    String? reason,
    String? userId,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'user_account_deletion',
        parameters: {
          'reason': reason ?? '',
          // user_id는 setUserId()로 자동 추가됨
        },
      );
      await _analytics.setUserId(id: null);
    } catch (e) {
      print('❌ Firebase Analytics 계정 탈퇴 이벤트 실패: $e');
    }
  }

  // ===== 앱 사용 및 세션 이벤트 =====
  
  /// 앱 시작 이벤트
  static Future<void> logAppOpen() async {
    try {
      await _analytics.logAppOpen();
    } catch (e) {
      print('❌ Firebase Analytics 앱 시작 이벤트 실패: $e');
    }
  }

  /// 세션 시작 이벤트
  static Future<void> logSessionStart({
    String? userId,
    String? sessionId,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'app_session_start',
        parameters: {
          'user_id': userId ?? '',
          'session_id': sessionId ?? '',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      print('❌ Firebase Analytics 세션 시작 이벤트 실패: $e');
    }
  }

  /// 세션 종료 이벤트
  static Future<void> logSessionEnd({
    String? userId,
    String? sessionId,
    int? durationMinutes,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'app_session_end',
        parameters: {
          'user_id': userId ?? '',
          'session_id': sessionId ?? '',
          'duration_minutes': durationMinutes ?? 0,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      print('❌ Firebase Analytics 세션 종료 이벤트 실패: $e');
    }
  }

  /// 화면 전환 이벤트
  static Future<void> logScreenView({
    required String screenName,
    String? screenClass,
    String? userId,
  }) async {
    try {
      await _analytics.logScreenView(
        screenName: screenName,
        screenClass: screenClass,
      );
      // 추가로 커스텀 이벤트로도 기록
      await _analytics.logEvent(
        name: 'screen_view',
        parameters: {
          'screen_name': screenName,
          'screen_class': screenClass ?? '',
          'user_id': userId ?? '',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      print('❌ Firebase Analytics 화면 전환 이벤트 실패: $e');
    }
  }

  // ===== 책 관련 이벤트 =====
  
  /// 책 추가 이벤트 (신규 추가)
  static Future<void> logBookAdded({
    required String bookTitle,
    required String bookAuthor,
    required String location, // 'profile' 또는 'archive'
    String? userId,
  }) async {
    try {
      final now = DateTime.now();
      await _analytics.logEvent(
        name: 'book_added',
        parameters: {
          'book_title': bookTitle,
          'book_author': bookAuthor,
          'location': location,
          'timestamp': now.toIso8601String(),
          'date': now.toIso8601String().split('T')[0], // YYYY-MM-DD
          'year': now.year,
          'month': now.month,
          'day': now.day,
          'weekday': now.weekday, // 1=Monday, 7=Sunday
        },
      );
    } catch (e) {
      print('❌ Firebase Analytics 책 추가 이벤트 실패: $e');
    }
  }

  /// 책을 프로필로 이동 이벤트 (보관함 → 프로필)
  static Future<void> logBookAddedToProfile({
    required String bookTitle,
    required String bookAuthor,
    String? reviewTitle,
    String? reviewContent,
    String? userId,
  }) async {
    try {
      final now = DateTime.now();
      final parameters = {
        'book_title': bookTitle,
        'book_author': bookAuthor,
        'review_title': reviewTitle ?? '',
        'review_content_length': reviewContent?.length ?? 0,
        'has_review': (reviewTitle?.isNotEmpty == true || reviewContent?.isNotEmpty == true) ? 'true' : 'false',
        'timestamp': now.toIso8601String(),
        'date': now.toIso8601String().split('T')[0], // YYYY-MM-DD
        'year': now.year,
        'month': now.month,
        'day': now.day,
        'weekday': now.weekday, // 1=Monday, 7=Sunday
      };
      
      debugPrint('🔥 Firebase Analytics 이벤트 전송 시작: add_book_to_profile');
      debugPrint('📚 책 정보: $bookTitle by $bookAuthor');
      debugPrint('📝 후기 정보: title="${reviewTitle ?? ''}", content_length=${reviewContent?.length ?? 0}');
      debugPrint('📊 파라미터: $parameters');
      
      await _analytics.logEvent(
        name: 'add_book_to_profile',
        parameters: parameters,
      );
      
      debugPrint('✅ Firebase Analytics 이벤트 전송 완료: add_book_to_profile');
    } catch (e) {
      debugPrint('❌ Firebase Analytics 프로필 책 이동 이벤트 실패: $e');
    }
  }

  /// 책을 보관함에 추가 이벤트 (신규 추가 → 보관함)
  static Future<void> logBookAddedToArchive({
    required String bookTitle,
    required String bookAuthor,
    String? reviewTitle,
    String? reviewContent,
    int? rating,
    String? userId,
  }) async {
    try {
      final now = DateTime.now();
      await _analytics.logEvent(
        name: 'add_book_to_archive',
        parameters: {
          'book_title': bookTitle,
          'book_author': bookAuthor,
          'review_title': reviewTitle ?? '',
          'review_content_length': reviewContent?.length ?? 0,
          'rating': rating ?? 0,
          'has_review': (reviewTitle?.isNotEmpty == true || reviewContent?.isNotEmpty == true) ? 'true' : 'false',
          'timestamp': now.toIso8601String(),
          'date': now.toIso8601String().split('T')[0], // YYYY-MM-DD
          'year': now.year,
          'month': now.month,
          'day': now.day,
          'weekday': now.weekday, // 1=Monday, 7=Sunday
        },
      );
    } catch (e) {
      print('❌ Firebase Analytics 보관함 책 추가 이벤트 실패: $e');
    }
  }

  /// 책 후기 작성 이벤트
  static Future<void> logBookReview({
    required String bookTitle,
    required String bookAuthor,
    required int rating,
    String? reviewTitle,
    String? reviewContent,
    String? userId,
  }) async {
    try {
      final now = DateTime.now();
      await _analytics.logEvent(
        name: 'book_review_written',
        parameters: {
          'book_title': bookTitle,
          'book_author': bookAuthor,
          'rating': rating,
          'review_title': reviewTitle ?? '',
          'review_content_length': reviewContent?.length ?? 0,
          'timestamp': now.toIso8601String(),
          'date': now.toIso8601String().split('T')[0], // YYYY-MM-DD
          'year': now.year,
          'month': now.month,
          'day': now.day,
          'weekday': now.weekday, // 1=Monday, 7=Sunday
        },
      );
    } catch (e) {
      print('❌ Firebase Analytics 책 후기 이벤트 실패: $e');
    }
  }

  /// 책 이동 이벤트 (프로필 ↔ 보관함)
  static Future<void> logBookMoved({
    required String bookTitle,
    required String bookAuthor,
    required String fromLocation, // 'profile' 또는 'archive'
    required String toLocation,   // 'profile' 또는 'archive'
    String? userId,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'book_moved',
        parameters: {
          'book_title': bookTitle,
          'book_author': bookAuthor,
          'from_location': fromLocation,
          'to_location': toLocation,
          'user_id': userId ?? '',
          'timestamp': DateTime.now().toIso8601String(),
          'date': DateTime.now().toIso8601String().split('T')[0],
        },
      );
    } catch (e) {
      print('❌ Firebase Analytics 책 이동 이벤트 실패: $e');
    }
  }

  /// 보관함/프로필 이동 버튼 클릭 이벤트
  static Future<void> logBookMoveButtonClick({
    required String fromLocation, // 'profile' 또는 'archive'
    required String toLocation,   // 'profile' 또는 'archive'
    String? userId,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'book_move_button_clicked',
        parameters: {
          'from_location': fromLocation,
          'to_location': toLocation,
          'user_id': userId ?? '',
          'timestamp': DateTime.now().toIso8601String(),
          'date': DateTime.now().toIso8601String().split('T')[0],
        },
      );
    } catch (e) {
      print('❌ Firebase Analytics 책 이동 버튼 클릭 이벤트 실패: $e');
    }
  }

  // ===== 소셜 기능 이벤트 =====
  
  /// 팔로우/언팔로우 이벤트
  static Future<void> logFollow({
    required String targetUserId,
    required String action, // 'follow' 또는 'unfollow'
    String? userId,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'user_follow_action',
        parameters: {
          'target_user_id': targetUserId,
          'action': action,
          'user_id': userId ?? '',
          'timestamp': DateTime.now().toIso8601String(),
          'date': DateTime.now().toIso8601String().split('T')[0],
        },
      );
    } catch (e) {
      print('❌ Firebase Analytics 팔로우 이벤트 실패: $e');
    }
  }

  /// 팔로워/팔로잉 수 변경 이벤트
  static Future<void> logFollowCountChange({
    required int followersCount,
    required int followingCount,
    String? userId,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'follow_count_change',
        parameters: {
          'followers_count': followersCount,
          'following_count': followingCount,
          'user_id': userId ?? '',
          'timestamp': DateTime.now().toIso8601String(),
          'date': DateTime.now().toIso8601String().split('T')[0],
        },
      );
    } catch (e) {
      print('❌ Firebase Analytics 팔로우 수 변경 이벤트 실패: $e');
    }
  }

  // ===== 공유 및 바이럴 기능 이벤트 =====
  
  /// 프로필 공유 이벤트
  static Future<void> logProfileShare({
    required String shareMethod, // 'link_copy', 'social_share', 'friend_invite'
    String? userId,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'profile_shared',
        parameters: {
          'share_method': shareMethod,
          'user_id': userId ?? '',
          'timestamp': DateTime.now().toIso8601String(),
          'date': DateTime.now().toIso8601String().split('T')[0],
        },
      );
    } catch (e) {
      print('❌ Firebase Analytics 프로필 공유 이벤트 실패: $e');
    }
  }

  /// 친구 초대 이벤트
  static Future<void> logFriendInvite({
    required String inviteMethod, // 'contacts', 'phone_number', 'link'
    String? userId,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'friend_invited',
        parameters: {
          'invite_method': inviteMethod,
          'user_id': userId ?? '',
          'timestamp': DateTime.now().toIso8601String(),
          'date': DateTime.now().toIso8601String().split('T')[0],
        },
      );
    } catch (e) {
      print('❌ Firebase Analytics 친구 초대 이벤트 실패: $e');
    }
  }

  /// 프로필 링크 복사 이벤트
  static Future<void> logProfileLinkCopy({
    String? userId,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'profile_link_copied',
        parameters: {
          'user_id': userId ?? '',
          'timestamp': DateTime.now().toIso8601String(),
          'date': DateTime.now().toIso8601String().split('T')[0],
        },
      );
    } catch (e) {
      print('❌ Firebase Analytics 프로필 링크 복사 이벤트 실패: $e');
    }
  }

  // ===== 검색 및 발견 기능 이벤트 =====
  
  /// 친구 찾기 이벤트
  static Future<void> logFriendSearch({
    required String searchMethod, // 'contacts', 'phone_number'
    String? userId,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'friend_search_clicked',
        parameters: {
          'search_method': searchMethod,
          'user_id': userId ?? '',
          'timestamp': DateTime.now().toIso8601String(),
          'date': DateTime.now().toIso8601String().split('T')[0],
        },
      );
    } catch (e) {
      print('❌ Firebase Analytics 친구 찾기 이벤트 실패: $e');
    }
  }

  /// 검색 이벤트
  static Future<void> logSearch({
    required String searchTerm,
    required String searchType, // 'book', 'user', 'content'
    String? userId,
  }) async {
    try {
      await _analytics.logSearch(
        searchTerm: searchTerm,
      );
      // 추가로 커스텀 이벤트로도 기록
      await _analytics.logEvent(
        name: 'search_performed',
        parameters: {
          'search_term': searchTerm,
          'search_type': searchType,
          'user_id': userId ?? '',
          'timestamp': DateTime.now().toIso8601String(),
          'date': DateTime.now().toIso8601String().split('T')[0],
        },
      );
    } catch (e) {
      print('❌ Firebase Analytics 검색 이벤트 실패: $e');
    }
  }

  // ===== 프로필 변경 이벤트 =====
  
  /// 사용자 프로필 변경 이벤트
  static Future<void> logProfileChange({
    required String changeType, // 'username', 'photo', 'bio', 'job'
    String? oldValue,
    String? newValue,
    String? userId,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'profile_changed',
        parameters: {
          'change_type': changeType,
          'old_value': oldValue ?? '',
          'new_value': newValue ?? '',
          'user_id': userId ?? '',
          'timestamp': DateTime.now().toIso8601String(),
          'date': DateTime.now().toIso8601String().split('T')[0],
        },
      );
    } catch (e) {
      print('❌ Firebase Analytics 프로필 변경 이벤트 실패: $e');
    }
  }

  /// 사용자 이름 변경 이벤트
  static Future<void> logUsernameChange({
    required String oldUsername,
    required String newUsername,
    String? userId,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'username_changed',
        parameters: {
          'old_username': oldUsername,
          'new_username': newUsername,
          'user_id': userId ?? '',
          'timestamp': DateTime.now().toIso8601String(),
          'date': DateTime.now().toIso8601String().split('T')[0],
        },
      );
    } catch (e) {
      print('❌ Firebase Analytics 사용자명 변경 이벤트 실패: $e');
    }
  }

  /// 프로필 사진 변경 이벤트
  static Future<void> logProfilePhotoChange({
    String? userId,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'profile_photo_changed',
        parameters: {
          'user_id': userId ?? '',
          'timestamp': DateTime.now().toIso8601String(),
          'date': DateTime.now().toIso8601String().split('T')[0],
        },
      );
    } catch (e) {
      print('❌ Firebase Analytics 프로필 사진 변경 이벤트 실패: $e');
    }
  }

  // ===== 광고 및 수익화 이벤트 =====
  
  /// 광고 배너 클릭 이벤트
  static Future<void> logBannerAdClick({
    required String bannerId,
    required String bannerType,
    String? userId,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'banner_ad_clicked',
        parameters: {
          'banner_id': bannerId,
          'banner_type': bannerType,
          'user_id': userId ?? '',
          'timestamp': DateTime.now().toIso8601String(),
          'date': DateTime.now().toIso8601String().split('T')[0],
        },
      );
    } catch (e) {
      print('❌ Firebase Analytics 광고 배너 클릭 이벤트 실패: $e');
    }
  }

  // ===== 사용자 속성 설정 =====
  
  /// 사용자 속성 설정
  static Future<void> setUserProperties({
    String? age,
    String? gender,
    String? job,
    String? appVersion,
    String? userId,
  }) async {
    try {
      if (age != null) await _analytics.setUserProperty(name: 'age', value: age);
      if (gender != null) await _analytics.setUserProperty(name: 'gender', value: gender);
      if (job != null) await _analytics.setUserProperty(name: 'job', value: job);
      if (appVersion != null) await _analytics.setUserProperty(name: 'app_version', value: appVersion);
      
      // user_id는 setUserId()로 별도 설정
      if (userId != null) await _analytics.setUserId(id: userId);
    } catch (e) {
      print('❌ Firebase Analytics 사용자 속성 설정 실패: $e');
    }
  }

  // ===== 고객센터 및 문의 이벤트 =====
  
  /// 고객센터 문의 이벤트
  static Future<void> logCustomerInquiry({
    required String inquiryType, // 'bug_report', 'feature_request', 'general', 'account'
    String? userId,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'customer_inquiry',
        parameters: {
          'inquiry_type': inquiryType,
          'user_id': userId ?? '',
          'timestamp': DateTime.now().toIso8601String(),
          'date': DateTime.now().toIso8601String().split('T')[0],
        },
      );
    } catch (e) {
      print('❌ Firebase Analytics 고객센터 문의 이벤트 실패: $e');
    }
  }

  // ===== 앱 버전 및 업데이트 이벤트 =====
  
  /// 앱 버전 정보 이벤트
  static Future<void> logAppVersion({
    required String appVersion,
    required String buildNumber,
    String? userId,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'app_version_info',
        parameters: {
          'app_version': appVersion,
          'build_number': buildNumber,
          'user_id': userId ?? '',
          'timestamp': DateTime.now().toIso8601String(),
          'date': DateTime.now().toIso8601String().split('T')[0],
        },
      );
    } catch (e) {
      print('❌ Firebase Analytics 앱 버전 정보 이벤트 실패: $e');
    }
  }

  // ===== 사용자 행동 패턴 분석 이벤트 =====
  
  /// 사용자 행동 패턴 이벤트
  static Future<void> logUserBehavior({
    required String behaviorType, // 'frequent_user', 'casual_user', 'power_user'
    required Map<String, dynamic> behaviorData,
    String? userId,
  }) async {
    try {
      final parameters = <String, Object>{
        'behavior_type': behaviorType,
        'user_id': userId ?? '',
        'timestamp': DateTime.now().toIso8601String(),
        'date': DateTime.now().toIso8601String().split('T')[0],
      };
      
      // behaviorData의 모든 값을 Object로 변환
      for (final entry in behaviorData.entries) {
        parameters[entry.key] = entry.value ?? '';
      }
      
      await _analytics.logEvent(
        name: 'user_behavior_pattern',
        parameters: parameters,
      );
    } catch (e) {
      print('❌ Firebase Analytics 사용자 행동 패턴 이벤트 실패: $e');
    }
  }

  // ===== 리텐션 및 이탈 분석 이벤트 =====
  
  /// 사용자 리텐션 이벤트
  static Future<void> logUserRetention({
    required int daysSinceLastVisit,
    required String retentionType, // 'daily', 'weekly', 'monthly'
    String? userId,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'user_retention',
        parameters: {
          'days_since_last_visit': daysSinceLastVisit,
          'retention_type': retentionType,
          'user_id': userId ?? '',
          'timestamp': DateTime.now().toIso8601String(),
          'date': DateTime.now().toIso8601String().split('T')[0],
        },
      );
    } catch (e) {
      print('❌ Firebase Analytics 사용자 리텐션 이벤트 실패: $e');
    }
  }

  /// 사용자 이탈 이벤트
  static Future<void> logUserChurn({
    required int daysInactive,
    required String churnReason, // 'inactive', 'deleted', 'blocked'
    String? userId,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'user_churn',
        parameters: {
          'days_inactive': daysInactive,
          'churn_reason': churnReason,
          'user_id': userId ?? '',
          'timestamp': DateTime.now().toIso8601String(),
          'date': DateTime.now().toIso8601String().split('T')[0],
        },
      );
    } catch (e) {
      print('❌ Firebase Analytics 사용자 이탈 이벤트 실패: $e');
    }
  }

  // ===== 시간대별 접속률 분석 이벤트 =====
  
  /// 시간대별 접속 이벤트
  static Future<void> logTimeBasedAccess({
    required String dayOfWeek, // 'monday', 'tuesday', etc.
    required int hour, // 0-23
    String? userId,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'time_based_access',
        parameters: {
          'day_of_week': dayOfWeek,
          'hour': hour,
          'user_id': userId ?? '',
          'timestamp': DateTime.now().toIso8601String(),
          'date': DateTime.now().toIso8601String().split('T')[0],
        },
      );
    } catch (e) {
      print('❌ Firebase Analytics 시간대별 접속 이벤트 실패: $e');
    }
  }

  // ===== DAU, WAU, MAU 분석 이벤트 =====
  
  /// 일일 활성 사용자 (DAU) 이벤트
  static Future<void> logDailyActiveUser({
    required String userId,
    required String userType, // 'new', 'returning', 'active'
  }) async {
    try {
      await _analytics.logEvent(
        name: 'daily_active_user',
        parameters: {
          'user_id': userId,
          'user_type': userType,
          'timestamp': DateTime.now().toIso8601String(),
          'date': DateTime.now().toIso8601String().split('T')[0],
        },
      );
    } catch (e) {
      print('❌ Firebase Analytics DAU 이벤트 실패: $e');
    }
  }

  /// 주간 활성 사용자 (WAU) 이벤트
  static Future<void> logWeeklyActiveUser({
    required String userId,
    required String userType, // 'new', 'returning', 'active'
  }) async {
    try {
      await _analytics.logEvent(
        name: 'weekly_active_user',
        parameters: {
          'user_id': userId,
          'user_type': userType,
          'timestamp': DateTime.now().toIso8601String(),
          'date': DateTime.now().toIso8601String().split('T')[0],
          'week_start': _getWeekStartDate().toIso8601String().split('T')[0],
        },
      );
    } catch (e) {
      print('❌ Firebase Analytics WAU 이벤트 실패: $e');
    }
  }

  /// 월간 활성 사용자 (MAU) 이벤트
  static Future<void> logMonthlyActiveUser({
    required String userId,
    required String userType, // 'new', 'returning', 'active'
  }) async {
    try {
      await _analytics.logEvent(
        name: 'monthly_active_user',
        parameters: {
          'user_id': userId,
          'user_type': userType,
          'timestamp': DateTime.now().toIso8601String(),
          'date': DateTime.now().toIso8601String().split('T')[0],
          'month_start': _getMonthStartDate().toIso8601String().split('T')[0],
        },
      );
    } catch (e) {
      print('❌ Firebase Analytics MAU 이벤트 실패: $e');
    }
  }

  // ===== 신규 가입자 및 프로필 생성자 분석 이벤트 =====
  
  /// 신규 가입자 이벤트
  static Future<void> logNewUserRegistration({
    required String userId,
    required String registrationMethod, // 'email', 'phone', 'social'
    required String source, // 'organic', 'referral', 'campaign'
  }) async {
    try {
      await _analytics.logEvent(
        name: 'new_user_registration',
        parameters: {
          'user_id': userId,
          'registration_method': registrationMethod,
          'source': source,
          'timestamp': DateTime.now().toIso8601String(),
          'date': DateTime.now().toIso8601String().split('T')[0],
        },
      );
    } catch (e) {
      print('❌ Firebase Analytics 신규 가입자 이벤트 실패: $e');
    }
  }

  /// 프로필 생성자 이벤트
  static Future<void> logProfileCreation({
    required String userId,
    required bool hasProfilePhoto,
    required bool hasBio,
    required bool hasJob,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'profile_creation',
        parameters: {
          'user_id': userId,
          'has_profile_photo': hasProfilePhoto,
          'has_bio': hasBio,
          'has_job': hasJob,
          'timestamp': DateTime.now().toIso8601String(),
          'date': DateTime.now().toIso8601String().split('T')[0],
        },
      );
    } catch (e) {
      print('❌ Firebase Analytics 프로필 생성 이벤트 실패: $e');
    }
  }

  // ===== UGC (User Generated Content) 분석 이벤트 =====
  
  /// UGC 생성 이벤트
  static Future<void> logUGCGeneration({
    required String userId,
    required String contentType, // 'book_review', 'profile_book', 'archive_book'
    required String contentId,
    required Map<String, dynamic> contentMetadata,
  }) async {
    try {
      final parameters = <String, Object>{
        'user_id': userId,
        'content_type': contentType,
        'content_id': contentId,
        'timestamp': DateTime.now().toIso8601String(),
        'date': DateTime.now().toIso8601String().split('T')[0],
      };
      
      // contentMetadata의 모든 값을 Object로 변환
      for (final entry in contentMetadata.entries) {
        parameters[entry.key] = entry.value ?? '';
      }
      
      await _analytics.logEvent(
        name: 'ugc_generated',
        parameters: parameters,
      );
    } catch (e) {
      print('❌ Firebase Analytics UGC 생성 이벤트 실패: $e');
    }
  }

  /// UGC 상호작용 이벤트
  static Future<void> logUGCInteraction({
    required String userId,
    required String contentType, // 'book_review', 'profile_book', 'archive_book'
    required String contentId,
    required String interactionType, // 'view', 'like', 'share', 'comment'
  }) async {
    try {
      await _analytics.logEvent(
        name: 'ugc_interaction',
        parameters: {
          'user_id': userId,
          'content_type': contentType,
          'content_id': contentId,
          'interaction_type': interactionType,
          'timestamp': DateTime.now().toIso8601String(),
          'date': DateTime.now().toIso8601String().split('T')[0],
        },
      );
    } catch (e) {
      print('❌ Firebase Analytics UGC 상호작용 이벤트 실패: $e');
    }
  }

  // ===== 사용자 행동 패턴 상세 분석 이벤트 =====
  
  /// 사용자 앱 이용 시간 이벤트
  static Future<void> logAppUsageTime({
    required String userId,
    required int sessionDurationMinutes,
    required String sessionType, // 'active', 'passive', 'background'
  }) async {
    try {
      await _analytics.logEvent(
        name: 'app_usage_time',
        parameters: {
          'user_id': userId,
          'session_duration_minutes': sessionDurationMinutes,
          'session_type': sessionType,
          'timestamp': DateTime.now().toIso8601String(),
          'date': DateTime.now().toIso8601String().split('T')[0],
        },
      );
    } catch (e) {
      print('❌ Firebase Analytics 앱 이용 시간 이벤트 실패: $e');
    }
  }

  /// 사용자 기능 사용 빈도 이벤트
  static Future<void> logFeatureUsageFrequency({
    required String userId,
    required String featureName,
    required int usageCount,
    required String timePeriod, // 'daily', 'weekly', 'monthly'
  }) async {
    try {
      await _analytics.logEvent(
        name: 'feature_usage_frequency',
        parameters: {
          'user_id': userId,
          'feature_name': featureName,
          'usage_count': usageCount,
          'time_period': timePeriod,
          'timestamp': DateTime.now().toIso8601String(),
          'date': DateTime.now().toIso8601String().split('T')[0],
        },
      );
    } catch (e) {
      print('❌ Firebase Analytics 기능 사용 빈도 이벤트 실패: $e');
    }
  }

  // ===== 헬퍼 메서드 =====
  
  /// 주 시작 날짜 계산
  static DateTime _getWeekStartDate() {
    final now = DateTime.now();
    final daysFromMonday = now.weekday - 1;
    return now.subtract(Duration(days: daysFromMonday));
  }

  /// 월 시작 날짜 계산
  static DateTime _getMonthStartDate() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, 1);
  }

  // ===== 날짜별 집계 이벤트 =====
  
  /// 일일 책 활동 통계 이벤트
  static Future<void> logDailyBookActivity({
    required int booksAdded,
    required int reviewsWritten,
    DateTime? date,
  }) async {
    try {
      final targetDate = date ?? DateTime.now();
      await _analytics.logEvent(
        name: 'daily_book_activity',
        parameters: {
          'books_added_count': booksAdded,
          'reviews_written_count': reviewsWritten,
          'total_activities': booksAdded + reviewsWritten,
          'date': targetDate.toIso8601String().split('T')[0], // YYYY-MM-DD
          'year': targetDate.year,
          'month': targetDate.month,
          'day': targetDate.day,
          'weekday': targetDate.weekday,
          'timestamp': targetDate.toIso8601String(),
        },
      );
    } catch (e) {
      print('❌ Firebase Analytics 일일 책 활동 통계 실패: $e');
    }
  }

  /// 주간 책 활동 요약 이벤트
  static Future<void> logWeeklyBookSummary({
    required int weeklyBooksAdded,
    required int weeklyReviewsWritten,
    DateTime? weekStartDate,
  }) async {
    try {
      final startDate = weekStartDate ?? _getWeekStartDate();
      final endDate = startDate.add(const Duration(days: 6));
      
      await _analytics.logEvent(
        name: 'weekly_book_summary',
        parameters: {
          'weekly_books_added': weeklyBooksAdded,
          'weekly_reviews_written': weeklyReviewsWritten,
          'weekly_total_activities': weeklyBooksAdded + weeklyReviewsWritten,
          'week_start_date': startDate.toIso8601String().split('T')[0],
          'week_end_date': endDate.toIso8601String().split('T')[0],
          'year': startDate.year,
          'week_of_year': _getWeekOfYear(startDate),
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      print('❌ Firebase Analytics 주간 책 활동 요약 실패: $e');
    }
  }

  /// 월간 책 활동 요약 이벤트
  static Future<void> logMonthlyBookSummary({
    required int monthlyBooksAdded,
    required int monthlyReviewsWritten,
    DateTime? monthDate,
  }) async {
    try {
      final targetMonth = monthDate ?? DateTime.now();
      final monthStart = DateTime(targetMonth.year, targetMonth.month, 1);
      
      await _analytics.logEvent(
        name: 'monthly_book_summary',
        parameters: {
          'monthly_books_added': monthlyBooksAdded,
          'monthly_reviews_written': monthlyReviewsWritten,
          'monthly_total_activities': monthlyBooksAdded + monthlyReviewsWritten,
          'month_start_date': monthStart.toIso8601String().split('T')[0],
          'year': targetMonth.year,
          'month': targetMonth.month,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      print('❌ Firebase Analytics 월간 책 활동 요약 실패: $e');
    }
  }

  /// 주차 계산 헬퍼
  static int _getWeekOfYear(DateTime date) {
    final yearStart = DateTime(date.year, 1, 1);
    final daysSinceYearStart = date.difference(yearStart).inDays;
    return ((daysSinceYearStart + yearStart.weekday - 1) / 7).floor() + 1;
  }

  // ===== 커스텀 이벤트 로깅 =====
  
  /// 커스텀 이벤트 로깅
  /// 
  /// 주의: user_id는 setUserId()로 자동 설정되므로 parameters에 포함하지 마세요.
  /// Firebase Analytics가 자동으로 모든 이벤트에 user_id를 추가합니다.
  static Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    try {
      // user_id가 parameters에 포함되어 있다면 제거
      Map<String, Object>? cleanParameters = parameters;
      if (parameters != null && parameters.containsKey('user_id')) {
        cleanParameters = Map.from(parameters);
        cleanParameters.remove('user_id');
        print('⚠️ user_id가 parameters에서 제거되었습니다. setUserId()를 사용하세요.');
      }
      
      await _analytics.logEvent(
        name: name,
        parameters: cleanParameters,
      );
    } catch (e) {
      print('❌ Firebase Analytics 커스텀 이벤트 실패: $e');
    }
  }
} 