import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/stroke_text_style.dart';
import '../../../../core/services/contacts_service.dart';
import 'input_phone_number_screen.dart';

class FindFriendsScreen extends StatefulWidget {
  final String? contactNumber;
  const FindFriendsScreen({super.key, this.contactNumber});

  @override
  State<FindFriendsScreen> createState() => _FindFriendsScreenState();
}

class _FindFriendsScreenState extends State<FindFriendsScreen> {
  String? contactNumber;
  bool isLoading = false;
  List<Map<String, dynamic>> foundFriends = [];
  bool isSearchingFriends = false;

  @override
  void initState() {
    super.initState();
    // widget.contactNumber가 있으면 사용, 없으면 null
    contactNumber = widget.contactNumber;
    _searchFriendsFromContacts();
  }

  Future<void> _loadContactNumber() async {
    // profiles 테이블에서 가져오지 않고, 편집 화면에서 돌아온 결과를 사용
    // 이 메서드는 더 이상 사용하지 않음
  }

  Future<void> _searchFriendsFromContacts() async {
    try {
      setState(() {
        isSearchingFriends = true;
      });

      // 주소록에서 전화번호 가져오기
      final phoneNumbers = await ContactsService.getPhoneNumbers();
      if (phoneNumbers.isEmpty) {
        print('❌ 주소록에서 전화번호를 가져올 수 없습니다.');
        return;
      }

      // 전화번호를 해시로 변환
      final hashesFull = ContactsService.hashPhoneNumbers(phoneNumbers);
      final hashesLast8 = phoneNumbers
          .where((phone) => phone.length >= 8)
          .map((phone) => ContactsService.hashPhoneNumber(phone.substring(phone.length - 8)))
          .toList();

      print('✅ 전화번호 해시 생성 완료: 전체 ${hashesFull.length}개, 마지막8자리 ${hashesLast8.length}개');

      // find-friends-kr Edge Function 호출
      final supabase = Supabase.instance.client;
      final response = await supabase.functions.invoke(
        'find-friends-kr',
        body: {
          'hashes_full': hashesFull,
          'hashes_last8': hashesLast8,
          'limit': 100,
        },
      );

      if (response.status == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final users = data['users'] as List<dynamic>? ?? [];
        
        if (mounted) {
          setState(() {
            foundFriends = users.cast<Map<String, dynamic>>();
            isSearchingFriends = false;
          });
        }
        
        print('✅ 친구 검색 완료: ${foundFriends.length}명의 친구를 찾았습니다.');
      } else {
        final errorMessage = 'HTTP ${response.status} 오류';
        print('❌ 친구 검색 실패: $errorMessage');
        if (mounted) {
          setState(() {
            isSearchingFriends = false;
          });
        }
      }
    } catch (e) {
      print('❌ 친구 검색 중 오류 발생: $e');
      if (mounted) {
        setState(() {
          isSearchingFriends = false;
        });
      }
    }
  }

  Future<void> _editPhoneNumber() async {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => InputPhoneNumberScreen(),
      ),
    );
  }
  ButtonStyle _outlinedStyle(BuildContext context) {
    return ButtonStyle(
      foregroundColor: MaterialStateProperty.all(AppColors.black900),
      backgroundColor: MaterialStateProperty.all(Colors.white),
      overlayColor: MaterialStateProperty.resolveWith<Color?>(
            (states) {
          if (states.contains(MaterialState.pressed)) {
            return AppColors.black100;
          }
          return null;
        },
      ),
      side: MaterialStateProperty.all(
        const BorderSide(color: AppColors.black500, width: 1),
      ),
      shape: MaterialStateProperty.all(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      padding: MaterialStateProperty.all(
        const EdgeInsets.symmetric(horizontal: 9),
      ),
      minimumSize: MaterialStateProperty.all(
        const Size(0, 34),
      ),
      textStyle: MaterialStateProperty.all(
        const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          height: 1.0,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        title: Text("친구 찾기", style: TextStyle(fontSize: 16, color: AppColors.black900, fontWeight: FontWeight.w500,)),
        leading: IconButton(
          icon: SvgPicture.asset('assets/back_arrow.svg'),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: double.infinity, // Row가 가로 전체 쓰도록 보장
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.only(right: 19), // 버튼과 19px 간격
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      decoration: BoxDecoration(
                        color: AppColors.black200,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        isLoading
                            ? '로딩 중...'
                            : (contactNumber ?? '전화번호를 입력해주세요'),
                        style: TextStyle(
                          fontSize: 14,
                          color: contactNumber != null ? AppColors.black500 : AppColors.black300,
                          height: 1.21,
                        ),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _editPhoneNumber,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero, // 시각적으로 더 오른쪽에 '착' 붙게
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      '편집',
                      style: TextStyle(
                        color: AppColors.blue500,
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 19),
            StrokeTextStyle.createStrokeText(text: '친구를 초대해 인생 책을 공유해보세요!', fontSize: 16 , color: AppColors.black900, fontWeight: FontWeight.w400, height: 1.187),
            SizedBox(height: 13),
            Row(
                children: [
                  const Expanded(child: SizedBox()),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                      },
                      style: _outlinedStyle(context),
                      child: const Text(
                        '친구 찾기',
                        style: TextStyle(fontSize: 13, color: AppColors.black900, height: 1.25),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
} 