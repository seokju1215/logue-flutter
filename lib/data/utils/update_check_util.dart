import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/widgets/dialogs/update_required_dialog.dart';


class UpdateCheckUtil {
  static Future<void> checkForUpdate(BuildContext context) async {
    final client = Supabase.instance.client;
    final packageInfo = await PackageInfo.fromPlatform();

    final currentVersion = packageInfo.version;
    final platform = Theme.of(context).platform == TargetPlatform.iOS ? 'ios' : 'android';

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