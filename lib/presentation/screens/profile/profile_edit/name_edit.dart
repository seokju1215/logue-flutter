import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:my_logue/core/themes/app_colors.dart';

class NameEdit extends StatefulWidget {
  final String currentName;

  const NameEdit({super.key, required this.currentName});

  @override
  State<NameEdit> createState() => _NameEdit();
}

class _NameEdit extends State<NameEdit> {
  late TextEditingController _controller;
  bool isValid = true;
  bool hasChanged = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentName);
    _controller.addListener(_onChanged);
  }

  void _onChanged() {
    final text = _controller.text;
    final changed = text != widget.currentName;

    // 초성 단독을 허용하기 위해 유효한 정규식 체크를 느슨하게 수정
    final valid = text.isNotEmpty && text.length <= 10 &&
        RegExp(r'^[a-zA-Z가-힣]+$').hasMatch(text);

    setState(() {
      hasChanged = changed;
      isValid = valid;
    });
  }

  void _onConfirm() {
    final newName = _controller.text.trim();

    if (!isValid || !hasChanged) return;

    try {
      Navigator.pop(context, {'name': newName});
    } catch (e) {
      debugPrint('❌ NameEdit 네비게이션 오류: $e');
      // 에러 발생 시에도 안전하게 돌아가기
      Navigator.of(context).pop({'name': newName});
    }
  }

  @override
  Widget build(BuildContext context) {
    final isConfirmEnabled = hasChanged && isValid;

    Color borderColor = AppColors.black500;
    if (_controller.text.isNotEmpty) {
      if (!isValid) {
        borderColor = AppColors.red500;
      } else if (hasChanged) {
        borderColor = AppColors.blue500;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('이름', style: TextStyle(color: AppColors.black900, fontSize: 16)),
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
                color: isConfirmEnabled ? AppColors.blue500 : AppColors.black300,
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
              maxLength: 10,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(vertical: 9, horizontal: 9),
                border: OutlineInputBorder(borderSide: BorderSide(color: borderColor)),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: borderColor)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: borderColor)),
                isDense: true,
                counter: const SizedBox.shrink(),
              ),
              style: const TextStyle(fontSize: 14, color: AppColors.black900),
            ),
            const SizedBox(height: 6),
            const Text(
                '이름, 별명 또는 비즈니스 이름 등 회원님의 알려진 이름을 사용하여\n사람들이 해당 계정을 찾을 수 있도록 해주세요.\n\n이름은 한글과 영어만 가능해요.',
                style: TextStyle(fontSize: 12, color: AppColors.black500),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}