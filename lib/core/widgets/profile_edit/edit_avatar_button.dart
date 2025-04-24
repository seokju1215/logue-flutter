import 'package:flutter/material.dart';

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
    final bool isBasic = avatarUrl == 'basic';

    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: CircleAvatar(
            radius: 48,
            backgroundColor: Colors.white,
            backgroundImage: isBasic
                ? null
                : NetworkImage(avatarUrl),
            child: isBasic
                ? ClipOval(
              child: Image.asset(
                'assets/basic_avatar.png',
                width: 96,
                height: 96,
                fit: BoxFit.cover,
              ),
            )
                : null,
          ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: CircleAvatar(
            radius: 14,
            backgroundColor: Colors.white,
            child: IconButton(
              icon: const Icon(Icons.camera_alt, size: 16),
              onPressed: () {
                // TODO: 갤러리 열기 + 업로드 후 onAvatarChanged 호출
                onAvatarChanged('https://example.com/new_avatar.png');
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
        ),
      ],
    );
  }
}