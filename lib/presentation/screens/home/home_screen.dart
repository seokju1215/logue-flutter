import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child:
           Text(
              '홈화면임',
              style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
      ),
    );
  }
}