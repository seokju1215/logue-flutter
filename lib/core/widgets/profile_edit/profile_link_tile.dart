import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ProfileLinkTile extends StatelessWidget {
  final String link;

  const ProfileLinkTile({super.key, required this.link});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(link),
      trailing: IconButton(
        icon: const Icon(Icons.link),
        onPressed: () {
          Clipboard.setData(ClipboardData(text: link));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('복사되었습니다.')),
          );
        },
      ),
    );
  }
}