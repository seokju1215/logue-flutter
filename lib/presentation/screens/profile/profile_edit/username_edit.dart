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
  bool isAvailable = false;
  bool isLoading = false;
  bool hasChanged = false;

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
      isAvailable = false;
    });

    if (changed && validFormat) {
      _checkAvailability(text);
    }
  }

  Future<void> _checkAvailability(String username) async {
    setState(() => isLoading = true);

    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .select('id')
          .eq('username', username)
          .maybeSingle();

      setState(() {
        isAvailable = response == null; // 중복이 없다면 사용 가능
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      debugPrint('Username check error: $e');
      // 에러 상황에 따라 사용자에게 알림을 줄 수도 있음
    }
  }

  void _onConfirm() {
    // TODO: '사용자 이름 변경 1-4' 화면으로 이동
    Navigator.pop(context, _controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final isConfirmEnabled =
        hasChanged && isValidFormat && isAvailable && !isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('사용자 이름', style: TextStyle(color: AppColors.black900, fontSize: 18),),
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
                color: isConfirmEnabled ? Colors.blue : Colors.blue.withOpacity(0.5),
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
            Padding(
              padding: const EdgeInsets.only(left: 9), // 위쪽 마진만 16
              child: Text(
                '사용자 이름',
                style: TextStyle(color: AppColors.black500, fontSize: 12),
              ),
            ),
            const SizedBox(height: 8),
            Stack(
              alignment: Alignment.centerRight,
              children: [
                TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(vertical: 9, horizontal: 9),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 14, color : AppColors.black900),
                ),
                if (isLoading)
                  const Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
              ],
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(left: 9), // 위쪽 마진만 16
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