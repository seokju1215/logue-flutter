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
    _calculateTextLayout();
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

    // 간단한 문자 수 기반 계산으로 성능 향상
    final estimatedCharsPerLine = 35; // 대략적인 한 줄당 문자 수
    final maxLines = 5;
    final estimatedMaxChars = estimatedCharsPerLine * maxLines;

    if (fullText.length <= estimatedMaxChars) {
      // 예상 5줄 이하면 전체 텍스트 표시
      setState(() {
        _displayText = fullText;
        _shouldShowMoreButton = false;
        _isCalculated = true;
      });
    } else {
      // 예상 5줄 초과면 자르기
      final truncatedText = fullText.substring(0, estimatedMaxChars - 10) + '... ';
      
      setState(() {
        _displayText = truncatedText;
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