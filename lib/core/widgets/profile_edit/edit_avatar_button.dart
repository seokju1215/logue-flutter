import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class EditAvatarButton extends StatelessWidget {
  final String avatarUrl;
  final void Function(String) onAvatarChanged;

  const EditAvatarButton({
    super.key,
    required this.avatarUrl,
    required this.onAvatarChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        CircleAvatar(
          radius: 48,
          backgroundImage: avatarUrl == 'basic' ? null : NetworkImage(avatarUrl),
          child: avatarUrl == 'basic'
              ? SvgPicture.asset('assets/basic_avatar.svg', width: 48, height: 48)
              : null,
        ),
        CircleAvatar(
          radius: 14,
          backgroundColor: Colors.white,
          child: IconButton(
            icon: const Icon(Icons.camera_alt, size: 16),
            onPressed: () {
              // TODO: 갤러리 열기 + 업로드 후 onAvatarChanged 호출
              onAvatarChanged('https://example.com/new_avatar.png');
            },
          ),
        ),
      ],
    );
  }
}