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

    // UTF-16 인코딩 문제 해결을 위한 안전한 텍스트 처리
    String _safeText(String? text) {
      if (text == null || text.isEmpty) return '';
      try {
        // 더 강력한 UTF-16 정리
        String cleaned = text;
        
        // 1단계: 기본적인 잘못된 문자 제거
        cleaned = cleaned.replaceAll(RegExp(r'[\uFFFD\u0000-\u001F\u007F-\u009F]'), '');
        
        // 2단계: UTF-16 유효성 검사 및 복구
        try {
          final bytes = text.codeUnits;
          final validChars = <int>[];
          
          for (int i = 0; i < bytes.length; i++) {
            final codeUnit = bytes[i];
            
            // 기본 평면 문자 (U+0000 ~ U+FFFF)
            if (codeUnit >= 0 && codeUnit <= 0xFFFF) {
              // 서로게이트 쌍 검사
              if (codeUnit >= 0xD800 && codeUnit <= 0xDBFF) {
                // 상위 서로게이트
                if (i + 1 < bytes.length) {
                  final nextCodeUnit = bytes[i + 1];
                  if (nextCodeUnit >= 0xDC00 && nextCodeUnit <= 0xDFFF) {
                    // 유효한 서로게이트 쌍
                    validChars.add(codeUnit);
                    validChars.add(nextCodeUnit);
                    i++; // 다음 문자 건너뛰기
                    continue;
                  }
                }
                // 잘못된 서로게이트 쌍은 건너뛰기
                continue;
              } else if (codeUnit >= 0xDC00 && codeUnit <= 0xDFFF) {
                // 단독 하위 서로게이트는 건너뛰기
                continue;
              } else {
                // 일반 문자
                validChars.add(codeUnit);
              }
            } else {
              // 이모지 등 기본 평면을 벗어나는 문자도 지원
              // UTF-16 서로게이트 쌍으로 처리
              if (codeUnit >= 0xD800 && codeUnit <= 0xDBFF) {
                // 상위 서로게이트
                if (i + 1 < bytes.length) {
                  final nextCodeUnit = bytes[i + 1];
                  if (nextCodeUnit >= 0xDC00 && nextCodeUnit <= 0xDFFF) {
                    // 유효한 서로게이트 쌍 (이모지 포함)
                    validChars.add(codeUnit);
                    validChars.add(nextCodeUnit);
                    i++; // 다음 문자 건너뛰기
                    continue;
                  }
                }
                // 잘못된 서로게이트 쌍은 건너뛰기
                continue;
              } else if (codeUnit >= 0xDC00 && codeUnit <= 0xDFFF) {
                // 단독 하위 서로게이트는 건너뛰기
                continue;
              } else {
                // 기타 문자는 건너뛰기
                continue;
              }
            }
          }
          
          // 유효한 문자들로 문자열 재구성
          cleaned = String.fromCharCodes(validChars);
        } catch (e) {
          debugPrint('⚠️ PostContent UTF-16 복구 실패, 기본 정리 사용: $e');
        }
        
        // 3단계: 최종 정리
        cleaned = cleaned.trim();
        return cleaned.isEmpty ? '' : cleaned;
      } catch (e) {
        debugPrint('⚠️ PostContent 텍스트 정리 실패: $text, 오류: $e');
        return '';
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

    // TextPainter 사용 전 UTF-16 유효성 최종 검증
    String _finalSafeText(String text) {
      try {
        // UTF-16 유효성 검사
        final codeUnits = text.codeUnits;
        final validChars = <int>[];
        
        for (int i = 0; i < codeUnits.length; i++) {
          final codeUnit = codeUnits[i];
          
          // 기본 평면 문자
          if (codeUnit >= 0 && codeUnit <= 0xFFFF) {
            if (codeUnit >= 0xD800 && codeUnit <= 0xDBFF) {
              // 상위 서로게이트
              if (i + 1 < codeUnits.length) {
                final nextCodeUnit = codeUnits[i + 1];
                if (nextCodeUnit >= 0xDC00 && nextCodeUnit <= 0xDFFF) {
                  validChars.add(codeUnit);
                  validChars.add(nextCodeUnit);
                  i++;
                  continue;
                }
              }
              continue;
            } else if (codeUnit >= 0xDC00 && codeUnit <= 0xDFFF) {
              continue;
            } else {
              validChars.add(codeUnit);
            }
          } else {
            // 확장 평면 문자 (이모지 등)
            if (codeUnit >= 0xD800 && codeUnit <= 0xDBFF) {
              if (i + 1 < codeUnits.length) {
                final nextCodeUnit = codeUnits[i + 1];
                if (nextCodeUnit >= 0xDC00 && nextCodeUnit <= 0xDFFF) {
                  validChars.add(codeUnit);
                  validChars.add(nextCodeUnit);
                  i++;
                  continue;
                }
              }
              continue;
            } else if (codeUnit >= 0xDC00 && codeUnit <= 0xDFFF) {
              continue;
            } else {
              continue;
            }
          }
        }
        
        return String.fromCharCodes(validChars);
      } catch (e) {
        debugPrint('⚠️ 최종 UTF-16 검증 실패: $e');
        return '';
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

    final textPainter = TextPainter(
      text: TextSpan(text: safeFullText, style: textStyle),
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
      int endIndex = safeFullText.length;
      for (int i = safeFullText.length - 1; i > 0; i--) {
        final testText = safeFullText.substring(0, i) + ellipsis + moreText;
        
        // 테스트 텍스트도 UTF-16 검증
        final safeTestText = _finalSafeText(testText);
        if (safeTestText.isEmpty) continue;
        
        final testPainter = TextPainter(
          text: TextSpan(text: safeTestText, style: textStyle),
          maxLines: maxLines,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: MediaQuery.of(context).size.width - 44);

        if (!testPainter.didExceedMaxLines) {
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
  }

  @override
  Widget build(BuildContext context) {
    // UTF-16 인코딩 문제 해결을 위한 안전한 텍스트 처리
    String _safeText(String? text) {
      if (text == null || text.isEmpty) return '';
      try {
        // 더 강력한 UTF-16 정리
        String cleaned = text;
        
        // 1단계: 기본적인 잘못된 문자 제거
        cleaned = cleaned.replaceAll(RegExp(r'[\uFFFD\u0000-\u001F\u007F-\u009F]'), '');
        
        // 2단계: UTF-16 유효성 검사 및 복구
        try {
          final bytes = text.codeUnits;
          final validChars = <int>[];
          
          for (int i = 0; i < bytes.length; i++) {
            final codeUnit = bytes[i];
            
            // 기본 평면 문자 (U+0000 ~ U+FFFF)
            if (codeUnit >= 0 && codeUnit <= 0xFFFF) {
              // 서로게이트 쌍 검사
              if (codeUnit >= 0xD800 && codeUnit <= 0xDBFF) {
                // 상위 서로게이트
                if (i + 1 < bytes.length) {
                  final nextCodeUnit = bytes[i + 1];
                  if (nextCodeUnit >= 0xDC00 && nextCodeUnit <= 0xDFFF) {
                    // 유효한 서로게이트 쌍
                    validChars.add(codeUnit);
                    validChars.add(nextCodeUnit);
                    i++; // 다음 문자 건너뛰기
                    continue;
                  }
                }
                // 잘못된 서로게이트 쌍은 건너뛰기
                continue;
              } else if (codeUnit >= 0xDC00 && codeUnit <= 0xDFFF) {
                // 단독 하위 서로게이트는 건너뛰기
                continue;
              } else {
                // 일반 문자
                validChars.add(codeUnit);
              }
            } else {
              // 이모지 등 기본 평면을 벗어나는 문자도 지원
              // UTF-16 서로게이트 쌍으로 처리
              if (codeUnit >= 0xD800 && codeUnit <= 0xDBFF) {
                // 상위 서로게이트
                if (i + 1 < bytes.length) {
                  final nextCodeUnit = bytes[i + 1];
                  if (nextCodeUnit >= 0xDC00 && nextCodeUnit <= 0xDFFF) {
                    // 유효한 서로게이트 쌍 (이모지 포함)
                    validChars.add(codeUnit);
                    validChars.add(nextCodeUnit);
                    i++; // 다음 문자 건너뛰기
                    continue;
                  }
                }
                // 잘못된 서로게이트 쌍은 건너뛰기
                continue;
              } else if (codeUnit >= 0xDC00 && codeUnit <= 0xDFFF) {
                // 단독 하위 서로게이트는 건너뛰기
                continue;
              } else {
                // 기타 문자는 건너뛰기
                continue;
              }
            }
          }
          
          // 유효한 문자들로 문자열 재구성
          cleaned = String.fromCharCodes(validChars);
        } catch (e) {
          debugPrint('⚠️ PostContent build UTF-16 복구 실패, 기본 정리 사용: $e');
        }
        
        // 3단계: 최종 정리
        cleaned = cleaned.trim();
        return cleaned.isEmpty ? '' : cleaned;
      } catch (e) {
        debugPrint('⚠️ PostContent build 텍스트 정리 실패: $text, 오류: $e');
        return '';
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
        return const SizedBox(height: 0);
      }
      return Text(
        safeContent,
        style: textStyle,
      );
    }

    return _shouldShowMoreButton
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
  }
}