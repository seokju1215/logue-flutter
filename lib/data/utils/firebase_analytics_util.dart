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
  
  /// GA4 UI용 커스텀 파라미터 값 (uid)
  static String? _uid;

  /// 표준 user_id(신원 결합/BigQuery) + UI용 uid 동시 세팅
  static Future<void> setUserId({String? id}) async {
    _uid = id;
    debugPrint('🔥 setUserId 호출됨: _uid = $_uid');
    await _analytics.setUserId(id: id);
  }

  /// Analytics 수집 활성화/비활성화
  static Future<void> setAnalyticsCollectionEnabled(bool enabled) async {
    try {
      await _analytics.setAnalyticsCollectionEnabled(enabled);
      debugPrint('📊 Analytics 수집 ${enabled ? '활성화' : '비활성화'} 완료');
    } catch (e) {
      debugPrint('❌ Analytics 수집 설정 실패: $e');
    }
  }

  /// 공통 파라미터 전처리: user_id 제거 + logue_user_id 자동 주입
  static Map<String, Object>? _injectUid(Map<String, Object>? params) {
    debugPrint('🔥 _injectUid 호출됨 - _uid: $_uid');
    final map = {...(params ?? const {})};
    debugPrint('🔥 _injectUid 입력 파라미터: $map');
    // 실수 방지: 표준 user_id 키는 제거 (GA4는 setUserId로만)
    map.remove('user_id');
    if (_uid != null && _uid!.isNotEmpty) {
      map['logue_user_id'] = _uid!;
      debugPrint('🔥 _injectUid: logue_user_id 주입됨 = $_uid');
    } else {
      debugPrint('⚠️ _injectUid: _uid가 null이거나 비어있음 = $_uid');
    }
    debugPrint('🔥 _injectUid 최종 파라미터: $map');
    // 권장: 파라미터 25개 제한 고려 (필요시 정리 로직 추가)
    return map.isEmpty ? null : map;
  }

  /// 모든 커스텀 이벤트 전송 엔트리포인트
  static Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    try {
      debugPrint('🔥 logEvent 호출됨: $name, _uid: $_uid');
      debugPrint('🔥 logEvent 입력 파라미터: $parameters');
      
      // logue_user_id가 항상 포함되도록 보장
      final finalParams = _injectUid(parameters) ?? <String, Object>{};
      
      // _uid가 없으면 현재 사용자 ID를 가져와서 설정
      String? currentUserId = _uid;
      if (currentUserId == null || currentUserId.isEmpty) {
        try {
          final user = Supabase.instance.client.auth.currentUser;
          currentUserId = user?.id;
          if (currentUserId != null) {
            _uid = currentUserId; // 다음번을 위해 저장
            debugPrint('🔥 logEvent: _uid가 없어서 현재 사용자 ID로 설정 = $currentUserId');
          }
        } catch (e) {
          debugPrint('⚠️ logEvent: 현재 사용자 ID 가져오기 실패: $e');
        }
      }
      
      if (currentUserId != null && currentUserId.isNotEmpty) {
        finalParams['logue_user_id'] = currentUserId;
        debugPrint('🔥 logEvent: logue_user_id 추가 = $currentUserId');
      } else {
        debugPrint('⚠️ logEvent: logue_user_id를 추가할 수 없음 (사용자 ID 없음)');
      }
      
      debugPrint('🔥 logEvent 최종 파라미터: $finalParams');
      
      await _analytics.logEvent(
        name: name,
        parameters: finalParams,
      );
      
      debugPrint('✅ logEvent 전송 완료: $name');
    } catch (e) {
      debugPrint('❌ Firebase Analytics 이벤트 실패($name): $e');
    }
  }
  
  // ===== 사용자 인증 및 기본 이벤트 =====
  
  /// 사용자 로그인 이벤트
  static Future<void> logLogin({
    required String method,
    String? userId,
  }) async {
    try {
      await _analytics.logLogin(loginMethod: method);
      if (userId != null) await setUserId(id: userId);
      await logEvent(name: 'login', parameters: {
        'method': method,
      });
    } catch (e) {
      debugPrint('❌ 로그인 이벤트 실패: $e');
    }
  }

  /// 사용자 로그아웃 이벤트
  static Future<void> logLogout() async {
    try {
      await logEvent(name: 'user_logout');
      await setUserId(id: null);
    } catch (e) {
      debugPrint('❌ 로그아웃 이벤트 실패: $e');
    }
  }

  /// 사용자 회원가입 이벤트
  static Future<void> logSignUp({
    required String method,
    String? userId,
  }) async {
    try {
      await _analytics.logSignUp(signUpMethod: method);
      if (userId != null) await setUserId(id: userId);
      await logEvent(name: 'sign_up', parameters: {
        'method': method,
      });
    } catch (e) {
      debugPrint('❌ 회원가입 이벤트 실패: $e');
    }
  }

  /// 사용자 계정 탈퇴 이벤트
  static Future<void> logAccountDeletion({
    String? reason,
  }) async {
    try {
      await logEvent(
        name: 'user_account_deletion',
        parameters: {
          'reason': reason ?? '',
        },
      );
      await setUserId(id: null);
    } catch (e) {
      debugPrint('❌ 계정 탈퇴 이벤트 실패: $e');
    }
  }

  // ===== 앱 사용 및 세션 이벤트 =====
  
  /// 앱 시작 이벤트
  static Future<void> logAppOpen() async {
    try {
      await _analytics.logAppOpen();
      await logEvent(name: 'app_open');
    } catch (e) {
      debugPrint('❌ 앱 시작 이벤트 실패: $e');
    }
  }

  /// 세션 시작 이벤트
  static Future<void> logSessionStart({
    String? userId,
    String? sessionId,
  }) async {
    try {
      await logEvent(
        name: 'app_session_start',
        parameters: {
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
      await logEvent(
        name: 'app_session_end',
        parameters: {
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
  }) async {
    try {
      await _analytics.logScreenView(
        screenName: screenName,
        screenClass: screenClass,
      );
      await logEvent(name: 'screen_view', parameters: {
        'screen_name': screenName,
        'screen_class': screenClass ?? '',
      });
    } catch (e) {
      debugPrint('❌ 화면 전환 이벤트 실패: $e');
    }
  }

  // ===== 팔로우 관련 이벤트 =====
  
  /// 사용자 팔로우 이벤트
  static Future<void> logFollowUser({
    required String targetUserId,
    required String targetUsername,
    String? sourceScreen, // 어느 화면에서 팔로우했는지
  }) async {
    try {
      final now = DateTime.now();
      final parameters = {
        'target_user_id': targetUserId,
        'target_username': targetUsername,
        'source_screen': sourceScreen ?? 'unknown',
        'timestamp': now.toIso8601String(),
        'date': now.toIso8601String().split('T')[0], // YYYY-MM-DD
        'year': now.year,
        'month': now.month,
        'day': now.day,
        'weekday': now.weekday, // 1=Monday, 7=Sunday
      };
      
      debugPrint('🔥🔥🔥 Firebase Analytics 이벤트 전송 시작: follow_user');
      debugPrint('👤 대상 사용자: $targetUsername ($targetUserId)');
      debugPrint('📱 소스 화면: $sourceScreen');
      debugPrint('📊 파라미터: $parameters');
      
      await logEvent(
        name: 'follow_user',
        parameters: parameters,
      );
      
      debugPrint('✅✅✅ Firebase Analytics 이벤트 전송 완료: follow_user');
    } catch (e) {
      debugPrint('❌ Firebase Analytics 팔로우 이벤트 실패: $e');
    }
  }

  /// 사용자 언팔로우 이벤트
  static Future<void> logUnfollowUser({
    required String targetUserId,
    required String targetUsername,
    String? sourceScreen, // 어느 화면에서 언팔로우했는지
  }) async {
    try {
      final now = DateTime.now();
      final parameters = {
        'target_user_id': targetUserId,
        'target_username': targetUsername,
        'source_screen': sourceScreen ?? 'unknown',
        'timestamp': now.toIso8601String(),
        'date': now.toIso8601String().split('T')[0], // YYYY-MM-DD
        'year': now.year,
        'month': now.month,
        'day': now.day,
        'weekday': now.weekday, // 1=Monday, 7=Sunday
      };
      
      debugPrint('🔥 Firebase Analytics 이벤트 전송 시작: unfollow_user');
      debugPrint('👤 대상 사용자: $targetUsername ($targetUserId)');
      debugPrint('📱 소스 화면: $sourceScreen');
      debugPrint('📊 파라미터: $parameters');
      
      await logEvent(
        name: 'unfollow_user',
        parameters: parameters,
      );
      
      debugPrint('✅ Firebase Analytics 이벤트 전송 완료: unfollow_user');
    } catch (e) {
      debugPrint('❌ Firebase Analytics 언팔로우 이벤트 실패: $e');
    }
  }

  /// 프로필 링크 복사 이벤트 (내 프로필 화면)
  static Future<void> logProfileLinkCopy({
    String? sharedUserId, // 공유된 사용자 ID
    String? sharedUsername, // 공유된 사용자명
  }) async {
    try {
      final now = DateTime.now();
      final parameters = {
        'shared_user_id': sharedUserId ?? '',
        'shared_username': sharedUsername ?? '',
        'timestamp': now.toIso8601String(),
        'date': now.toIso8601String().split('T')[0], // YYYY-MM-DD
        'year': now.year,
        'month': now.month,
        'day': now.day,
        'weekday': now.weekday, // 1=Monday, 7=Sunday
      };
      
      debugPrint('🔥 Firebase Analytics 이벤트 전송 시작: profile_link_copy');
      debugPrint('👤 공유된 사용자: $sharedUsername ($sharedUserId)');
      debugPrint('📊 파라미터: $parameters');
      
      await logEvent(
        name: 'profile_link_copy',
        parameters: parameters,
      );
      
      debugPrint('✅ Firebase Analytics 이벤트 전송 완료: profile_link_copy');
    } catch (e) {
      debugPrint('❌ Firebase Analytics 프로필 링크 복사 이벤트 실패: $e');
    }
  }

  /// 다른 사용자 프로필 공유 이벤트
  static Future<void> logOtherProfileShare({
    String? sharedUserId, // 공유된 사용자 ID
    String? sharedUsername, // 공유된 사용자명
  }) async {
    try {
      final now = DateTime.now();
      final parameters = {
        'shared_user_id': sharedUserId ?? '',
        'shared_username': sharedUsername ?? '',
        'timestamp': now.toIso8601String(),
        'date': now.toIso8601String().split('T')[0], // YYYY-MM-DD
        'year': now.year,
        'month': now.month,
        'day': now.day,
        'weekday': now.weekday, // 1=Monday, 7=Sunday
      };
      
      debugPrint('🔥 Firebase Analytics 이벤트 전송 시작: other_profile_share');
      debugPrint('👤 공유된 사용자: $sharedUsername ($sharedUserId)');
      debugPrint('📊 파라미터: $parameters');
      
      await logEvent(
        name: 'other_profile_share',
        parameters: parameters,
      );
      
      debugPrint('✅ Firebase Analytics 이벤트 전송 완료: other_profile_share');
    } catch (e) {
      debugPrint('❌ Firebase Analytics 다른 사용자 프로필 공유 이벤트 실패: $e');
    }
  }

  /// 친구 초대 이벤트
  static Future<void> logFriendInvite({
    String? sharedUserId, // 공유된 사용자 ID
    String? sharedUsername, // 공유된 사용자명
  }) async {
    try {
      final now = DateTime.now();
      final parameters = {
        'shared_user_id': sharedUserId ?? '',
        'shared_username': sharedUsername ?? '',
        'timestamp': now.toIso8601String(),
        'date': now.toIso8601String().split('T')[0], // YYYY-MM-DD
        'year': now.year,
        'month': now.month,
        'day': now.day,
        'weekday': now.weekday, // 1=Monday, 7=Sunday
      };
      
      debugPrint('🔥 Firebase Analytics 이벤트 전송 시작: friend_invite');
      debugPrint('👤 공유된 사용자: $sharedUsername ($sharedUserId)');
      debugPrint('📊 파라미터: $parameters');
      
      await logEvent(
        name: 'friend_invite',
        parameters: parameters,
      );
      
      debugPrint('✅ Firebase Analytics 이벤트 전송 완료: friend_invite');
    } catch (e) {
      debugPrint('❌ Firebase Analytics 친구 초대 이벤트 실패: $e');
    }
  }

  /// 프로필 링크 복사 이벤트
  static Future<void> logCopyProfileLink({
    required String sourceScreen, // 어느 화면에서 복사했는지
    String? userId, // 복사한 사용자 ID
    String? username, // 복사한 사용자명
    String? copiedLink, // 복사된 링크
  }) async {
    try {
      final now = DateTime.now();
      final parameters = {
        'source_screen': sourceScreen,
        'username': username ?? '',
        'copied_link': copiedLink ?? '',
        'timestamp': now.toIso8601String(),
        'date': now.toIso8601String().split('T')[0], // YYYY-MM-DD
        'year': now.year,
        'month': now.month,
        'day': now.day,
        'weekday': now.weekday, // 1=Monday, 7=Sunday
      };
      
      debugPrint('🔥 Firebase Analytics 이벤트 전송 시작: copy_profile_link');
      debugPrint('📱 소스 화면: $sourceScreen');
      debugPrint('👤 사용자: $username ($userId)');
      debugPrint('🔗 복사된 링크: $copiedLink');
      debugPrint('📊 파라미터: $parameters');
      
      await logEvent(
        name: 'copy_profile_link',
        parameters: parameters,
      );
      
      debugPrint('✅ Firebase Analytics 이벤트 전송 완료: copy_profile_link');
    } catch (e) {
      debugPrint('❌ Firebase Analytics 프로필 링크 복사 이벤트 실패: $e');
    }
  }

  /// 친구 찾기 버튼 클릭 이벤트
  static Future<void> logFindFriendsClick({
    required String sourceScreen, // 어느 화면에서 클릭했는지
    String? userId, // 클릭한 사용자 ID
  }) async {
    try {
      final now = DateTime.now();
      final parameters = {
        'source_screen': sourceScreen,
        'timestamp': now.toIso8601String(),
        'date': now.toIso8601String().split('T')[0], // YYYY-MM-DD
        'year': now.year,
        'month': now.month,
        'day': now.day,
        'weekday': now.weekday, // 1=Monday, 7=Sunday
      };
      
      debugPrint('🔥 Firebase Analytics 이벤트 전송 시작: find_friends_click');
      debugPrint('📱 소스 화면: $sourceScreen');
      debugPrint('👤 사용자 ID: $userId');
      debugPrint('📊 파라미터: $parameters');
      
      await logEvent(
        name: 'find_friends_click',
        parameters: parameters,
      );
      
      debugPrint('✅ Firebase Analytics 이벤트 전송 완료: find_friends_click');
    } catch (e) {
      debugPrint('❌ Firebase Analytics 친구 찾기 클릭 이벤트 실패: $e');
    }
  }

  /// 사용자 이름 변경 이벤트
  static Future<void> logUsernameChange({
    required String oldUsername, // 기존 사용자 이름
    required String newUsername, // 새로운 사용자 이름
    String? userId, // 사용자 ID
  }) async {
    try {
      final now = DateTime.now();
      final parameters = {
        'old_username': oldUsername,
        'new_username': newUsername,
        'username_length': newUsername.length,
        'has_special_chars': newUsername.contains(RegExp(r'[^a-zA-Z0-9_]')) ? 'true' : 'false',
        'has_numbers': newUsername.contains(RegExp(r'[0-9]')) ? 'true' : 'false',
        'timestamp': now.toIso8601String(),
        'date': now.toIso8601String().split('T')[0], // YYYY-MM-DD
        'year': now.year,
        'month': now.month,
        'day': now.day,
        'weekday': now.weekday, // 1=Monday, 7=Sunday
      };
      
      debugPrint('🔥 Firebase Analytics 이벤트 전송 시작: username_change');
      debugPrint('👤 기존 사용자명: $oldUsername');
      debugPrint('🆕 새로운 사용자명: $newUsername');
      debugPrint('📊 파라미터: $parameters');
      
      await logEvent(
        name: 'username_change',
        parameters: parameters,
      );
      
      debugPrint('✅ Firebase Analytics 이벤트 전송 완료: username_change');
    } catch (e) {
      debugPrint('❌ Firebase Analytics 사용자명 변경 이벤트 실패: $e');
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
      await logEvent(
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
      
      await logEvent(
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
      await logEvent(
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
      await logEvent(
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
      await logEvent(
        name: 'book_moved',
        parameters: {
          'book_title': bookTitle,
          'book_author': bookAuthor,
          'from_location': fromLocation,
          'to_location': toLocation,
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
      await logEvent(
        name: 'book_move_button_clicked',
        parameters: {
          'from_location': fromLocation,
          'to_location': toLocation,
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
      await logEvent(
        name: 'user_follow_action',
        parameters: {
          'target_user_id': targetUserId,
          'action': action,
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
      await logEvent(
        name: 'follow_count_change',
        parameters: {
          'followers_count': followersCount,
          'following_count': followingCount,
          'timestamp': DateTime.now().toIso8601String(),
          'date': DateTime.now().toIso8601String().split('T')[0],
        },
      );
    } catch (e) {
      print('❌ Firebase Analytics 팔로우 수 변경 이벤트 실패: $e');
    }
  }

  // ===== 공유 및 바이럴 기능 이벤트 =====

  /// 친구 초대 이벤트 (기존)
  static Future<void> logFriendInvited({
    required String inviteMethod, // 'contacts', 'phone_number', 'link'
    String? userId,
  }) async {
    try {
      await logEvent(
        name: 'friend_invited',
        parameters: {
          'invite_method': inviteMethod,
          'timestamp': DateTime.now().toIso8601String(),
          'date': DateTime.now().toIso8601String().split('T')[0],
        },
      );
    } catch (e) {
      print('❌ Firebase Analytics 친구 초대 이벤트 실패: $e');
    }
  }

  /// 프로필 링크 복사 이벤트 (기존)
  static Future<void> logProfileLinkCopied({
    String? userId,
  }) async {
    try {
      await logEvent(
        name: 'profile_link_copied',
        parameters: {
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
      await logEvent(
        name: 'friend_search_clicked',
        parameters: {
          'search_method': searchMethod,
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
      await logEvent(
        name: 'search_performed',
        parameters: {
          'search_term': searchTerm,
          'search_type': searchType,
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
      await logEvent(
        name: 'profile_changed',
        parameters: {
          'change_type': changeType,
          'old_value': oldValue ?? '',
          'new_value': newValue ?? '',
          'timestamp': DateTime.now().toIso8601String(),
          'date': DateTime.now().toIso8601String().split('T')[0],
        },
      );
    } catch (e) {
      print('❌ Firebase Analytics 프로필 변경 이벤트 실패: $e');
    }
  }



  /// 프로필 사진 변경 이벤트
  static Future<void> logProfilePhotoChange({
    String? userId,
    String? oldAvatarUrl, // 기존 아바타 URL
    String? newAvatarUrl, // 새로운 아바타 URL
    String? changeType,   // 'upload', 'select_preset', 'remove'
  }) async {
    try {
      final now = DateTime.now();
      final parameters = {
        'old_avatar_url': oldAvatarUrl ?? '',
        'new_avatar_url': newAvatarUrl ?? '',
        'change_type': changeType ?? 'unknown',
        'is_custom_upload': (newAvatarUrl?.contains('supabase') == true) ? 'true' : 'false',
        'is_default_avatar': (newAvatarUrl == 'basic' || newAvatarUrl?.isEmpty == true) ? 'true' : 'false',
        'timestamp': now.toIso8601String(),
        'date': now.toIso8601String().split('T')[0], // YYYY-MM-DD
        'year': now.year,
        'month': now.month,
        'day': now.day,
        'weekday': now.weekday, // 1=Monday, 7=Sunday
      };
      
      debugPrint('🔥 Firebase Analytics 이벤트 전송 시작: profile_photo_change');
      debugPrint('📸 변경 타입: $changeType');
      debugPrint('🖼️ 기존 아바타: $oldAvatarUrl');
      debugPrint('🆕 새로운 아바타: $newAvatarUrl');
      debugPrint('📊 파라미터: $parameters');
      
      await logEvent(
        name: 'profile_photo_change',
        parameters: parameters,
      );
      
      debugPrint('✅ Firebase Analytics 이벤트 전송 완료: profile_photo_change');
    } catch (e) {
      debugPrint('❌ Firebase Analytics 프로필 사진 변경 이벤트 실패: $e');
    }
  }

  // ===== 광고 및 수익화 이벤트 =====
  
  /// 배너 클릭 이벤트
  static Future<void> logBannerClick({
    required String bannerId,      // 배너 고유 ID
    required String bannerType,    // 배너 타입 (ad, promotion, feature 등)
    required String sourceScreen,  // 어느 화면에서 클릭했는지
    String? bannerTitle,           // 배너 제목
    String? bannerUrl,             // 배너 링크 URL
    String? position,              // 배너 위치 (top, middle, bottom)
  }) async {
    try {
      final now = DateTime.now();
      final parameters = {
        'banner_id': bannerId,
        'banner_type': bannerType,
        'source_screen': sourceScreen,
        'banner_title': bannerTitle ?? '',
        'banner_url': bannerUrl ?? '',
        'position': position ?? 'unknown',
        'timestamp': now.toIso8601String(),
        'date': now.toIso8601String().split('T')[0], // YYYY-MM-DD
      };
      
      debugPrint('🔥 Firebase Analytics 이벤트 전송 시작: banner_click');
      debugPrint('🎯 배너 ID: $bannerId');
      debugPrint('📱 소스 화면: $sourceScreen');
      debugPrint('🏷️ 배너 타입: $bannerType');
      debugPrint('📍 배너 위치: $position');
      debugPrint('📊 파라미터: $parameters');
      
      await logEvent(
        name: 'banner_click',
        parameters: parameters,
      );
      
      debugPrint('✅ Firebase Analytics 이벤트 전송 완료: banner_click');
    } catch (e) {
      debugPrint('❌ Firebase Analytics 배너 클릭 이벤트 실패: $e');
    }
  }

  /// 앱 시작 이벤트
  static Future<void> logAppStart({
    required String appVersion,
    required String buildNumber,
    String? userId,
    String? platform, // 'android', 'ios'
  }) async {
    try {
      final now = DateTime.now();
      final parameters = {
        'app_version': appVersion,
        'build_number': buildNumber,
        'platform': platform ?? 'unknown',
        'timestamp': now.toIso8601String(),
        'date': now.toIso8601String().split('T')[0], // YYYY-MM-DD
        'year': now.year,
        'month': now.month,
        'day': now.day,
        'weekday': now.weekday, // 1=Monday, 7=Sunday
      };
      
      // user_id는 별도로 설정 (파라미터에 포함하지 않음)
      if (userId != null) {
        await _analytics.setUserId(id: userId);
      }
      
      debugPrint('🔥🔥🔥 Firebase Analytics 이벤트 전송 시작: app_start');
      debugPrint('📱 앱 버전: $appVersion');
      debugPrint('🔢 빌드 번호: $buildNumber');
      debugPrint('🖥️ 플랫폼: $platform');
      debugPrint('👤 사용자 ID: $userId');
      debugPrint('📊 전송할 파라미터: $parameters');
      
      await logEvent(
        name: 'app_start',
        parameters: parameters,
      );
      
      debugPrint('✅✅✅ Firebase Analytics 이벤트 전송 완료: app_start');
      debugPrint('🎯 이벤트명: app_start');
      debugPrint('🎯 전송된 버전: $appVersion');
      debugPrint('🎯 전송된 빌드: $buildNumber');
    } catch (e) {
      debugPrint('❌ Firebase Analytics 앱 시작 이벤트 실패: $e');
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
      await logEvent(
        name: 'customer_inquiry',
        parameters: {
          'inquiry_type': inquiryType,
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
      await logEvent(
        name: 'app_version_info',
        parameters: {
          'app_version': appVersion,
          'build_number': buildNumber,
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
        'timestamp': DateTime.now().toIso8601String(),
        'date': DateTime.now().toIso8601String().split('T')[0],
      };
      
      // behaviorData의 모든 값을 Object로 변환
      for (final entry in behaviorData.entries) {
        parameters[entry.key] = entry.value ?? '';
      }
      
      await logEvent(
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
      await logEvent(
        name: 'user_retention',
        parameters: {
          'days_since_last_visit': daysSinceLastVisit,
          'retention_type': retentionType,
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
      await logEvent(
        name: 'user_churn',
        parameters: {
          'days_inactive': daysInactive,
          'churn_reason': churnReason,
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
      await logEvent(
        name: 'time_based_access',
        parameters: {
          'day_of_week': dayOfWeek,
          'hour': hour,
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
      await logEvent(
        name: 'daily_active_user',
        parameters: {
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
      await logEvent(
        name: 'weekly_active_user',
        parameters: {
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
      await logEvent(
        name: 'monthly_active_user',
        parameters: {
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
      await logEvent(
        name: 'new_user_registration',
        parameters: {
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
      await logEvent(
        name: 'profile_creation',
        parameters: {
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
        'content_type': contentType,
        'content_id': contentId,
        'timestamp': DateTime.now().toIso8601String(),
        'date': DateTime.now().toIso8601String().split('T')[0],
      };
      
      // contentMetadata의 모든 값을 Object로 변환
      for (final entry in contentMetadata.entries) {
        parameters[entry.key] = entry.value ?? '';
      }
      
      await logEvent(
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
      await logEvent(
        name: 'ugc_interaction',
        parameters: {
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
      await logEvent(
        name: 'app_usage_time',
        parameters: {
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
      await logEvent(
        name: 'feature_usage_frequency',
        parameters: {
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
      await logEvent(
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
      
      await logEvent(
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
      
      await logEvent(
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
} 