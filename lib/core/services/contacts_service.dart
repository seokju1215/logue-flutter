import 'package:permission_handler/permission_handler.dart';

class ContactsService {
  /// 주소록 접근 권한 요청
  static Future<bool> requestContactsPermission() async {
    try {
      print('🔍 주소록 권한 요청 시작...');
      
      // 권한 상태를 먼저 확인
      final currentStatus = await Permission.contacts.status;
      print('🔍 현재 권한 상태: $currentStatus');
      
      // 이미 권한이 있으면 true 반환
      if (currentStatus.isGranted) {
        print('✅ 이미 권한이 있습니다.');
        return true;
      }
      
      // 권한이 영구적으로 거부된 경우 설정창으로 이동
      if (currentStatus.isPermanentlyDenied) {
        print('❌ 권한이 영구적으로 거부되었습니다. 설정창으로 이동합니다.');
        final opened = await openAppSettings();
        if (opened) {
          print('✅ 설정창이 열렸습니다.');
        } else {
          print('❌ 설정창을 열 수 없습니다.');
        }
        return false;
      }
      
      // 권한이 거부된 상태면 권한 요청 시도
      if (currentStatus.isDenied) {
        print('🔍 권한 요청 팝업 표시 중...');
        final status = await Permission.contacts.request();
        print('🔍 권한 요청 결과: $status');
        
        return status.isGranted;
      }
      
      return false;
    } catch (e) {
      print('❌ 주소록 권한 요청 실패: $e');
      return false;
    }
  }

  /// 주소록 접근 권한 상태 확인
  static Future<bool> hasContactsPermission() async {
    try {
      final status = await Permission.contacts.status;
      print('🔍 권한 상태 확인: $status');
      return status.isGranted;
    } catch (e) {
      print('❌ 주소록 권한 상태 확인 실패: $e');
      return false;
    }
  }

  /// iOS에서 권한 요청을 강제로 트리거하는 메서드
  static Future<bool> forceRequestContactsPermission() async {
    try {
      print('🔍 강제 권한 요청 시작...');
      
      // 현재 권한 상태 확인
      final currentStatus = await Permission.contacts.status;
      print('🔍 현재 권한 상태: $currentStatus');
      
      // 이미 권한이 있으면 true 반환
      if (currentStatus.isGranted) {
        print('✅ 이미 권한이 있습니다.');
        return true;
      }
      
      // 권한이 영구적으로 거부된 경우 설정창으로 이동
      if (currentStatus.isPermanentlyDenied) {
        print('❌ 권한이 영구적으로 거부되었습니다. 설정창으로 이동합니다.');
        final opened = await openAppSettings();
        if (opened) {
          print('✅ 설정창이 열렸습니다.');
        } else {
          print('❌ 설정창을 열 수 없습니다.');
        }
        return false;
      }
      
      // 권한이 거부된 상태면 권한 요청 시도
      if (currentStatus.isDenied) {
        print('🔍 권한 요청 팝업 표시 중...');
        final status = await Permission.contacts.request();
        print('🔍 권한 요청 결과: $status');
        
        if (status.isGranted) {
          print('✅ 주소록 접근 권한 승인됨');
          return true;
        } else if (status.isPermanentlyDenied) {
          print('❌ 권한이 영구적으로 거부되었습니다. 설정창으로 이동합니다.');
          final opened = await openAppSettings();
          if (opened) {
            print('✅ 설정창이 열렸습니다.');
          } else {
            print('❌ 설정창을 열 수 없습니다.');
          }
          return false;
        } else {
          print('❌ 주소록 접근 권한 거부됨');
          return false;
        }
      }
      
      // 기타 상태 (restricted, limited 등)
      print('⚠️ 권한 상태가 예상과 다릅니다: $currentStatus');
      return false;
      
    } catch (e) {
      print('❌ 권한 요청 실패: $e');
      return false;
    }
  }

  /// 권한 상태를 상세하게 로깅하는 디버그 메서드
  static Future<void> debugPermissionStatus() async {
    try {
      final status = await Permission.contacts.status;
      print('🔍 === 권한 상태 디버그 ===');
      print('🔍 현재 상태: $status');
      print('🔍 상태 설명: ${_getStatusDescription(status)}');
      print('🔍 권한 요청 가능 여부: ${status.isDenied}');
      print('🔍 영구 거부 여부: ${status.isPermanentlyDenied}');
      print('🔍 권한 있음 여부: ${status.isGranted}');
      print('🔍 ========================');
    } catch (e) {
      print('❌ 권한 상태 디버그 실패: $e');
    }
  }

  /// 권한 상태에 대한 설명 반환
  static String _getStatusDescription(PermissionStatus status) {
    switch (status) {
      case PermissionStatus.denied:
        return '거부됨 (첫 번째 요청)';
      case PermissionStatus.granted:
        return '승인됨';
      case PermissionStatus.restricted:
        return '제한됨 (iOS)';
      case PermissionStatus.limited:
        return '제한적 접근 (iOS)';
      case PermissionStatus.permanentlyDenied:
        return '영구적으로 거부됨 (설정창에서만 변경 가능)';
      case PermissionStatus.provisional:
        return '임시 승인 (iOS)';
      default:
        return '알 수 없음';
    }
  }
} 