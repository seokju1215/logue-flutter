import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:my_logue/core/themes/app_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserNameEdit extends StatefulWidget {
  final String currentUsername;
  final String originalUsername; // 원래 username (중복 체크에서 제외)

  const UserNameEdit({
    Key? key,
    required this.currentUsername,
    required this.originalUsername,
  }) : super(key: key);

  @override
  State<UserNameEdit> createState() => _UserNameEdit();
}

class _UserNameEdit extends State<UserNameEdit> {
  late TextEditingController _controller;
  bool isValidFormat = true;
  bool isDuplicate = false;
  String? errorText;
  Future<void>? _pendingCheck;
  bool _isChecking = false; // 중복 체크 진행 중 여부

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentUsername);
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<bool> _isUsernameTaken(String username) async {
    // 원래 username과 같으면 중복이 아님
    if (username.toLowerCase() == widget.originalUsername.toLowerCase()) {
      return false;
    }

    final client = Supabase.instance.client;
    final response = await client
        .from('profiles')
        .select('id')
        .eq('username', username.toLowerCase())
        .maybeSingle();

    return response != null;
  }

  void _onChanged() {
    final originalText = _controller.text;
    final text = originalText.trim();

    // 공백 검사 (원본 텍스트로 검사)
    final hasSpace = originalText.contains(' ');
    
    // 3~20자 + 허용문자 + 영어 또는 숫자 하나 이상
    final validFormat = RegExp(r'^(?=[a-zA-Z0-9._]{3,20}$)(?=.*[a-zA-Z0-9]).*$').hasMatch(text);

    setState(() {
      isValidFormat = validFormat && !hasSpace;
      errorText = null;
      isDuplicate = false;
    });

    if (validFormat && !hasSpace) {
      // 이전 검증 요청이 있으면 취소하고 바로 새 검증 실행
          setState(() {
        _isChecking = true;
      });
      _pendingCheck = _checkUsernameAvailability(text);
    } else if (!validFormat || hasSpace) {
      setState(() {
        errorText = '사용자 이름 $text은(는) 사용할 수 없습니다.';
      });
    }
  }

  Future<void> _checkUsernameAvailability(String text) async {
    final taken = await _isUsernameTaken(text);
    if (!mounted) return;
    
    // 현재 입력된 텍스트와 검증한 텍스트가 같은지 확인 (입력 중 변경되었을 수 있음)
    final currentText = _controller.text.trim();
    if (currentText != text) {
      // 입력이 변경되었으면 결과 무시
      setState(() {
        _isChecking = false;
      });
      return;
    }
    
    setState(() {
      _isChecking = false;
      if (taken) {
        isValidFormat = false;
        isDuplicate = true;
        errorText = '사용자 이름 $text은(는) 이미 다른 사람이 사용하고 있어요.';
      }
    });
  }

  Future<void> _onConfirm() async {
    final newUsername = _controller.text.trim().toLowerCase();
    
    // 형식 검증
    final hasSpace = _controller.text.contains(' ');
    final validFormat = RegExp(r'^(?=[a-zA-Z0-9._]{3,20}$)(?=.*[a-zA-Z0-9]).*$').hasMatch(newUsername);
    
    if (!validFormat || hasSpace) {
      setState(() {
        isValidFormat = false;
        errorText = '사용자 이름 $newUsername은(는) 사용할 수 없습니다.';
      });
      return;
    }
    
    // 최종 중복 체크 (확인 버튼을 누를 때 한 번 더 확인)
    setState(() {
      _isChecking = true;
    });
    
    final taken = await _isUsernameTaken(newUsername);
    
    if (!mounted) return;
    
    if (taken) {
      setState(() {
        _isChecking = false;
        isValidFormat = false;
        isDuplicate = true;
        errorText = '사용자 이름 $newUsername은(는) 이미 다른 사람이 사용하고 있어요.';
      });
      return;
    }
    
    // 중복이 아니면 적용
    setState(() {
      _isChecking = false;
    });
    
    Navigator.pop(context, {'username': newUsername});
  }

  @override
  Widget build(BuildContext context) {
    // 중복 체크 중이거나 형식이 유효하지 않으면 확인 버튼 비활성화
    final isConfirmEnabled = isValidFormat && !_isChecking;

    Color borderColor = Colors.grey;
    if (_controller.text.isNotEmpty) {
      if (!isValidFormat) {
        borderColor = AppColors.red500;
      } else {
        borderColor = AppColors.blue500;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '사용자 이름',
          style: TextStyle(color: AppColors.black900, fontSize: 16, fontWeight: FontWeight.w500,),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: SvgPicture.asset('assets/back_arrow.svg'),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: isConfirmEnabled ? _onConfirm : null,
            child: Text(
              '확인',
              style: TextStyle(
                color: isConfirmEnabled
                    ? AppColors.blue500
                    : AppColors.black300,
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              maxLength: 20,
              decoration: InputDecoration(
                contentPadding:
                const EdgeInsets.symmetric(vertical: 9, horizontal: 9),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: borderColor),
                ),
                isDense: true,
                counter: const SizedBox.shrink(),
              ),
              style: const TextStyle(fontSize: 14, color: AppColors.black900),
            ),
            const SizedBox(height: 8),
            if (errorText != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  errorText!,
                  style: const TextStyle(
                    color: AppColors.red500,
                    fontSize: 12,
                  ),
                ),
              ),
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                '사용자 이름은 영어와 숫자, 특수문자(_ .)만 가능해요.\n영어 또는 숫자가 하나 이상 포함되어야 해요.',
                style: TextStyle(color: AppColors.black500, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}