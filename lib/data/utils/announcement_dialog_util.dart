import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/widgets/dialogs/AnnouncementDialog.dart';

class AnnouncementDialogUtil {
  static const _lastShownKey = 'announcement_last_shown';

  static Future<void> showIfNeeded(BuildContext context) async {
    final client = Supabase.instance.client;
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    // 📦 오늘 이미 봤는지 확인
    final lastShown = DateTime.tryParse(prefs.getString(_lastShownKey) ?? '');
    if (lastShown != null &&
        now.difference(lastShown).inHours < 24 &&
        now.day == lastShown.day) return;

    // 📱 플랫폼 정보 가져오기
    final packageInfo = await PackageInfo.fromPlatform();
    final platform = Theme.of(context).platform == TargetPlatform.iOS ? 'ios' : 'android';

    // ✅ Supabase에서 팝업 설정 불러오기
    final data = await client
        .from('announcement_popup')
        .select()
        .eq('platform', platform)
        .eq('enabled', true)
        .order('updated_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (data == null) return; // ❌ 비활성화거나 없음

    final title = data['title'] ?? '안내';
    final body = data['body'] ?? '현재 공지사항이 없습니다.';

    // ✅ showDialog 호출
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (_) => AnnouncementDialog(title: title, body: body),
      );
    });

    await prefs.setString(_lastShownKey, now.toIso8601String());
  }
}