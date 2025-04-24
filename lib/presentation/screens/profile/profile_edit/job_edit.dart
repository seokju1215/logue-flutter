import 'package:flutter/material.dart';

class JobEdit extends StatelessWidget {
  const JobEdit({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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