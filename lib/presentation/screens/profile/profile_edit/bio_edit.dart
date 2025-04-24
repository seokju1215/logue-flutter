import 'package:flutter/material.dart';

class BioEdit extends StatelessWidget {
  const BioEdit({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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