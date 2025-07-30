import 'package:mixpanel_flutter/mixpanel_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class MixpanelUtil {
  static Mixpanel? _mixpanel;
  static bool _isTrackingEnabled = true;
  
  static Future<void> initialize() async {
    final token = dotenv.env['MIXPANEL_PROJECT_TOKEN'];
    if (token == null) {
      print('⚠️ MIXPANEL_TOKEN이 설정되지 않았습니다.');
      return;
    }
    
    // 항상 추적 허용
    _isTrackingEnabled = true;
    
    if (_isTrackingEnabled) {
    _mixpanel = await Mixpanel.init(token, trackAutomaticEvents: true);
      print('📊 Mixpanel 초기화 완료 (추적 허용)');
    } else {
      print('📊 Mixpanel 초기화 건너뜀 (추적 거부)');
    }
  }
  
  static Mixpanel? get instance => _mixpanel;
  
  // 사용자 식별
  static void identify(String userId) {
    if (!_isTrackingEnabled) {
      print('📊 사용자 식별 건너뜀 (추적 거부): $userId');
      return;
    }
    _mixpanel?.identify(userId);
    print('📊 사용자 식별: $userId');
  }
  
  // 사용자 속성 설정
  static void setUserProperties(Map<String, dynamic> properties) {
    if (!_isTrackingEnabled) {
      print('📊 사용자 속성 설정 건너뜀 (추적 거부): $properties');
      return;
    }
    // Mixpanel Flutter SDK에서는 setUserProperties 대신 track으로 사용자 속성 설정
    _mixpanel?.track('User Properties', properties: properties);
    print('📊 사용자 속성 설정: $properties');
  }
  
  // 이벤트 트래킹
  static void track(String eventName, {Map<String, dynamic>? properties}) {
    if (!_isTrackingEnabled) {
      print('📊 이벤트 트래킹 건너뜀 (추적 거부): $eventName');
      return;
    }
    _mixpanel?.track(eventName, properties: properties);
    print('📊 이벤트 트래킹: $eventName ${properties ?? {}}');
  }
  
  // 화면 방문 트래킹
  static void trackScreenView(String screenName) {
    track('Screen View', properties: {'screen_name': screenName});
  }
  
  // 앱 시작 트래킹
  static void trackAppOpen() {
    track('App Open');
  }
  
  // 로그인 트래킹
  static void trackLogin(String method) {
    track('Login', properties: {'method': method});
  }
  
  // 로그아웃 트래킹
  static void trackLogout() {
    track('Logout');
  }
  
  // 책 추가 트래킹
  static void trackBookAdd(String bookTitle, String bookId) {
    track('Book Add', properties: {
      'book_title': bookTitle,
      'book_id': bookId,
    });
  }
  
  // 책 검색 트래킹
  static void trackBookSearch(String query) {
    track('Book Search', properties: {'query': query});
  }
  
  // 리뷰 작성 트래킹
  static void trackReviewWrite(String bookTitle, String bookId) {
    track('Review Write', properties: {
      'book_title': bookTitle,
      'book_id': bookId,
    });
  }
  
  // 팔로우 트래킹
  static void trackFollow(String targetUserId) {
    track('Follow', properties: {'target_user_id': targetUserId});
  }
  
  // 언팔로우 트래킹
  static void trackUnfollow(String targetUserId) {
    track('Unfollow', properties: {'target_user_id': targetUserId});
  }
  
  // 프로필 편집 트래킹
  static void trackProfileEdit(String field) {
    track('Profile Edit', properties: {'field': field});
  }
  
  // 알림 클릭 트래킹
  static void trackNotificationClick(String notificationType) {
    track('Notification Click', properties: {'notification_type': notificationType});
  }
  
  // 공유 트래킹
  static void trackShare(String contentType, String contentId) {
    track('Share', properties: {
      'content_type': contentType,
      'content_id': contentId,
    });
  }
  
  // 앱 종료 트래킹
  static void trackAppClose() {
    track('App Close');
  }
} 