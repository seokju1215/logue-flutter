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
  String? errorText;

  final client = Supabase.instance.client;

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
      errorText = null;
    });

    if (changed && validFormat) {
      _checkAvailability(text);
    } else if (changed && !validFormat) {
      setState(() {
        errorText = '사용자 이름 $text은(는) 사용할 수 없습니다.';
      });
    }
  }

  Future<void> _checkAvailability(String username) async {
    setState(() => isLoading = true);

    try {
      final userId = client.auth.currentUser?.id;
      final response = await client
          .from('profiles')
          .select('id')
          .eq('username', username)
          .maybeSingle();

      setState(() {
        if (response == null || response['id'] == userId) {
          // 사용 가능하거나 현재 사용자 본인의 이름이면 허용
          isAvailable = true;
          errorText = null;
        } else {
          isAvailable = false;
          errorText = '이 사용자 이름은 이미 다른 사람이 사용하고 있습니다.';
        }
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      debugPrint('Username check error: $e');
    }
  }

  void _onConfirm() async {
    final userId = client.auth.currentUser?.id;
    final newUsername = _controller.text;

    if (userId == null) return;

    try {
      await client
          .from('profiles')
          .update({'username': newUsername})
          .eq('id', userId);

      if (mounted) {
        Navigator.pop(context, {'username': newUsername});
      }
    } catch (e) {
      debugPrint('Username update error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('사용자 이름 변경에 실패했어요. 다시 시도해주세요.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isConfirmEnabled =
        hasChanged && isValidFormat && isAvailable && !isLoading;

    // 테두리 색 결정
    Color borderColor = Colors.grey;
    if (_controller.text.isNotEmpty && !isLoading) {
      if (!isValidFormat || (hasChanged && !isAvailable)) {
        borderColor = Colors.red;
      } else if (isAvailable) {
        borderColor = Colors.blue;
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
            const Padding(
              padding: EdgeInsets.only(left: 9),
              child: Text('사용자 이름', style: TextStyle(color: AppColors.black500, fontSize: 12)),
            ),
            const SizedBox(height: 8),
            Stack(
              alignment: Alignment.centerRight,
              children: [
                TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(vertical: 9, horizontal: 9),
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
                  ),
                  style: const TextStyle(fontSize: 14, color: AppColors.black900),
                ),
                if (isLoading)
                  const Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (errorText != null)
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 9),
                  child: Text(
                    errorText!,
                    style: const TextStyle(color: Colors.red, fontSize: 10),
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