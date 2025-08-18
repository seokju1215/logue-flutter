
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/themes/app_colors.dart';
import 'find_friends_screen.dart';

class InputPhoneNumberScreen extends StatefulWidget {
  final String? initialPhoneNumber;
  final List<String>? contactPhoneNumbers; // 연락처 전화번호 목록 추가
  
  const InputPhoneNumberScreen({
    Key? key,
    this.initialPhoneNumber,
    this.contactPhoneNumbers,
  }) : super(key: key);

  @override
  State<InputPhoneNumberScreen> createState() => _InputPhoneNumberScreenState();
}

class _InputPhoneNumberScreenState extends State<InputPhoneNumberScreen> {
  late TextEditingController _searchController;
  bool hasSearchText = false;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchController.addListener(_onSearchChanged);
    if (widget.initialPhoneNumber != null) {
      _searchController.text = widget.initialPhoneNumber!;
      _onSearchChanged(); // Update hasSearchText based on initial value
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      final text = _searchController.text.trim();
      // 8글자 또는 11글자일 때만 활성화
      hasSearchText = text.length == 11;
    });
  }

  Future<void> _savePhoneNumber() async {
    if (!hasSearchText) return;

    setState(() {
      isLoading = true;
    });

    try {
      final supabase = Supabase.instance.client;
      final phoneNumber = _searchController.text.trim();
      
      // profiles 테이블의 contact_number 컬럼에 직접 전화번호 저장
      await supabase
          .from('profiles')
          .update({'contact_number': phoneNumber})
          .eq('id', supabase.auth.currentUser!.id);

                // 성공 시 find_friends_screen으로 이동하면서 전화번호와 연락처 목록 전달
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => FindFriendsScreen(
                  contactNumber: phoneNumber,
                  contactPhoneNumbers: widget.contactPhoneNumbers,
                ),
              ),
            );
          }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('전화번호 저장에 실패했습니다: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        title: Text("본인의 전화번호를 입력해주세요", style: TextStyle(fontSize: 16, color: AppColors.black900, fontWeight: FontWeight.w500,)),
        leading: IconButton(
          icon: SvgPicture.asset('assets/back_arrow.svg'),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: hasSearchText && !isLoading ? _savePhoneNumber : null,
            child: isLoading
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.blue500),
                    ),
                  )
                : Text(
                    '확인',
                    style: TextStyle(
                      color: hasSearchText ? AppColors.blue500 : AppColors.black300,
                    ),
                  ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _searchController,
              maxLength: 11,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(vertical: 9, horizontal: 9),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.black500),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.black500),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.black500),
                ),
                isDense: true,
                hintText: '전화번호를 입력해주세요!',
                hintStyle: TextStyle(color: AppColors.black500, fontSize: 14, height: 1.21),
                counterText: '', // 글자 수 카운터 숨기기
              ),
              style: const TextStyle(fontSize: 14, color: AppColors.black900),
              keyboardType: TextInputType.number, // 🔢 숫자 키보드
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly, // ✅ 숫자만 허용
              ],
            ),
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                '전화번호는 01012345678 형식으로\n숫자 11글자만 정확하게 입력해주세요.',
                style: TextStyle(color: AppColors.black500, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
