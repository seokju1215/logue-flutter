import 'package:flutter/material.dart';
import 'package:my_logue/core/themes/app_colors.dart';

class InquiryCard extends StatefulWidget {
  final String userId;
  final String request;
  final String details;
  final String date;
  final String status;

  const InquiryCard({
    Key? key,
    required this.userId,
    required this.request,
    required this.details,
    required this.date,
    required this.status,
  }) : super(key: key);

  @override
  State<InquiryCard> createState() => _InquiryCardState();
}

class _InquiryCardState extends State<InquiryCard> {
  String _displayDetails = '';
  String _displayTitle = '';

  static const double fontSize = 12;
  static const double lineHeight = 1.25;
  static const int maxLines = 1;

  final textStyle = const TextStyle(
    fontSize: fontSize,
    height: lineHeight,
    color: AppColors.black500,
  );

  final titleStyle = const TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.black900,
    height: 1.23
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calculateDisplayText();
      _calculateDisplayTitle();
    });
  }

  @override
  void didUpdateWidget(covariant InquiryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.details != widget.details) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _calculateDisplayText());
    }
    if (oldWidget.request != widget.request) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _calculateDisplayTitle());
    }
  }

  void _calculateDisplayText() {
    final fullText = widget.details;
    if (fullText.isEmpty) {
      setState(() {
        _displayDetails = '';
      });
      return;
    }

    // 컨테이너의 실제 너비를 계산
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final maxWidth = renderBox.size.width - 30; // 패딩 고려

    // 전체 텍스트가 한 줄에 들어가는지 확인
    final fullSpan = TextSpan(text: fullText, style: textStyle);
    final fullTp = TextPainter(
      text: fullSpan,
      textDirection: TextDirection.ltr,
      maxLines: maxLines,
    )..layout(maxWidth: maxWidth);

    // 텍스트가 잘렸는지 확인 (width가 maxWidth를 초과하거나 줄바꿈이 발생한 경우)
    if (fullTp.width <= maxWidth && !fullTp.didExceedMaxLines) {
      setState(() {
        _displayDetails = fullText;
      });
    } else {
      // 텍스트가 잘렸으므로 "..." 추가
      const suffix = '...';
      int end = fullText.length;
      
      while (end > 0) {
        final testText = fullText.substring(0, end) + suffix;
        final testSpan = TextSpan(text: testText, style: textStyle);
        final testTp = TextPainter(
          text: testSpan,
          textDirection: TextDirection.ltr,
          maxLines: maxLines,
        )..layout(maxWidth: maxWidth);

        if (testTp.width <= maxWidth && !testTp.didExceedMaxLines) {
          setState(() {
            _displayDetails = fullText.substring(0, end).trimRight() + suffix;
          });
          return;
        }
        end--;
      }

      // 자르기 실패 시 최소한의 텍스트라도 표시
      setState(() {
        _displayDetails = fullText.length > 3 ? fullText.substring(0, 3) + suffix : fullText;
      });
    }
  }

  void _calculateDisplayTitle() {
    final fullText = widget.request;
    if (fullText.isEmpty) {
      setState(() {
        _displayTitle = '';
      });
      return;
    }

    // 컨테이너의 실제 너비를 계산
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final maxWidth = renderBox.size.width - 30; // 패딩 고려

    // 전체 텍스트가 한 줄에 들어가는지 확인
    final fullSpan = TextSpan(text: fullText, style: titleStyle);
    final fullTp = TextPainter(
      text: fullSpan,
      textDirection: TextDirection.ltr,
      maxLines: maxLines,
    )..layout(maxWidth: maxWidth);

    // 텍스트가 잘렸는지 확인 (width가 maxWidth를 초과하거나 줄바꿈이 발생한 경우)
    if (fullTp.width <= maxWidth && !fullTp.didExceedMaxLines) {
      setState(() {
        _displayTitle = fullText;
      });
    } else {
      // 텍스트가 잘렸으므로 "..." 추가
      const suffix = '...';
      int end = fullText.length;
      
      while (end > 0) {
        final testText = fullText.substring(0, end) + suffix;
        final testSpan = TextSpan(text: testText, style: titleStyle);
        final testTp = TextPainter(
          text: testSpan,
          textDirection: TextDirection.ltr,
          maxLines: maxLines,
        )..layout(maxWidth: maxWidth);

        if (testTp.width <= maxWidth && !testTp.didExceedMaxLines) {
          setState(() {
            _displayTitle = fullText.substring(0, end).trimRight() + suffix;
          });
          return;
        }
        end--;
      }

      // 자르기 실패 시 최소한의 텍스트라도 표시
      setState(() {
        _displayTitle = fullText.length > 3 ? fullText.substring(0, 3) + suffix : fullText;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFD9D9D9),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 4,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.userId,
            style: const TextStyle(
              fontSize: 12,
              height: 1.25,
              fontWeight: FontWeight.w400,
              color: AppColors.black500,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            _displayTitle,
            style: titleStyle,
            maxLines: maxLines,
          ),
          const SizedBox(height: 5),
          Text(
            _displayDetails,
            style: textStyle,
            maxLines: maxLines,
          ),
          const SizedBox(height: 5),
          Text(
            widget.date,
            style: const TextStyle(
              fontSize: 10,
              height: 1.2,
              color: AppColors.black500,
            ),
          ),
        ],
      ),
    );
  }
}
