import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../data/models/inquiry_models.dart';
import '../../../../data/repositories/inquiry_repository.dart';
import '../../../../data/datasources/inquiry_api.dart';
import '../../../../data/utils/fetch_profile.dart';

class CreateInquiryScreen extends StatefulWidget {
  const CreateInquiryScreen({Key? key}) : super(key: key);

  @override
  State<CreateInquiryScreen> createState() => _CreateInquiryScreenState();
}

class _CreateInquiryScreenState extends State<CreateInquiryScreen> {
  bool _emailReply = false;
  String _selectedInquiryType = '';
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  bool _isSubmitting = false;
  bool _isDropdownOpen = false;

  final List<String> _inquiryTypes = [
    '없는 책 추가 요청',
    '책 표지 이미지 수정 요청',
    '신규 기능 또는 신규 콘텐츠 추천',
    '버그 신고',
    '악성 유저 신고',
    '1대1 문의 (광고, 제휴 등 기타 문의사항)',
  ];

  @override
  void initState() {
    super.initState();
    _subjectController.text = '';
    _contentController.text = '';
    
    // 텍스트 변경 리스너 추가
    _subjectController.addListener(() => setState(() {}));
    _contentController.addListener(() => setState(() {}));
    _emailController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _contentController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submitInquiry() async {
    if (_selectedInquiryType.isEmpty) {
      _showSnackBar('문의 유형을 선택해주세요.');
      return;
    }

    if (_subjectController.text.trim().isEmpty) {
      _showSnackBar('문의 제목을 입력해주세요.');
      return;
    }

    if (_contentController.text.trim().isEmpty) {
      _showSnackBar('문의 내용을 입력해주세요.');
      return;
    }

    // 이메일 필수 여부 확인
    final bool isEmailRequired = _selectedInquiryType != '없는 책 추가 요청';
    if (isEmailRequired && (!_emailReply || _emailController.text.trim().isEmpty)) {
      _showSnackBar('이메일을 입력해주세요.');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final client = Supabase.instance.client;
      final currentUser = client.auth.currentUser;
      
      if (currentUser == null) {
        _showSnackBar('로그인이 필요합니다.');
        return;
      }

      // 프로필에서 username 가져오기
      final profile = await fetchCurrentUserProfile();
      final username = profile?['username'] ?? '사용자';

      final inquiryData = {
        'user_id': currentUser.id,
        'username': username,
        'title': _subjectController.text.trim(),
        'content': _contentController.text.trim(),
        'inquiry_type': _selectedInquiryType,
        'email': _emailReply ? _emailController.text.trim() : null,
        'is_completed': false,
        'created_at': DateTime.now().toIso8601String(),
      };

      await client.from('inquiries').insert(inquiryData);

      
      // inquiry_screen으로 돌아가면서 새로고침을 위한 result 전달
      Navigator.pop(context, true);
    } catch (e) {
      print('Error submitting inquiry: $e');
      _showSnackBar('문의 접수 중 오류가 발생했습니다.');
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 이메일 필수 여부 확인
    final bool isEmailRequired = _selectedInquiryType.isNotEmpty && 
                                 _selectedInquiryType != '없는 책 추가 요청';
    
    // 이메일 유효성 검사
    final bool isEmailValid = !isEmailRequired || 
                             (_emailReply && _emailController.text.trim().isNotEmpty);
    
    // 버튼 활성화 조건
    final bool isFormValid = _selectedInquiryType.isNotEmpty && 
                             _subjectController.text.trim().isNotEmpty && 
                             _contentController.text.trim().isNotEmpty &&
                             isEmailValid;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          '고객센터',
          style: TextStyle(
            fontSize: 16,
            color: AppColors.black900,
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: SvgPicture.asset('assets/back_arrow.svg'),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 문의사항 섹션
            Stack(
              children: [
                Text( // 테두리용
                  '문의사항을 알려주세요!',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    foreground: Paint()
                      ..style = PaintingStyle.stroke
                      ..strokeWidth = 0.2
                      ..color = Colors.black,
                  ),
                ),
                Text( // 내부 채우기용
                  '문의사항을 알려주세요!',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: AppColors.black900, // 내부 텍스트 색상
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            
            // 문의 유형 선택
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.black300),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isDropdownOpen = !_isDropdownOpen;
                      });
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _selectedInquiryType.isEmpty
                                  ? '문의사항을 선택해주세요.'
                                  : _selectedInquiryType,
                              style: TextStyle(
                                fontSize: 14,
                                color: _selectedInquiryType.isEmpty
                                    ? AppColors.black500
                                    : AppColors.black900,
                              ),
                            ),
                          ),
                          AnimatedRotation(
                            turns: _isDropdownOpen ? 0.5 : 0,
                            duration: const Duration(milliseconds: 200),
                            child: SvgPicture.asset(
                              'assets/dropdown_arrow.svg',
                              width: 18,
                              height: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_isDropdownOpen) ...[
                    Container(
                      width: double.infinity,
                      child: Column(
                        children: _inquiryTypes.map((type) {
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedInquiryType = type;
                                _isDropdownOpen = false;
                                // "없는 책 추가 요청"이 아니면 이메일 답변 받기를 자동으로 체크
                                if (type != '없는 책 추가 요청') {
                                  _emailReply = true;
                                } else {
                                  _emailReply = false;
                                }
                              });
                            },
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                              decoration: BoxDecoration(
                                color: AppColors.white500,
                              ),
                              child: Text(
                                type,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: _selectedInquiryType == type
                                      ? AppColors.black900
                                      : AppColors.black900,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 21),
            // 이메일 답변 받기 섹션
            GestureDetector(
              onTap: () {
                // "없는 책 추가 요청"일 때만 체크박스 토글 가능
                if (_selectedInquiryType == '없는 책 추가 요청') {
                setState(() {
                  _emailReply = !_emailReply;
                });
                }
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    SizedBox(
                        width: 24,
                        height: 24,
                        child: Transform.scale(
                          scale: 1.2, // 1.0이 기본, 이 값을 키우면 전체 크기 증가
                          child: Checkbox(
                            value: _emailReply,
                            onChanged: _selectedInquiryType == '없는 책 추가 요청' 
                                ? (value) {
                              setState(() {
                                _emailReply = value ?? false;
                              });
                                  }
                                : null, // 다른 문의 유형일 때는 비활성화
                            activeColor: AppColors.black900,
                            fillColor: MaterialStateProperty.resolveWith((states) {
                              if (states.contains(MaterialState.selected)) {
                                return AppColors.black900;
                              }
                              return AppColors.black300;
                            }),
                            checkColor: Colors.white,
                            side: const BorderSide(
                              color: AppColors.black300,
                              width: 1,
                            ),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ),
                        )
                    ),
                    SizedBox(width: 9,),
                    const Text(
                      '이메일로 문의 답변 받기',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.21,
                        color: AppColors.black900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_emailReply) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 36,
                child: TextField(
                  controller: _emailController,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.23,
                    color: AppColors.black900,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: '문의에 대해 답변 받으실 이메일을 입력해주세요.',
                    hintStyle: const TextStyle(
                      fontSize: 13,
                      height: 1.23,
                      color: AppColors.black500,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(5),
                      borderSide: const BorderSide(color: AppColors.black300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(5),
                      borderSide: const BorderSide(color: AppColors.black300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(5),
                      borderSide: const BorderSide(color: AppColors.black300),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            
            // 문의 제목
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 9),
                  child: Text(
                    '문의 제목',
                    style: TextStyle(fontSize: 12, color: AppColors.black500),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 9),
                  child: Text(
                    '${_subjectController.text.length}/50',
                    style: const TextStyle(fontSize: 12, color: AppColors.black500),
                  ),
                ),
              ],
            ),
            TextField(
              controller: _subjectController,
              maxLength: 50,
              minLines: 3,
              maxLines: null,
              style: const TextStyle(fontSize: 13, color: AppColors.black900, height: 1.23),
              decoration: InputDecoration(
                counterText: '', // 기본 글자 수 숨김
                contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 13),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(5),
                  borderSide: const BorderSide(color: AppColors.black300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(5),
                  borderSide: const BorderSide(color: AppColors.black300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(5),
                  borderSide: const BorderSide(color: AppColors.black300),
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // 문의 내용
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 9),
                  child: Text(
                    '문의 내용',
                    style: TextStyle(fontSize: 12, color: AppColors.black500),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 9),
                  child: Text(
                    '${_contentController.text.length}/500',
                    style: const TextStyle(fontSize: 12, color: AppColors.black500),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            TextField(
              controller: _contentController,
              maxLength: 500,
              minLines: 13,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              style: const TextStyle(fontSize: 13, color: AppColors.black900, height : 1.23),
              decoration: InputDecoration(
                counterText: '', // 기본 카운터 제거
                contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 13),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(5),
                  borderSide: const BorderSide(color: AppColors.black300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(5),
                  borderSide: const BorderSide(color: AppColors.black300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(5),
                  borderSide: const BorderSide(color: AppColors.black300),
                ),
              ),
            ),
            SizedBox(height: 50,),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                SizedBox(
                  width: 200,
                  height: 36,
                  child: ElevatedButton(
                    onPressed: (isFormValid && !_isSubmitting) ? _submitInquiry : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isFormValid ? AppColors.black900 : AppColors.black300,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.black900),
                      ),
                    )
                        : isFormValid
                        ? Stack(
                      children: [
                        // 테두리용 텍스트
                        Text(
                          '문의 접수',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            foreground: Paint()
                              ..style = PaintingStyle.stroke
                              ..strokeWidth = 0.2 // 테두리 두께
                              ..color = AppColors.white500, // 테두리 색상
                          ),
                        ),
                        // 내부 텍스트 (원래 스타일)
                        const Text(
                          '문의 접수',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.white500, // 내부 텍스트 색상
                          ),
                        ),
                      ],
                    )
                        :
                    // 내부 텍스트 (원래 스타일)
                    const Text(
                      '문의 접수',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.black500, // 내부 텍스트 색상
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 60,)
          ],
        ),
      ),
    );
  }
} 