import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../data/models/inquiry_models.dart';
import '../../../../data/repositories/inquiry_repository.dart';
import '../../../../data/datasources/inquiry_api.dart';

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
    _subjectController.text = '비비디 바 블라';
    _contentController.text = '비비디 바 블라';
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

      final inquiryData = {
        'user_id': currentUser.id,
        'username': currentUser.userMetadata?['username'] ?? '사용자',
        'title': _subjectController.text.trim(),
        'content': _contentController.text.trim(),
        'inquiry_type': _selectedInquiryType,
        'email': _emailReply ? _emailController.text.trim() : null,
        'is_completed': false,
        'created_at': DateTime.now().toIso8601String(),
      };

      await client.from('inquiries').insert(inquiryData);

      _showSnackBar('문의가 성공적으로 접수되었습니다.');
      Navigator.pop(context);
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
            // 이메일 답변 받기 섹션
            Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: Checkbox(
                    value: _emailReply,
                    onChanged: (value) {
                      setState(() {
                        _emailReply = value ?? false;
                      });
                    },
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
                ),
                SizedBox(width: 7,),
                const Text(
                  '이메일로 문의 답변 받기 (선택)',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.23,
                    color: AppColors.black900,
                  ),
                ),
              ],
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
            const SizedBox(height: 38),
            
            // 문의사항 섹션
            const Text(
              '문의사항을 알려주세요!',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: AppColors.black900,
              ),
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
            const SizedBox(height: 26),
            
            // 문의 제목
            Padding(
              padding: const EdgeInsets.only(left: 9),
              child: const Text(
                '문의 제목',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.25,
                  fontWeight: FontWeight.w400,
                  color: AppColors.black500,
                ),
              ),
            ),
            const SizedBox(height: 3),
            TextField(
              controller: _subjectController,
              maxLength: 50,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(5),
                  borderSide: const BorderSide(color: Color(0xFFD9D9D9)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(5),
                  borderSide: const BorderSide(color: Color(0xFFD9D9D9)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(5),
                  borderSide: const BorderSide(color: AppColors.black300),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 6,
                ),
                counterText: '${_subjectController.text.length}/50',
                counterStyle: const TextStyle(
                  fontSize: 13,
                  color: AppColors.black500,
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // 문의 내용
            const Text(
              '문의 내용',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.black900,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _contentController,
              maxLength: 500,
              maxLines: 6,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFD9D9D9)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFD9D9D9)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.black900),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                counterText: '${_contentController.text.length}/500',
                counterStyle: const TextStyle(
                  fontSize: 12,
                  color: AppColors.black500,
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _submitInquiry,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.black900,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    '문의 접수',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
} 