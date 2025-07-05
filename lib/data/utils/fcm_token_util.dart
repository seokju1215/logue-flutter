import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FcmTokenUtil {
  /// 로그인 후 또는 앱 실행 시 호출
  static Future<void> updateFcmToken() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) return;

    try {
      await Supabase.instance.client
          .from('profiles')
          .update({'fcm_token': token})
          .eq('id', user.id);
      print('✅ FCM 토큰 Supabase에 저장 완료');
    } catch (e) {
      print('❌ FCM 토큰 저장 실패: $e');
    }
  }

  /// 토큰이 변경될 때마다 자동 갱신
  static void listenTokenRefresh() {
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        await Supabase.instance.client
            .from('profiles')
            .update({'fcm_token': newToken})
            .eq('id', user.id);
        print('🔁 FCM 토큰 갱신됨');
      }
    });
  }
}