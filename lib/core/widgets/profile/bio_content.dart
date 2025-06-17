import 'package:flutter/material.dart';
import '../../themes/app_colors.dart';

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

  static const double fontSize = 12;
  static const double lineHeight = 1.2;
  static const int maxLines = 2;

  final textStyle = const TextStyle(
    fontSize: fontSize,
    color: AppColors.black900,
    fontFamily: 'Inter',
    fontWeight: FontWeight.w400,
    height: lineHeight,
    letterSpacing: -0.32,
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
      int end = fullText.length;
      while (end > 0) {
        final test = fullText.substring(0, end) + suffix;
        final testSpan = TextSpan(text: test, style: textStyle);
        final testTp = TextPainter(
          text: testSpan,
          textDirection: TextDirection.ltr,
          textHeightBehavior: textHeightBehavior,
          maxLines: maxLines,
        )..layout(maxWidth: widget.maxWidth - 20);

        if (!testTp.didExceedMaxLines) {
          setState(() {
            _truncatedText = fullText.substring(0, end).trimRight();
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
            : RichText(
          textHeightBehavior: textHeightBehavior,
          overflow: TextOverflow.clip,
          maxLines: maxLines,
          text: TextSpan(
            style: textStyle,
            children: [
              TextSpan(text: _truncatedText),
              WidgetSpan(
                alignment: PlaceholderAlignment.bottom,
                child: Text(
                  '...',
                  style: textStyle.copyWith(
                    fontSize: 12,
                    color: AppColors.black900,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}