import 'package:flutter/material.dart';

class UserNameEdit extends StatelessWidget {
  const UserNameEdit({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pop(context); // 이전 화면으로 돌아가기
            },
          ),
          title: const Text('알림')
      ),
      body: Center(
        child:
        Text(
          '사용자 이름 변경 화면',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ),
    );
  }
}