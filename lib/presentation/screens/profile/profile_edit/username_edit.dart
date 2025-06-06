import 'dart:async';
import 'package:flutter/material.dart';
import 'package:logue/core/themes/app_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  bool isDuplicate = false;
  String? errorText;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentUsername);
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<bool> _isUsernameTaken(String username) async {
    final client = Supabase.instance.client;
    final response = await client
        .from('profiles')
        .select('id')
        .eq('username', username)
        .maybeSingle();

    return response != null;
  }

  void _onChanged() {
    final text = _controller.text;
    final changed = text != widget.currentUsername;
    final validFormat = RegExp(r'^[a-zA-Z0-9._]{1,20}$').hasMatch(text);

    setState(() {
      hasChanged = changed;
      isValidFormat = validFormat;
      errorText = null;
      isDuplicate = false;
    });

    _debounce?.cancel();

    if (changed && validFormat) {
      _debounce = Timer(const Duration(milliseconds: 500), () async {
        final taken = await _isUsernameTaken(text);
        if (!mounted) return;
        if (taken) {
          setState(() {
            isValidFormat = false;
            isDuplicate = true;
            errorText = '사용자 이름 $text은(는) 이미 다른 사람이 사용하고 있어요.';
          });
        }
      });
    } else if (changed && !validFormat) {
      setState(() {
        errorText = '사용자 이름 $text은(는) 사용할 수 없습니다.';
      });
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
        title: const Text('사용자 이름',
            style: TextStyle(color: AppColors.black900, fontSize: 16)),
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
                color:
                isConfirmEnabled ? AppColors.blue500 : AppColors.black300,
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
                    borderSide: BorderSide(color: borderColor)),
                enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: borderColor)),
                focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: borderColor)),
                isDense: true,
              ),
              style: const TextStyle(fontSize: 14, color: AppColors.black900),
            ),
            const SizedBox(height: 8),
            if (errorText != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  errorText!,
                  style: const TextStyle(color: AppColors.red500, fontSize: 12),
                  textAlign: TextAlign.right,
                ),
              ),
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                '사용자 이름은 영어와 특수문자(_ .)만 가능해요.',
                style: TextStyle(color: AppColors.black500, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}