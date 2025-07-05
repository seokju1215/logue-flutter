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
  bool _hasCalculated = false; // 추가: 계산 완료 플래그

  @override
  void initState() {
    super.initState();
    _calculateText();
  }

  @override
  void didUpdateWidget(PostContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    // post가 변경된 경우에만 다시 계산
    if (oldWidget.post.reviewContent != widget.post.reviewContent) {
      _hasCalculated = false;
      _calculateText();
    }
  }

  void _calculateText() {
    if (_hasCalculated) return; // 이미 계산된 경우 스킵

    final fullText = widget.post.reviewContent ?? '';
    if (fullText.isEmpty) {
      setState(() {
        truncatedText = '';
        shouldShowMoreButton = false;
        _hasCalculated = true;
      });
      return;
    }

    // 비동기로 계산하여 UI 블로킹 방지
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      
      _truncateToFitWithButton();
    });
  }

  void _truncateToFitWithButton() {
    if (_hasCalculated) return;

    final fullText = widget.post.reviewContent ?? '';
    final textStyle = const TextStyle(fontSize: 14, color: AppColors.black500, height: 2, letterSpacing: -0.32);

    // '... 더보기'가 붙은 텍스트로 줄 수 계산
    final testText = fullText + '... 더보기';
    final testSpan = TextSpan(text: testText, style: textStyle);
    final testTp = TextPainter(
      text: testSpan,
      textDirection: TextDirection.ltr,
      maxLines: null,
    );
    testTp.layout(maxWidth: MediaQuery.of(context).size.width - 56);

    final lineCount = testTp.computeLineMetrics().length;

    if (lineCount <= 5) {
      setState(() {
        truncatedText = fullText;
        shouldShowMoreButton = false;
        _hasCalculated = true;
      });
      return;
    }

    // 5줄에 맞게 자르기
    int endIndex = fullText.length;
    while (endIndex > 0) {
      final cutText = fullText.substring(0, endIndex) + '... 더보기';
      final cutSpan = TextSpan(text: cutText, style: textStyle);
      final cutTp = TextPainter(
        text: cutSpan,
        textDirection: TextDirection.ltr,
        maxLines: null,
      );
      cutTp.layout(maxWidth: MediaQuery.of(context).size.width - 56);

      if (cutTp.computeLineMetrics().length <= 5) break;
      endIndex--;
    }

    setState(() {
      truncatedText = fullText.substring(0, endIndex) + '... ';
      shouldShowMoreButton = true;
      _hasCalculated = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final content = widget.post.reviewContent ?? '';
    
    // content가 비어있으면 최소 높이를 유지하여 일관된 패딩 보장
    if (content.isEmpty) {
      return const SizedBox(height: 0);
    }
    
    final textStyle = const TextStyle(fontSize: 14, color: AppColors.black500, height : 2,letterSpacing: -0.32);

    return shouldShowMoreButton
        ? RichText(
      text: TextSpan(
        style: textStyle,
        children: [
          TextSpan(text: truncatedText),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
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
              child: Text(
                '더보기',
                style: TextStyle(
                  fontSize: 14,
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