import 'package:flutter/material.dart';
import 'package:logue/core/themes/app_colors.dart';

class UserNameEdit extends StatefulWidget {
  final String currentUsername;

  const UserNameEdit({
    Key? key,
    required this.currentUsername,
  }) : super(key: key);

  @override
  State<UserNameEdit> createState() => _UserNameEdit();
}

class _UserNameEdit extends State<UserNameEdit> {
  late TextEditingController _controller;
  bool isValidFormat = true;
  bool hasChanged = false;
  String? errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentUsername);
    _controller.addListener(_onChanged);
  }

  void _onChanged() {
    final text = _controller.text;
    final changed = text != widget.currentUsername;
    final validFormat = RegExp(r'^[a-zA-Z0-9._]{1,20}$').hasMatch(text);

    setState(() {
      hasChanged = changed;
      isValidFormat = validFormat;
      errorText = null;
    });

    if (changed && !validFormat) {
      errorText = '사용자 이름 $text은(는) 사용할 수 없습니다.';
    }
  }

  void _onConfirm() {
    final newUsername = _controller.text;
    if (!isValidFormat || !hasChanged) return;
    Navigator.pop(context, {'username': newUsername});
  }

  @override
  Widget build(BuildContext context) {
    final isConfirmEnabled = hasChanged && isValidFormat;

    Color borderColor = Colors.grey;
    if (_controller.text.isNotEmpty) {
      if (!isValidFormat) {
        borderColor = AppColors.red500;
      } else if (hasChanged) {
        borderColor = AppColors.blue500;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('사용자 이름', style: TextStyle(color: AppColors.black900, fontSize: 18)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
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
                    : AppColors.blue500.withOpacity(0.5),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 9),
              child: Text('사용자 이름', style: TextStyle(color: AppColors.black500, fontSize: 12)),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(vertical: 9, horizontal: 9),
                border: OutlineInputBorder(borderSide: BorderSide(color: borderColor)),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: borderColor)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: borderColor)),
                isDense: true,
              ),
              style: const TextStyle(fontSize: 14, color: AppColors.black900),
            ),
            const SizedBox(height: 8),
            if (errorText != null)
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 9),
                  child: Text(
                    errorText!,
                    style: const TextStyle(color: AppColors.red500, fontSize: 10),
                    textAlign: TextAlign.right,
                  ),
                ),
              ),
            const Padding(
              padding: EdgeInsets.only(left: 9, top: 4),
              child: Text(
                '사용자 이름은 영어와 특수문자(_ .)만 가능해요.',
                style: TextStyle(color: AppColors.black500, fontSize: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }
}