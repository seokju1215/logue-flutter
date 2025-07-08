import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:io';

import 'fcm_token_util.dart';

class FcmPermissionUtil {
  static const _key = 'is_fcm_permission_granted';

  static Future<void> requestOnceIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final alreadyGranted = prefs.getBool(_key) ?? false;
    if (alreadyGranted) return;

    try {
      final settings = await FirebaseMessaging.instance.requestPermission();
      print('🔧 알림 권한 상태: ${settings.authorizationStatus}');
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        await prefs.setBool(_key, true);
      }

      if (Platform.isIOS) {
        String? apnsToken;
        do {
          await Future.delayed(const Duration(milliseconds: 500));
          apnsToken = await FirebaseMessaging.instance.getAPNSToken();
        } while (apnsToken == null);
        print('📲 APNs 토큰: $apnsToken');
      }

      final fcmToken = await FirebaseMessaging.instance.getToken();
      print('📱 FCM 토큰: $fcmToken');
      await FcmTokenUtil.updateFcmToken();
    } catch (e) {
      print('❌ FCM 권한 요청 에러: $e');
    }
  }
}