import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/widgets/dialogs/update_required_dialog.dart';


class UpdateCheckUtil {
  static Future<String> getCurrentAppVersion() async {
  final packageInfo = await PackageInfo.fromPlatform();
  return packageInfo.version;
  }


  static Future<void> checkForUpdate(BuildContext context) async {
    final client = Supabase.instance.client;
    final packageInfo = await PackageInfo.fromPlatform();

    final currentVersion = packageInfo.version;
    final platform = Theme.of(context).platform == TargetPlatform.iOS ? 'ios' : 'android';

    // 사용자별 업데이트 팝업 표시 제한 체크
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    final prefs = await SharedPreferences.getInstance();
    final updateCountKey = 'update_popup_count_$userId';
    final lastShownKey = 'update_popup_last_shown_$userId';
    
    final updateCount = prefs.getInt(updateCountKey) ?? 0;
    final lastShownStr = prefs.getString(lastShownKey);
    final now = DateTime.now();
    
    // 평생 2회 제한 체크
    if (updateCount >= 2) {
      debugPrint('📢 업데이트 팝업 제한 도달: $updateCount/2');
      return;
    }
    
    // 하루에 한 번만 표시 체크
    if (lastShownStr != null) {
      final lastShown = DateTime.tryParse(lastShownStr);
      if (lastShown != null && 
          now.difference(lastShown).inHours < 24 && 
          now.day == lastShown.day) {
        debugPrint('📢 업데이트 팝업 오늘 이미 표시됨');
        return;
      }
    }

    final result = await client
        .from('app_updates')
        .select()
        .eq('platform', platform)
        .maybeSingle();
    debugPrint('📦 현재 버전: $currentVersion');
    debugPrint('🧪 Supabase 응답: $result');

    if (result == null || result['show_popup'] != true) return;

    final minVersion = result['min_supported_version'];
    final latestVersion = result['latest_version'];
    final title = result['title'] ?? '업데이트 안내';
    final body = result['body'] ?? '새로운 기능과 안정성을 위해 업데이트가 필요합니다.';
    final forceUpdate = result['force_update'] ?? false;
    final storeUrl = result['store_url'];

    if (_compareVersion(currentVersion, minVersion) < 0 ||
        (_compareVersion(currentVersion, latestVersion) < 0 && result['show_popup'])) {
      if (context.mounted) {
        await showDialog(
          context: context,
          barrierDismissible: !forceUpdate,
          builder: (_) => UpdateRequiredDialog(
            title: title,
            body: body,
            storeUrl: storeUrl,
            forceUpdate: forceUpdate,
          ),
        );
        
        // 팝업 표시 후 카운트 및 날짜 업데이트
        await prefs.setInt(updateCountKey, updateCount + 1);
        await prefs.setString(lastShownKey, now.toIso8601String());
        debugPrint('📢 업데이트 팝업 표시: ${updateCount + 1}/2');
      }
    }
  }

  // 1.2.3 < 1.3.0 -> return -1
  static int _compareVersion(String v1, String v2) {
    final parts1 = v1.split('.').map(int.parse).toList();
    final parts2 = v2.split('.').map(int.parse).toList();

    for (int i = 0; i < 3; i++) {
      final a = i < parts1.length ? parts1[i] : 0;
      final b = i < parts2.length ? parts2[i] : 0;
      if (a != b) return a.compareTo(b);
    }
    return 0;
  }
}