import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTextTheme {
  static TextTheme get textTheme => TextTheme(
    titleMedium: GoogleFonts.inter(
      fontSize: 18,
      fontWeight: FontWeight.w400,
      color: AppColors.black900,
    ),
    bodyLarge: GoogleFonts.inter(
      fontSize: 20,
      fontWeight: FontWeight.normal,
      color: AppColors.black900,
    ),
    bodyMedium: GoogleFonts.inter(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: AppColors.black900,
    ),
    bodySmall: GoogleFonts.inter(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: AppColors.black500,
    ),
  );
}