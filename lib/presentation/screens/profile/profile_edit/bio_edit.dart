import 'package:flutter/material.dart';

class BioEdit extends StatelessWidget {
  const BioEdit({super.key});

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
          '소개글 편집 화면',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ),
    );
  }
}