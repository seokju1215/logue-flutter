import 'package:flutter/material.dart';
import 'package:logue/core/themes/app_colors.dart';
import 'package:logue/data/models/book_post_model.dart';
import 'package:logue/presentation/screens/post/post_detail_screen.dart';

class PostContent extends StatefulWidget {
  final BookPostModel post;
  final VoidCallback? onTapMore; // ✅ 상세 화면에서 삭제 후 반영할 콜백

  const PostContent({super.key, required this.post, this.onTapMore});

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
    final fullText = widget.post.reviewContent ?? '';
    final textStyle = const TextStyle(fontSize: 12, color: AppColors.black500, letterSpacing: -0.32);

    final span = TextSpan(text: fullText, style: textStyle);
    final tp = TextPainter(
      text: span,
      maxLines: 6,
      textDirection: TextDirection.ltr,
    );

    tp.layout(maxWidth: MediaQuery.of(context).size.width - 44);
    if (!tp.didExceedMaxLines) {
      setState(() {
        truncatedText = fullText;
        shouldShowMoreButton = false;
      });
      return;
    }

    int endIndex = fullText.length;
    while (endIndex > 0) {
      final testSpan = TextSpan(
        text: fullText.substring(0, endIndex) + '... 더보기',
        style: textStyle,
      );
      final testTp = TextPainter(
        text: testSpan,
        maxLines: 6,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: MediaQuery.of(context).size.width - 56);

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
    final textStyle = const TextStyle(fontSize: 12, color: AppColors.black500, letterSpacing: -0.32);

    return shouldShowMoreButton
        ? RichText(
      text: TextSpan(
        style: textStyle,
        children: [
          TextSpan(text: truncatedText),
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: GestureDetector(
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PostDetailScreen(post: widget.post),
                  ),
                );

                if (result == true && widget.onTapMore != null) {
                  widget.onTapMore!(); // ✅ 삭제 후 목록 갱신
                }
              },
              child: const Text(
                '더보기',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.black500,
                  height: 1,
                  letterSpacing: -0.32
                ),
              ),
            ),
          ),
        ],
      ),
    )
        : Text(
      widget.post.reviewContent ?? '',
      style: textStyle,
    );
  }
}