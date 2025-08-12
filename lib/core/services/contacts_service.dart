import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:contacts_service/contacts_service.dart' as contacts;

class ContactsService {

  /// 주소록 접근 권한 요청
  static Future<bool> requestContactsPermission() async {
    try {
      print('🔍 주소록 권한 요청 시작...');
      
      // iOS에서는 네이티브 권한 확인 사용 (연결 문제 해결 전까지는 permission_handler 사용)
      if (Platform.isIOS) {
        return await _requestContactsPermissionIOS();
      }
      
      // Android에서는 permission_handler 사용
      final currentStatus = await Permission.contacts.status;
      print('🔍 현재 권한 상태: $currentStatus');
      
      if (currentStatus.isGranted) {
        print('✅ 이미 권한이 있습니다.');
        return true;
      }
      
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

  /// 주소록 접근 권한 상태 확인 (iOS 네이티브 방식 우선)
  static Future<bool> hasContactsPermission() async {
    try {
      // iOS에서는 네이티브 권한 확인 사용 (연결 문제 해결 전까지는 permission_handler 사용)
      if (Platform.isIOS) {
        return await _checkContactsPermissionIOS();
      }
      
      // Android에서는 permission_handler 사용
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
      
      // iOS에서는 네이티브 권한 확인 사용 (연결 문제 해결 전까지는 permission_handler 사용)
      if (Platform.isIOS) {
        return await _requestContactsPermissionIOS();
      }
      
      // Android에서는 permission_handler 사용
      print('🔍 권한 요청 시도...');
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
      
    } catch (e) {
      print('❌ 권한 요청 실패: $e');
      return false;
    }
  }

  /// 주소록에서 전화번호 목록을 가져옴
  static Future<List<String>> getPhoneNumbers() async {
    try {
      // 권한 확인
      if (!await hasContactsPermission()) {
        print('❌ 주소록 접근 권한이 없습니다.');
        return [];
      }

      // 주소록 가져오기
      final contactsList = await contacts.ContactsService.getContacts();
      final phoneNumbers = <String>[];
      
      for (final contact in contactsList) {
        if (contact.phones != null) {
          for (final phone in contact.phones!) {
            // 전화번호에서 특수문자 제거하고 숫자만 추출
            final cleanNumber = phone.value?.replaceAll(RegExp(r'[^\d]'), '') ?? '';
            if (cleanNumber.isNotEmpty) {
              phoneNumbers.add(cleanNumber);
            }
          }
        }
      }
      
      print('✅ 주소록에서 ${phoneNumbers.length}개의 전화번호를 가져왔습니다.');
      return phoneNumbers;
    } catch (e) {
      print('❌ 주소록에서 전화번호 가져오기 실패: $e');
      return [];
    }
  }

  /// 전화번호를 해시로 변환 (간단한 해시 함수)
  static String hashPhoneNumber(String phoneNumber) {
    // 간단한 해시 함수 (실제로는 더 안전한 해시 사용 권장)
    int hash = 0;
    for (int i = 0; i < phoneNumber.length; i++) {
      hash = ((hash << 5) - hash + phoneNumber.codeUnitAt(i)) & 0xffffffff;
    }
    return hash.toString();
  }

  /// 전화번호 목록을 해시로 변환
  static List<String> hashPhoneNumbers(List<String> phoneNumbers) {
    return phoneNumbers.map((phone) => hashPhoneNumber(phone)).toList();
  }

  /// iOS 네이티브 권한 상태 확인 (임시로 permission_handler 사용)
  static Future<bool> _checkContactsPermissionIOS() async {
    try {
      // iOS 네이티브 코드 연결 문제 해결 전까지는 permission_handler 사용
      print('🔍 iOS에서 permission_handler로 권한 상태 확인...');
      
      final status = await Permission.contacts.status;
      print('🔍 iOS 권한 상태: $status');
      
      if (status.isGranted) {
        print('✅ iOS에서 권한이 허용되어 있습니다.');
        return true;
      } else if (status.isPermanentlyDenied) {
        print('❌ iOS에서 권한이 영구적으로 거부되었습니다.');
        return false;
      } else {
        print('❌ iOS에서 권한이 거부되었습니다.');
        return false;
      }
    } catch (e) {
      print('❌ iOS 권한 확인 실패: $e');
      return false;
    }
  }

  /// iOS 네이티브 권한 요청 (임시로 permission_handler 사용)
  static Future<bool> _requestContactsPermissionIOS() async {
    try {
      // iOS 네이티브 코드 연결 문제 해결 전까지는 permission_handler 사용
      print('🔍 iOS에서 permission_handler로 권한 요청...');
      
      // 먼저 현재 권한 상태 확인
      final currentStatus = await Permission.contacts.status;
      print('🔍 iOS 현재 권한 상태: $currentStatus');
      
      // 이미 권한이 있으면 true 반환
      if (currentStatus.isGranted) {
        print('✅ iOS에서 이미 권한이 있습니다.');
        return true;
      }
      
      // iOS 시뮬레이터에서는 permission_handler가 부정확할 수 있음
      // 실제 권한 요청을 시도해보고 결과를 확인
      print('🔍 iOS에서 권한 요청 시도...');
      final status = await Permission.contacts.request();
      print('🔍 iOS 권한 요청 결과: $status');
      
      if (status.isGranted) {
        print('✅ iOS에서 주소록 접근 권한 승인됨');
        return true;
      } else if (status.isPermanentlyDenied) {
        print('❌ iOS에서 권한이 영구적으로 거부되었습니다.');
        
        // iOS 시뮬레이터에서는 permission_handler가 부정확할 수 있음
        // 설정창으로 이동하기 전에 한 번 더 확인
        print('🔍 iOS 시뮬레이터 권한 상태 재확인...');
        await Future.delayed(const Duration(milliseconds: 500));
        final recheckStatus = await Permission.contacts.status;
        print('🔍 iOS 권한 상태 재확인 결과: $recheckStatus');
        
        if (recheckStatus.isGranted) {
          print('✅ iOS에서 권한이 실제로 허용되어 있습니다.');
          return true;
        }
        
        print('❌ iOS에서 권한이 영구적으로 거부되었습니다. 설정창으로 이동합니다.');
        final opened = await openAppSettings();
        if (opened) {
          print('✅ 설정창이 열렸습니다.');
        } else {
          print('❌ 설정창을 열 수 없습니다.');
        }
        return false;
      } else {
        print('❌ iOS에서 주소록 접근 권한 거부됨');
        return false;
      }
    } catch (e) {
      print('❌ iOS 권한 요청 실패: $e');
      return false;
    }
  }

  /// 권한 상태를 상세하게 로깅하는 디버그 메서드
  static Future<void> debugPermissionStatus() async {
    try {
      if (Platform.isIOS) {
        print('🔍 === iOS 권한 상태 디버그 (permission_handler 사용) ===');
        final status = await Permission.contacts.status;
        print('🔍 iOS 권한 상태: $status');
        print('🔍 상태 설명: ${_getStatusDescription(status)}');
        print('🔍 권한 요청 가능 여부: ${status.isDenied}');
        print('🔍 영구 거부 여부: ${status.isPermanentlyDenied}');
        print('🔍 권한 있음 여부: ${status.isGranted}');
        print('🔍 ================================================');
      } else {
        final status = await Permission.contacts.status;
        print('🔍 === Android 권한 상태 디버그 ===');
        print('🔍 현재 상태: $status');
        print('🔍 상태 설명: ${_getStatusDescription(status)}');
        print('🔍 권한 요청 가능 여부: ${status.isDenied}');
        print('🔍 영구 거부 여부: ${status.isPermanentlyDenied}');
        print('🔍 권한 있음 여부: ${status.isGranted}');
        print('🔍 ================================');
      }
    } catch (e) {
      print('❌ 권한 상태 디버그 실패: $e');
    }
  }

  /// 권한 상태에 대한 설명 반환 (Android용)
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
    }
  }
} 