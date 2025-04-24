import 'package:flutter/material.dart';

class SaveButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onPressed;

  const SaveButton({
    super.key,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: enabled ? onPressed : null,
      style: TextButton.styleFrom(
        foregroundColor: enabled ? Colors.blue : Colors.grey.withOpacity(0.5),
      ),
      child: const Text('저장'),
    );
  }
}