import 'package:flutter/material.dart';
import '../../themes/app_colors.dart';

class PostContent extends StatefulWidget {
  final String reviewContent;

  const PostContent({super.key, required this.reviewContent});

  @override
  State<PostContent> createState() => _PostContentState();
}

class _PostContentState extends State<PostContent> {
  late String truncatedText;
  bool shouldShowMoreButton = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _truncateToFitWithButton();
    });
  }

  void _truncateToFitWithButton() {
    final fullText = widget.reviewContent;
    final textStyle = const TextStyle(fontSize: 12, color: AppColors.black500);

    final span = TextSpan(text: fullText, style: textStyle);
    final tp = TextPainter(
      text: span,
      maxLines: 3,
      textDirection: TextDirection.ltr,
    );

    tp.layout(maxWidth: MediaQuery.of(context).size.width - 44); // 좌우 22 padding
    if (!tp.didExceedMaxLines) {
      setState(() {
        truncatedText = fullText;
        shouldShowMoreButton = false;
      });
      return;
    }

    // 글자를 줄여가며 몇 글자까지 넣을 수 있는지 계산
    int endIndex = fullText.length;
    while (endIndex > 0) {
      final testSpan = TextSpan(
        text: fullText.substring(0, endIndex) + '... 더보기',
        style: textStyle,
      );
      final testTp = TextPainter(
        text: testSpan,
        maxLines: 3,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: MediaQuery.of(context).size.width - 44);

      if (!testTp.didExceedMaxLines) break;
      endIndex--;
    }

    setState(() {
      truncatedText = fullText.substring(0, endIndex) + '... ';
      shouldShowMoreButton = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = const TextStyle(fontSize: 12, color: AppColors.black500);

    return shouldShowMoreButton
        ? RichText(
      text: TextSpan(
        style: textStyle,
        children: [
          TextSpan(text: truncatedText),
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: GestureDetector(
              onTap: () {
                // 👉 상세 페이지 이동
              },
              child: const Text(
                '더보기',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.black500,
                ),
              ),
            ),
          ),
        ],
      ),
    )
        : Text(
      widget.reviewContent,
      style: textStyle,
    );
  }
}