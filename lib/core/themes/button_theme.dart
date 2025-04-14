import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppButtonTheme {

  static final OutlinedButtonThemeData outlinedButtonTheme = OutlinedButtonThemeData(
    style: ButtonStyle(
      side: MaterialStateProperty.all(
        BorderSide(color: AppColors.black300),
      ),
      foregroundColor: MaterialStateProperty.all(AppColors.black900),
      textStyle: MaterialStateProperty.all(
        const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      shape: MaterialStateProperty.all(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
  );

  static final TextButtonThemeData textButtonTheme = TextButtonThemeData(
    style: ButtonStyle(
      foregroundColor: MaterialStateProperty.all(AppColors.blue500),
      textStyle: MaterialStateProperty.all(
        const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
  );
}