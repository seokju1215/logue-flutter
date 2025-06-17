import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:logue/core/themes/app_colors.dart';

import '../../../data/utils/amplitude_util.dart';

class ProfileLinkTile extends StatefulWidget {
  final String link;

  const ProfileLinkTile({super.key, required this.link});

  @override
  State<ProfileLinkTile> createState() => _ProfileLinkTileState();
}

class _ProfileLinkTileState extends State<ProfileLinkTile> {
  bool _copied = false;

  void _copyToClipboard() async {
    await Clipboard.setData(ClipboardData(text: widget.link));
    setState(() => _copied = true);
    AmplitudeUtil.log('profile_shared', props: {
      'target_type': 'my',
      'source_page' : 'profile_edit_screen'
    });

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _copied = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
    const Padding(
    padding: EdgeInsets.only(left: 9),
    child:Text(
          '프로필 링크',
          style: TextStyle(fontSize: 12, color: AppColors.black500),
        ),),
        const SizedBox(height: 3),
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.black500),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.link,
                      style: const TextStyle(fontSize: 14, color: AppColors.black500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  GestureDetector(
                    onTap: _copyToClipboard,
                    child: SvgPicture.asset(
                      'assets/share_button.svg',
                      width: 20,
                      height: 20,
                    ),
                  ),
                ],
              ),
            ),
            if (_copied)
              const Positioned(
                bottom: -22,
                right: 4,
                child: Text(
                  '복사되었습니다.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.blue500,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}