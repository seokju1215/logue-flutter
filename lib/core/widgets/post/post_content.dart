import 'package:flutter/material.dart';
import 'package:my_logue/core/themes/app_colors.dart';
import 'package:my_logue/data/models/book_post_model.dart';
import 'package:my_logue/presentation/screens/post/post_detail_screen.dart';

class PostContent extends StatefulWidget {
  final BookPostModel post;
  final VoidCallback? onTapMore; // ✅ 상세 화면에서 삭제 후 반영할 콜백

  const PostContent({super.key, required this.post, this.onTapMore});

  @override
  State<PostContent> createState() => _PostContentState();
}

class _PostContentState extends State<PostContent> {
  String? _displayText;
  bool _shouldShowMoreButton = false;
  bool _isCalculated = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didUpdateWidget(PostContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    // post가 변경된 경우에만 다시 계산
    if (oldWidget.post.reviewContent != widget.post.reviewContent) {
      _isCalculated = false;
      _calculateTextLayout();
    }
  }
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isCalculated) {
      _calculateTextLayout();
    }
  }

  void _calculateTextLayout() {
    if (_isCalculated) return;

    final fullText = widget.post.reviewContent ?? '';
    if (fullText.isEmpty) {
      setState(() {
        _displayText = '';
        _shouldShowMoreButton = false;
        _isCalculated = true;
      });
      return;
    }

    const maxLines = 5;
    const moreText = '더보기';
    const ellipsis = '... ';
    final textStyle = const TextStyle(
      fontSize: 14,
      color: AppColors.black500,
      height: 2,
      letterSpacing: -0.32,
    );

    final textPainter = TextPainter(
      text: TextSpan(text: fullText, style: textStyle),
      maxLines: maxLines,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: MediaQuery.of(context).size.width - 44);

    if (!textPainter.didExceedMaxLines) {
      setState(() {
        _displayText = fullText;
        _shouldShowMoreButton = false;
        _isCalculated = true;
      });
    } else {
      // " ... 더보기"가 들어갈 공간 확보
      int endIndex = fullText.length;
      for (int i = fullText.length - 1; i > 0; i--) {
        final testText = fullText.substring(0, i) + ellipsis + moreText;
        final testPainter = TextPainter(
          text: TextSpan(text: testText, style: textStyle),
          maxLines: maxLines,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: MediaQuery.of(context).size.width - 44);

        if (!testPainter.didExceedMaxLines) {
          endIndex = i;
          break;
        }
      }

      setState(() {
        _displayText = fullText.substring(0, endIndex) + ellipsis;
        _shouldShowMoreButton = true;
        _isCalculated = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = widget.post.reviewContent ?? '';
    
    if (content.isEmpty) {
      return const SizedBox(height: 0);
    }

    final textStyle = const TextStyle(fontSize: 14, color: AppColors.black500, height: 2, letterSpacing: -0.32);

    // 계산이 완료되지 않았으면 전체 텍스트를 표시 (레이아웃 안정성 확보)
    if (!_isCalculated) {
      return Text(
        content,
        style: textStyle,
      );
    }

    return _shouldShowMoreButton
        ? RichText(
            text: TextSpan(
              style: textStyle,
              children: [
                TextSpan(text: _displayText),
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
                        widget.onTapMore!();
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
            _displayText ?? '',
            style: textStyle,
          );
  }
}