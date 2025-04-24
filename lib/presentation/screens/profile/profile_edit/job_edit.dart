import 'package:flutter/material.dart';

class JobEdit extends StatelessWidget {
  const JobEdit({super.key});

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
          '직업 편집 화면',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ),
    );
  }
}