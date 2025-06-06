import 'package:flutter/material.dart';
import 'package:logue/core/themes/app_colors.dart';

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
    final valid = text.length <= 30;

    setState(() {
      hasChanged = changed;
      isValid = valid;
    });
  }

  void _onConfirm() {
    final newBio = _controller.text.trim();

    if (!hasChanged || !isValid) return;

    Navigator.pop(context, {'bio': newBio});
  }

  @override
  Widget build(BuildContext context) {
    final isConfirmEnabled = hasChanged && isValid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('소개', style: TextStyle(color: AppColors.black900, fontSize: 18)),
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
                color: isConfirmEnabled ? AppColors.blue500 : AppColors.blue500.withOpacity(0.5),
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
              child: Text('소개', style: TextStyle(color: AppColors.black500, fontSize: 12)),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              maxLength: 30,
              maxLines: null,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(vertical: 9, horizontal: 9),
                border: OutlineInputBorder(borderSide: BorderSide(color: AppColors.black500)),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.black500)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.black500)),
                isDense: true,
                counterText: '${_controller.text.length}/30',
              ),
              style: const TextStyle(fontSize: 14, color: AppColors.black900),
            ),
          ],
        ),
      ),
    );
  }
}