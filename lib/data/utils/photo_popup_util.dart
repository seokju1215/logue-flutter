import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/widgets/dialogs/photo_popup_dialog.dart';
import '../models/photo_popup_model.dart';

class PhotoPopupUtil {
  static const _lastShownKey = 'photo_popup_last_shown';
  static const _dontShowTodayKey = 'photo_popup_dont_show_today_';

  /// 사진 팝업을 표시해야 하는지 확인하고 표시
  static Future<void> showIfNeeded(BuildContext context) async {
    final client = Supabase.instance.client;
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    // 오늘 이미 "보지 않기"를 눌렀는지 확인 (전체 팝업 차단)
    final dontShowToday = prefs.getString(_dontShowTodayKey);
    if (dontShowToday != null && _isBlockedToday(dontShowToday)) {
      return; // 오늘은 더 이상 표시하지 않음
    }

    // 📱 플랫폼 정보 가져오기
    final platform = Theme.of(context).platform == TargetPlatform.iOS ? 'ios' : 'android';

    // ✅ Supabase에서 사진 팝업 설정 불러오기 (여러 개)
    final dataList = await client
        .from('photo_popup')
        .select()
        .eq('platform', platform)
        .eq('enabled', true)
        .order('display_order', ascending: true)
        .order('updated_at', ascending: false);

    if (dataList.isEmpty) return; // ❌ 비활성화거나 없음

    // 사진 URL이 있는 팝업들만 필터링하고 개별 차단 상태 확인
    final validPopups = <Map<String, dynamic>>[];
    for (final data in dataList) {
      final photoUrl = data['photo_url'] ?? '';
      if (photoUrl.isEmpty) continue;

      final popupId = data['id'] ?? '';
      final individualDontShowKey = '${_dontShowTodayKey}individual_$popupId';
      final individualDontShow = prefs.getString(individualDontShowKey);
      
      // 개별 팝업이 오늘 차단되지 않은 경우만 추가
      if (individualDontShow == null || !_isBlockedToday(individualDontShow)) {
        validPopups.add(data);
      }
    }

    if (validPopups.isEmpty) return; // 유효한 사진이 없으면 표시하지 않음

    // ✅ 순차적으로 팝업 표시
    _showPopupsSequentially(context, validPopups, prefs, now);
  }

  /// 여러 사진 팝업을 순차적으로 표시
  static Future<void> _showPopupsSequentially(
    BuildContext context,
    List<Map<String, dynamic>> popupDataList,
    SharedPreferences prefs,
    DateTime now,
  ) async {
    for (int i = 0; i < popupDataList.length; i++) {
      final data = popupDataList[i];
      final title = data['title'];
      final description = data['description'];
      final photoUrl = data['photo_url'] ?? '';

      final photoPopup = PhotoPopupModel(
        id: data['id'] ?? '',
        platform: data['platform'] ?? '',
        enabled: data['enabled'] ?? false,
        displayOrder: data['display_order'] ?? 0,
        updatedAt: DateTime.tryParse(data['updated_at'] ?? '') ?? DateTime.now(),
        title: title,
        description: description,
        photoUrl: photoUrl,
      );

      // 마지막 팝업인지 확인
      final isLastPopup = i == popupDataList.length - 1;

      // 팝업 표시
      final result = await showDialog<String>(
        context: context,
        barrierDismissible: true,
        builder: (_) => PhotoPopupDialog(
          photoPopup: photoPopup,
          linkUrl: null, // TODO: 데이터베이스에서 링크 URL 가져오기
        ),
      );

      // "오늘 하루 보지 않기"를 누른 경우
      if (result == 'dont_show_today') {
        // 개별 팝업만 차단
        final popupId = data['id'] ?? '';
        final individualDontShowKey = '${_dontShowTodayKey}individual_$popupId';
        await prefs.setString(individualDontShowKey, now.toIso8601String());
        // 전체 팝업 차단은 하지 않고 계속 진행
      }

      // 마지막 팝업인 경우에만 마지막 표시 시간 업데이트
      if (isLastPopup) {
        await prefs.setString(_lastShownKey, now.toIso8601String());
      }

      // 팝업이 닫힌 후 잠시 대기 (사용자가 인지할 수 있도록)
      if (i < popupDataList.length - 1) {
        await Future.delayed(const Duration(milliseconds: 300));
      }
    }
  }

  /// 오늘 차단되었는지 확인하는 헬퍼 메서드 (한국 시간 기준)
  static bool _isBlockedToday(String? dontShowToday) {
    if (dontShowToday == null) return false;
    
    final dontShowDate = DateTime.tryParse(dontShowToday);
    if (dontShowDate == null) return false;
    
    // 한국 시간대로 변환 (UTC+9)
    final nowKst = DateTime.now().toUtc().add(const Duration(hours: 9));
    final dontShowDateKst = dontShowDate.toUtc().add(const Duration(hours: 9));
    
    // 같은 날인지 확인 (년, 월, 일이 모두 같으면 같은 날)
    return nowKst.year == dontShowDateKst.year &&
           nowKst.month == dontShowDateKst.month &&
           nowKst.day == dontShowDateKst.day;
  }

  /// 사진 팝업 표시 여부를 초기화 (테스트용)
  static Future<void> resetPopupState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastShownKey);
    await prefs.remove(_dontShowTodayKey);
  }

  /// 현재 사진 팝업 상태 확인
  static Future<Map<String, dynamic>> getPopupState() async {
    final prefs = await SharedPreferences.getInstance();
    final lastShown = prefs.getString(_lastShownKey);
    final dontShowToday = prefs.getString(_dontShowTodayKey);
    
    return {
      'lastShown': lastShown,
      'dontShowToday': dontShowToday,
      'isBlockedToday': _isBlockedToday(dontShowToday),
    };
  }
}