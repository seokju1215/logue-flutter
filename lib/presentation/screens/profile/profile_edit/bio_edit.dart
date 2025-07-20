import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:my_logue/core/themes/app_colors.dart';

class BioEdit extends StatefulWidget {
  final String currentBio;

  const BioEdit({super.key, required this.currentBio});

  @override
  State<BioEdit> createState() => _BioEdit();
}

class _BioEdit extends State<BioEdit> {
  late TextEditingController _controller;
  bool hasChanged = false;
  bool isValid = true;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentBio);
    _controller.addListener(_onChanged);
  }

  void _onChanged() {
    final text = _controller.text;
    final changed = text != widget.currentBio;
    final valid = text.length <= 150;

    setState(() {
      hasChanged = changed;
      isValid = valid;
    });
  }

  void _onConfirm() {
    final newBio = _controller.text.trim();

    if (!hasChanged || !isValid) return;

    try {
      Navigator.pop(context, {'bio': newBio});
    } catch (e) {
      debugPrint('❌ BioEdit 네비게이션 오류: $e');
      // 에러 발생 시에도 안전하게 돌아가기
      Navigator.of(context).pop({'bio': newBio});
    }
  }

  @override
  Widget build(BuildContext context) {
    final isConfirmEnabled = hasChanged && isValid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('소개', style: TextStyle(color: AppColors.black900, fontSize: 16, fontWeight: FontWeight.w500,)),
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
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              maxLength: 150,
              maxLines: 9,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(vertical: 9, horizontal: 9),
                border: OutlineInputBorder(borderSide: BorderSide(color: AppColors.black500)),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.black500)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.black500)),
                isDense: true,
                counterText: '${_controller.text.length}/150',
              ),
              style: const TextStyle(fontSize: 14, color: AppColors.black900),
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