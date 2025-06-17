import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../themes/app_colors.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String leadingIconPath;
  final VoidCallback onLeadingTap;
  final String trailingIconPath;
  final VoidCallback onTrailingTap;

  const CustomAppBar({
    super.key,
    required this.title,
    required this.leadingIconPath,
    required this.onLeadingTap,
    required this.trailingIconPath,
    required this.onTrailingTap,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: preferredSize.height,
        child: Padding(
          padding: const EdgeInsets.only(top: 15),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: onLeadingTap,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22.73),
                  child: SvgPicture.asset(
                    leadingIconPath,
                    width: 24,
                    height: 24,
                  ),
                ),
              ),
              Text(
                title,
                style: TextStyle(fontSize: 16, color: AppColors.black900),
              ),
              GestureDetector(
                onTap: onTrailingTap,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22.73),
                  child: SvgPicture.asset(
                    trailingIconPath,
                    width: 24,
                    height: 24,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(56);
}