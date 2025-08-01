import 'package:flutter/material.dart';
import 'package:my_logue/core/themes/app_colors.dart';

class CommonOutlinedButton extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;

  const CommonOutlinedButton({
    super.key,
    required this.text,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.black900,
        backgroundColor: Colors.white,
        side: const BorderSide(color: AppColors.black500, width: 1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(5),
        ),
        padding: const EdgeInsets.symmetric(vertical: 9),
        minimumSize: const Size.fromHeight(34),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          height: 1.25,
          color: AppColors.black900,
          fontWeight: FontWeight.w400,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
