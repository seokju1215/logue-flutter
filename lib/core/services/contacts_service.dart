import 'package:flutter_contacts/flutter_contacts.dart';

class ContactsService {

  /// 주소록에서 전화번호 목록을 가져옴
  static Future<List<String>> getPhoneNumbers() async {
    try {
      // 주소록 권한 요청 및 확인
      if (!await FlutterContacts.requestPermission(readonly: true)) {
        print('❌ 주소록 접근 권한이 거부되었습니다.');
        return [];
      }

      // 주소록 가져오기
      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: false,
      );
      
      final phoneNumbers = <String>[];
      
      for (final contact in contacts) {
        final phones = contact.phones;
        if (phones.isNotEmpty) {
          for (final phone in phones) {
            // 전화번호에서 특수문자 제거하고 숫자만 추출
            final cleanNumber = phone.number.replaceAll(RegExp(r'[^\d]'), '');
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
} 