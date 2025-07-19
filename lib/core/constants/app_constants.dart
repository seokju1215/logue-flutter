import 'package:flutter/material.dart';

class AppConstants {
  // AppBar를 포함한 전체 화면 중앙으로 이동하기 위한 오프셋 계산
  static Offset getCenterOffset(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    return Offset(0, -MediaQuery.of(context).padding.top - kToolbarHeight / 2 + keyboardHeight);
  }
  
  // 탭바가 있는 AppBar를 포함한 전체 화면 중앙으로 이동하기 위한 오프셋 계산
  static Offset getCenterOffsetWithTabBar(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    return Offset(0, -MediaQuery.of(context).padding.top - kToolbarHeight / 2 - 24 + keyboardHeight); // 탭바 높이의 절반만큼 추가로 위로
  }
} 