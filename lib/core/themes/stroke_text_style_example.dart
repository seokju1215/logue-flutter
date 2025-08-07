import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'stroke_text_style.dart';

class ExampleWidget extends StatelessWidget {
  const ExampleWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // 방법 1: 스타일만 가져와서 사용
    final strokeStyles = StrokeTextStyle.stroke(
      fontSize: 14,
      fontWeight: FontWeight.bold,
      color: AppColors.white500,
    );

    return Column(
      children: [
        // 방법 1: 스타일 사용
        Stack(
          children: [
            Text('문의 접수', style: strokeStyles[0]),
            Text('문의 접수', style: strokeStyles[1]),
          ],
        ),
        
        const SizedBox(height: 20),
        
        // 방법 2: 바로 위젯으로 사용
        StrokeTextStyle.createStrokeText(
          text: '문의 접수',
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppColors.white500,
        ),
        
        // 커스텀 테두리 색상과 두께 사용
        StrokeTextStyle.createStrokeText(
          text: '문의 접수',
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppColors.white500,
          strokeWidth: 0.5,
          strokeColor: Colors.black,
        ),
      ],
    );
  }
}