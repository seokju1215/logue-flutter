import 'package:flutter/material.dart';

class StrokeTextStyle {
  /// 테두리가 있는 텍스트 스타일을 생성합니다.
  /// 
  /// [fontSize] - 텍스트 크기
  /// [fontWeight] - 텍스트 굵기
  /// [color] - 텍스트 색상
  /// [strokeWidth] - 테두리 두께 (기본값: 0.2)
  /// [strokeColor] - 테두리 색상 (기본값: 텍스트 색상과 동일)
  static List<TextStyle> stroke({
    required double fontSize,
    required FontWeight fontWeight,
    required Color color,
    double strokeWidth = 0.2,
    Color? strokeColor,
    double? height,
  }) {
    return [
      // 테두리용 텍스트 스타일
      TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        height: height,
        foreground: Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..color = strokeColor ?? color,
      ),
      // 내부 텍스트 스타일
      TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        height: height,
        color: color,
      ),
    ];
  }

  /// Stack과 함께 사용할 수 있는 테두리가 있는 텍스트 위젯을 생성합니다.
  static Stack createStrokeText({
    required String text,
    required double fontSize,
    required FontWeight fontWeight,
    required Color color,
    double strokeWidth = 0.2,
    Color? strokeColor,
    TextAlign? textAlign,
    double? height,
  }) {
    final styles = stroke(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      strokeWidth: strokeWidth,
      strokeColor: strokeColor,
      height: height,
    );

    return Stack(
      children: [
        // 테두리용 텍스트
        Text(
          text,
          style: styles[0],
          textAlign: textAlign,
        ),
        // 내부 텍스트
        Text(
          text,
          style: styles[1],
          textAlign: textAlign,
        ),
      ],
    );
  }
}