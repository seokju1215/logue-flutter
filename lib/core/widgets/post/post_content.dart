import 'package:flutter/material.dart';
import 'package:my_logue/core/themes/app_colors.dart';
import 'package:my_logue/data/models/book_post_model.dart';
import 'package:my_logue/presentation/screens/post/post_detail_screen.dart';

class PostContent extends StatefulWidget {
  final BookPostModel post;
  final VoidCallback? onTapMore; // ✅ 상세 화면에서 삭제 후 반영할 콜백
  final String? fromScreen;
  final VoidCallback? onDeleteSuccess;
  final VoidCallback? onEditSuccess;
  final VoidCallback? onArchiveSuccess;
  final bool isMyPost;
  const PostContent({super.key, required this.post, this.onTapMore, this.fromScreen, this.onDeleteSuccess, this.onEditSuccess, this.onArchiveSuccess,required this.isMyPost});

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

    final stopwatch = Stopwatch()..start();
    debugPrint('   🔍 PostContent _calculateTextLayout 시작');
    debugPrint('     - reviewContent 길이: ${widget.post.reviewContent?.length ?? 0}');

    // 최적화된 UTF-16 안전 텍스트 처리
    String _safeText(String? text) {
      if (text == null || text.isEmpty) return '';
      
      try {
        // 1단계: 기본적인 잘못된 문자 제거 (정규식으로 빠르게)
        String cleaned = text.replaceAll(RegExp(r'[\uFFFD\u0000-\u001F\u007F-\u009F]'), '');
        
        // 2단계: 잘못된 서로게이트 쌍 제거 (정규식으로 빠르게)
        cleaned = cleaned.replaceAll(RegExp(r'[\uD800-\uDBFF](?![\uDC00-\uDFFF])'), ''); // 단독 상위 서로게이트
        cleaned = cleaned.replaceAll(RegExp(r'(?<![\uD800-\uDBFF])[\uDC00-\uDFFF]'), ''); // 단독 하위 서로게이트
        
        // 3단계: 연속된 공백 정리
        cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
        
        return cleaned.isEmpty ? '' : cleaned;
      } catch (e) {
        debugPrint('⚠️ PostContent 텍스트 정리 실패: $e');
        return text; // 실패 시 원본 반환
      }
    }

    final fullText = _safeText(widget.post.reviewContent);
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

    // 최적화된 최종 텍스트 검증 (간단한 정규식 사용)
    String _finalSafeText(String text) {
      try {
        // 이미 _safeText에서 처리했으므로 추가 검증만 수행
        return text.replaceAll(RegExp(r'[\uFFFD]'), ''); // 대체 문자만 제거
      } catch (e) {
        debugPrint('⚠️ 최종 텍스트 검증 실패: $e');
        return text; // 실패 시 원본 반환
      }
    }

    final safeFullText = _finalSafeText(fullText);
    if (safeFullText.isEmpty) {
      setState(() {
        _displayText = '';
        _shouldShowMoreButton = false;
        _isCalculated = true;
      });
      return;
    }

    // 간단한 문자 수 기반으로 더보기 버튼 결정 (TextPainter 대신)
    const maxChars = 200; // 대략적인 문자 수 제한
    
    if (safeFullText.length <= maxChars) {
      setState(() {
        _displayText = fullText;
        _shouldShowMoreButton = false;
        _isCalculated = true;
      });
    } else {
      // 간단한 문자 수 기반으로 잘라내기
      int endIndex = maxChars;
      
      // 단어 경계에서 자르기 (더 자연스러운 잘라내기)
      for (int i = maxChars; i > maxChars - 50 && i > 0; i--) {
        if (safeFullText[i] == ' ' || safeFullText[i] == '\n') {
          endIndex = i;
          break;
        }
      }

      setState(() {
        _displayText = safeFullText.substring(0, endIndex) + ellipsis;
        _shouldShowMoreButton = true;
        _isCalculated = true;
      });
    }
    
    stopwatch.stop();
    debugPrint('   ⏱️ PostContent _calculateTextLayout 소요시간: ${stopwatch.elapsedMicroseconds}μs');
    if (stopwatch.elapsedMicroseconds > 5000) {
      debugPrint('   ⚠️ PostContent 텍스트 계산 시간 초과! 렉 발생 가능성 높음!');
    }
  }

  @override
  Widget build(BuildContext context) {
    final stopwatch = Stopwatch()..start();
    debugPrint('   🎨 PostContent build 시작');
    
    // 최적화된 UTF-16 안전 텍스트 처리 (build 메서드용)
    String _safeText(String? text) {
      if (text == null || text.isEmpty) return '';
      
      try {
        // 1단계: 기본적인 잘못된 문자 제거 (정규식으로 빠르게)
        String cleaned = text.replaceAll(RegExp(r'[\uFFFD\u0000-\u001F\u007F-\u009F]'), '');
        
        // 2단계: 잘못된 서로게이트 쌍 제거 (정규식으로 빠르게)
        cleaned = cleaned.replaceAll(RegExp(r'[\uD800-\uDBFF](?![\uDC00-\uDFFF])'), ''); // 단독 상위 서로게이트
        cleaned = cleaned.replaceAll(RegExp(r'(?<![\uD800-\uDBFF])[\uDC00-\uDFFF]'), ''); // 단독 하위 서로게이트
        
        // 3단계: 연속된 공백 정리
        cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
        
        return cleaned.isEmpty ? '' : cleaned;
      } catch (e) {
        debugPrint('⚠️ PostContent build 텍스트 정리 실패: $e');
        return text; // 실패 시 원본 반환
      }
    }

    final content = _safeText(widget.post.reviewContent);
    
    if (content.isEmpty) {
      return const SizedBox(height: 0);
    }

    final textStyle = const TextStyle(fontSize: 14, color: AppColors.black500, height: 2, letterSpacing: -0.32);

    // 계산이 완료되지 않았으면 전체 텍스트를 표시 (레이아웃 안정성 확보)
    if (!_isCalculated) {
      // 안전한 텍스트로 표시
      final safeContent = _safeText(content);
      if (safeContent.isEmpty) {
        stopwatch.stop();
        debugPrint('   ⏱️ PostContent build 소요시간: ${stopwatch.elapsedMicroseconds}μs (빈 컨텐츠)');
        return const SizedBox(height: 0);
      }
      stopwatch.stop();
      debugPrint('   ⏱️ PostContent build 소요시간: ${stopwatch.elapsedMicroseconds}μs (미계산 상태)');
      return Text(
        safeContent,
        style: textStyle,
      );
    }

    final result = _shouldShowMoreButton
        ? RichText(
            text: TextSpan(
              style: textStyle,
              children: [
                TextSpan(text: _safeText(_displayText)),
                WidgetSpan(
                  alignment: PlaceholderAlignment.baseline,
                  baseline: TextBaseline.alphabetic,
                  child: GestureDetector(
                    onTap: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PostDetailScreen(post: widget.post, fromScreen: widget.fromScreen, onDeleteSuccess: widget.onDeleteSuccess, onEditSuccess: widget.onEditSuccess, onArchiveSuccess: widget.onArchiveSuccess,isMyPost: widget.isMyPost,),
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
            _safeText(_displayText ?? ''),
            style: textStyle,
          );
    
    stopwatch.stop();
    debugPrint('   ⏱️ PostContent build 소요시간: ${stopwatch.elapsedMicroseconds}μs');
    if (stopwatch.elapsedMicroseconds > 5000) {
      debugPrint('   ⚠️ PostContent build 시간 초과! 렉 발생 가능성 높음!');
    }
    
    return result;
  }
}