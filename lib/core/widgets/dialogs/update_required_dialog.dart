import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:logue/core/themes/app_colors.dart';

class UpdateRequiredDialog extends StatelessWidget {
  final String title;
  final String body;
  final String storeUrl;
  final bool forceUpdate;

  const UpdateRequiredDialog({
    super.key,
    required this.title,
    required this.body,
    required this.storeUrl,
    this.forceUpdate = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: forceUpdate ? null : () => Navigator.pop(context),
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
                        const SizedBox(height: 10),
                        Text(title, style: const TextStyle(fontSize: 20, color: AppColors.black900, fontWeight: FontWeight.normal, decoration: TextDecoration.none,)),
                        const SizedBox(height: 9),
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
                                height: 1.2,
                              ),
                            ),
                          ))
                              .toList(),
                        ),
                        const SizedBox(height: 11),
                        ElevatedButton(
                          onPressed: () async {
                            final uri = Uri.parse(storeUrl);
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.black900,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(5),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 72, vertical: 8),
                            elevation: 0,
                          ),
                          child: const Text('지금 업데이트', style: TextStyle(fontSize: 16,fontWeight: FontWeight.normal,)),
                        ),
                      ],
                    ),
                  ),
                  if (!forceUpdate)
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