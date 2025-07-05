import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:logue/core/themes/app_colors.dart';

class AnnouncementDialog extends StatelessWidget {
  final String title;
  final String body;

  const AnnouncementDialog({
    super.key,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final lines = body.replaceAll(r'\n', '\n').split('\n');

    return GestureDetector(
      onTap: () {},
      child: Stack(
        children: [
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(color: Colors.black.withOpacity(0.3)),
            ),
          ),
          Center(
            child: GestureDetector(
              onTap: () {},
              child: Stack(
                children: [
                  Container(
                    width: 300,
                    padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 25),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 20,
                            color: AppColors.black900,
                            fontWeight: FontWeight.normal, decoration: TextDecoration.none,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: (body.replaceAll(r'\n', '\n'))
                              .split('\n')
                              .map((line) => Padding(
                            padding: const EdgeInsets.only(bottom: 0),
                            child: Text(
                              line,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.black500,
                                fontWeight: FontWeight.normal,
                                decoration: TextDecoration.none,
                                height: 1.5,
                              ),
                            ),
                          ))
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.close, size: 26, color: AppColors.black900),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}