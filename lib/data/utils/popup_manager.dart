import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/widgets/dialogs/AnnouncementDialog.dart';
import '../../core/widgets/dialogs/photo_popup_dialog.dart';
import '../models/photo_popup_model.dart';

/// 팝업 우선순위 관리자
/// 1. 사진 팝업 (있으면 우선 표시)
/// 2. 안내 팝업 (사진 팝업이 없거나 표시 후)
class PopupManager {
  static const _announcementLastShownKey = 'announcement_last_shown';
  static const _photoPopupLastShownKey = 'photo_popup_last_shown';
  static const _photoPopupDontShowTodayKey = 'photo_popup_dont_show_today';

  /// 모든 팝업을 우선순위에 따라 표시
  static Future<void> showPopupsIfNeeded(BuildContext context) async {
    // 1. 사진 팝업 먼저 확인
    final photoPopupShown = await _showPhotoPopupIfNeeded(context);
    
    // 2. 사진 팝업 표시 후 안내 팝업 확인 (사진 팝업이 있었든 없었든)
    await _showAnnouncementPopupIfNeeded(context);
  }

  /// 사진 팝업 표시 (있으면)
  static Future<bool> _showPhotoPopupIfNeeded(BuildContext context) async {
    const bool isQA = bool.fromEnvironment('QA_MODE', defaultValue: true);
    debugPrint('🔍 QA 모드: $isQA');
    
    final client = Supabase.instance.client;
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    // 오늘 이미 "보지 않기"를 눌렀는지 확인 (전체 팝업 차단)
    final dontShowToday = prefs.getString(_photoPopupDontShowTodayKey);
    if (dontShowToday != null && _isBlockedToday(dontShowToday)) {
      debugPrint('🔍 오늘 "보지 않기"를 눌러서 photo_popup 차단됨');
      return false; // 오늘은 더 이상 표시하지 않음
    }

    // 플랫폼 정보 가져오기
    final platform = Theme.of(context).platform == TargetPlatform.iOS ? 'ios' : 'android';

    // ✅ Supabase에서 사진 팝업 설정 불러오기 (여러 개)
    debugPrint('🔍 플랫폼: $platform, QA 모드: $isQA');
    final dataList = await client
        .from('photo_popup')
        .select()
        .eq('platform', platform)
        .eq('enabled', true)
        .order('display_order', ascending: true)
        .order('updated_at', ascending: false);

    debugPrint('🔍 photo_popup 데이터베이스 쿼리 결과: ${dataList.length}개');
    if (dataList.isNotEmpty) {
      debugPrint('🔍 첫 번째 데이터: ${dataList.first}');
    }

    if (dataList.isEmpty) {
      debugPrint('🔍 photo_popup 데이터가 없음 - 비활성화거나 없음');
      return false; // ❌ 비활성화거나 없음
    }

    // 사진 URL이 있는 팝업들만 필터링하고 개별 차단 상태 확인
    final validPopups = <Map<String, dynamic>>[];
    for (final data in dataList) {
      final photoUrl = data['photo_url'] ?? '';
      if (photoUrl.isEmpty) {
        debugPrint('🔍 photo_url이 비어있음: ${data['id']}');
        continue;
      }

      final popupId = data['id'] ?? '';
      final individualDontShowKey = '${_photoPopupDontShowTodayKey}individual_$popupId';
      final individualDontShow = prefs.getString(individualDontShowKey);
      
      // 개별 팝업이 오늘 차단되지 않은 경우만 추가
      if (individualDontShow == null || !_isBlockedToday(individualDontShow)) {
        validPopups.add(data);
        debugPrint('🔍 유효한 팝업 추가: $popupId');
      } else {
        debugPrint('🔍 개별 팝업이 오늘 차단됨: $popupId');
      }
    }

    debugPrint('🔍 최종 유효한 팝업 개수: ${validPopups.length}');
    if (validPopups.isEmpty) {
      debugPrint('🔍 유효한 사진이 없음 - 표시하지 않음');
      return false; // 유효한 사진이 없으면 표시하지 않음
    }

    // ✅ 순차적으로 팝업 표시 (비동기 대기)
    await _showPhotoPopupsSequentially(context, validPopups, prefs, now);

    return true; // 사진 팝업이 표시됨
  }

