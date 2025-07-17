import 'dart:io';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/material.dart';

class ATTPermissionUtil {
  static Future<void> requestTrackingPermission() async {
    if (!Platform.isIOS) return;

    try {
      // iOS 14.5 이상에서만 ATT 권한 요청
      final status = await AppTrackingTransparency.trackingAuthorizationStatus;

      if (status == TrackingStatus.notDetermined) {
        // 권한이 아직 결정되지 않은 경우 요청
        await AppTrackingTransparency.requestTrackingAuthorization();
      }
    } catch (e) {
      debugPrint('🔍 ATT 권한 요청 실패: $e');
    }
  }

  static Future<TrackingStatus> getTrackingStatus() async {
    if (!Platform.isIOS) return TrackingStatus.authorized;

    try {
      return await AppTrackingTransparency.trackingAuthorizationStatus;
    } catch (e) {
      debugPrint('🔍 ATT 상태 확인 실패: $e');
      return TrackingStatus.denied;
    }
  }
}