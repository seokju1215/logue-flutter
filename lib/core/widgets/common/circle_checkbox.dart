import 'package:flutter/material.dart';
import 'package:logue/core/themes/app_colors.dart';

class CircleCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;

  const CircleCheckbox({
    super.key,
    required this.value,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged?.call(!value),
      customBorder: const CircleBorder(),
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: value ? AppColors.black900 : AppColors.black300,
            width: 2,
          ),
        ),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: value ? AppColors.black900 : Colors.transparent,
            ),
          ),
        ),
      ),
    );
  }
}