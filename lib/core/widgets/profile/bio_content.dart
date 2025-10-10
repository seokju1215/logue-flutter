import 'package:flutter/material.dart';
import '../../themes/app_colors.dart';
import 'package:characters/characters.dart';

class BioContent extends StatefulWidget {
  final String bio;
  final double maxWidth;

  const BioContent({
    super.key,
    required this.bio,
    required this.maxWidth,
  });

  @override
  State<BioContent> createState() => _BioContentState();
}

class _BioContentState extends State<BioContent> {
  bool _shouldTruncate = false;
  bool _showFull = false;
  String _truncatedText = '';

  static const double fontSize = 13;
  static const double lineHeight = 1.2;
  static const int maxLines = 2;

  final textStyle = const TextStyle(
    fontSize: fontSize,
    color: AppColors.black900,
    fontFamily: 'Inter',
    fontWeight: FontWeight.w400,
    height: lineHeight,
    letterSpacing: 0.3,
  );

  final textHeightBehavior = const TextHeightBehavior(
    applyHeightToFirstAscent: false,
    applyHeightToLastDescent: false,
  );

  double get _fixedHeight => fontSize * lineHeight * maxLines;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _calculateTruncation());
  }

  @override
  void didUpdateWidget(covariant BioContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bio != widget.bio) {
      _showFull = false;
      _calculateTruncation();
    }
  }

  void _calculateTruncation() {
    final fullText = widget.bio;
    if (fullText.isEmpty) {
      setState(() {
        _truncatedText = '';
        _shouldTruncate = false;
      });
      return;
    }

    final span = TextSpan(text: fullText, style: textStyle);
    final tp = TextPainter(
      text: span,
      textDirection: TextDirection.ltr,
      textHeightBehavior: textHeightBehavior,
      maxLines: maxLines,
    )..layout(maxWidth: widget.maxWidth);

    if (!tp.didExceedMaxLines) {
      setState(() {
        _truncatedText = fullText;
        _shouldTruncate = false;
      });
    } else {
      const suffix = '...';
      // 이모지를 안전하게 처리하기 위해 Characters 사용
      final characters = fullText.characters;
      int end = characters.length;
      while (end > 0) {
        final testChars = characters.take(end);
        final test = testChars.string + suffix;
        final testSpan = TextSpan(text: test, style: textStyle);
        final testTp = TextPainter(
          text: testSpan,
          textDirection: TextDirection.ltr,
          textHeightBehavior: textHeightBehavior,
          maxLines: maxLines,
        )..layout(maxWidth: widget.maxWidth - 20);

        if (!testTp.didExceedMaxLines) {
          setState(() {
            _truncatedText = testChars.string.trimRight();
            _shouldTruncate = true;
          });
          return;
        }
        end--;
      }

      setState(() {
        _truncatedText = '';
        _shouldTruncate = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.bio.isEmpty) {
      return SizedBox(height: _fixedHeight);
    }

    return GestureDetector(
      onTap: () => setState(() => _showFull = true),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: _fixedHeight,
          maxWidth: widget.maxWidth,
        ),
        child: _showFull || !_shouldTruncate
            ? Text(
          widget.bio,
          style: textStyle,
          textHeightBehavior: textHeightBehavior,
          softWrap: true,
        )
            : Text(
          '${_truncatedText}...',
          style: textStyle,
          textHeightBehavior: textHeightBehavior,
          softWrap: true,
          maxLines: maxLines,
          overflow: TextOverflow.clip,
        ),
      ),
    );
  }
}