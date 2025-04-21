import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: // TODO:  약관 동의 화면 접근용 텍스트 버튼 지우기
          TextButton(
            onPressed: () {
              Navigator.pushNamed(context, '/terms');
            },
            child: const Text(
              '🛠 약관 동의 화면 보기 (개발용)',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
      ),
    );
  }
}