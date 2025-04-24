import 'package:flutter/material.dart';

class ProfileEditButton extends StatelessWidget {
  final String label;       // 위에 표시되는 회색 텍스트
  final String username;    // 버튼 안에 표시될 유저 이름
  final VoidCallback onTap; // 버튼 클릭 시 실행될 함수

  const ProfileEditButton({
    Key? key,
    required this.label,
    required this.username,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Stack(
          children: [
            OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.grey, width: 1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  username,
                  style: const TextStyle(color: Colors.black),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}