  /// 여러 사진 팝업을 순차적으로 표시
  static Future<void> _showPhotoPopupsSequentially(
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
        link: data['link'], // 링크 필드 추가
        ratio: data['ratio'], // 비율 필드 추가
      );

      // 마지막 팝업인지 확인
      final isLastPopup = i == popupDataList.length - 1;

      // 팝업 표시
      final result = await showDialog<String>(
        context: context,
        barrierDismissible: true,
        builder: (_) => PhotoPopupDialog(
          photoPopup: photoPopup,
        ),
      );

      // "오늘 하루 보지 않기"를 누른 경우
      if (result == 'dont_show_today') {
        // 개별 팝업만 차단
        final popupId = data['id'] ?? '';
        final individualDontShowKey = '${_photoPopupDontShowTodayKey}individual_$popupId';
        await prefs.setString(individualDontShowKey, now.toIso8601String());
        // 전체 팝업 차단은 하지 않고 계속 진행
      }

      // 마지막 팝업인 경우에만 마지막 표시 시간 업데이트
      if (isLastPopup) {
        await prefs.setString(_photoPopupLastShownKey, now.toIso8601String());
      }

      // 팝업이 닫힌 후 잠시 대기 (사용자가 인지할 수 있도록)
      if (i < popupDataList.length - 1) {
        await Future.delayed(const Duration(milliseconds: 300));
      }
    }
  }

  /// 안내 팝업 표시 (사진 팝업이 없거나 표시 후)
  static Future<void> _showAnnouncementPopupIfNeeded(BuildContext context) async {
    final client = Supabase.instance.client;
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    // 오늘 이미 봤는지 확인 (한국 시간 기준)
    final lastShown = DateTime.tryParse(prefs.getString(_announcementLastShownKey) ?? '');
    if (lastShown != null) {
      final nowKst = now.toUtc().add(const Duration(hours: 9));
      final lastShownKst = lastShown.toUtc().add(const Duration(hours: 9));
      
      if (nowKst.year == lastShownKst.year &&
          nowKst.month == lastShownKst.month &&
          nowKst.day == lastShownKst.day) return;
    }

    // 플랫폼 정보 가져오기
    final platform = Theme.of(context).platform == TargetPlatform.iOS ? 'ios' : 'android';

    // Supabase에서 안내 팝업 설정 불러오기
    final data = await client
        .from('announcement_popup')
        .select()
        .eq('platform', platform)
        .eq('enabled', true)
        .order('updated_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (data == null) return; // 비활성화거나 없음

    final title = data['title'] ?? '안내';
    final body = data['body'] ?? '현재 공지사항이 없습니다.';

    // showDialog 호출
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (_) => AnnouncementDialog(title: title, body: body),
      );
    });

    await prefs.setString(_announcementLastShownKey, now.toIso8601String());
  }

  /// 팝업 상태 초기화 (테스트용)
  static Future<void> resetAllPopupStates() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_announcementLastShownKey);
    await prefs.remove(_photoPopupLastShownKey);
    await prefs.remove(_photoPopupDontShowTodayKey);
  }

  /// 현재 팝업 상태 확인
  static Future<Map<String, dynamic>> getAllPopupStates() async {
    final prefs = await SharedPreferences.getInstance();
    final announcementLastShown = prefs.getString(_announcementLastShownKey);
    final photoPopupLastShown = prefs.getString(_photoPopupLastShownKey);
    final photoPopupDontShowToday = prefs.getString(_photoPopupDontShowTodayKey);
    
    return {
      'announcementLastShown': announcementLastShown,
      'photoPopupLastShown': photoPopupLastShown,
      'photoPopupDontShowToday': photoPopupDontShowToday,
      'isPhotoPopupBlockedToday': _isPhotoPopupBlockedToday(photoPopupDontShowToday),
    };
  }

  /// 오늘 차단되었는지 확인하는 헬퍼 메서드 (한국 시간 기준)
  static bool _isBlockedToday(String dontShowToday) {
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

  static bool _isPhotoPopupBlockedToday(String? dontShowToday) {
    if (dontShowToday == null) return false;
    return _isBlockedToday(dontShowToday);
  }
}