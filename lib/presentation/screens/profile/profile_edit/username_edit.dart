import 'package:flutter/material.dart';

class UserNameEdit extends StatelessWidget {
  const UserNameEdit({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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