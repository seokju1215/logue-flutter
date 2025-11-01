import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:my_logue/core/themes/app_colors.dart';

class BookFrame extends StatelessWidget {
  final String imageUrl;

  const BookFrame({Key? key, required this.imageUrl}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) return _errorBox();

    // 우선 https 시도
    final primaryUrl = imageUrl.startsWith('http://')
        ? imageUrl.replaceFirst('http://', 'https://')
        : imageUrl;

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.black300, width: 0.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final dpr = MediaQuery.of(context).devicePixelRatio;
            // 썸네일 해상도에 맞게 캐시 사이즈 제한 (메모리/디코딩 안정화)
            final targetW =
            (constraints.maxWidth * dpr).clamp(100, 1024).round();
            final targetH =
            (constraints.maxHeight * dpr).clamp(100, 1024).round();

            return CachedNetworkImage(
              key: ValueKey(primaryUrl), // 스테일 이미지 방지
              imageUrl: primaryUrl,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,

              // 성능/안정화 포인트
              memCacheWidth: targetW,
              memCacheHeight: targetH,
              maxWidthDiskCache: targetW,
              maxHeightDiskCache: targetH,
              fadeInDuration: Duration.zero,
              fadeOutDuration: Duration.zero,
              // gaplessPlayback: true, // 필요하면 주석 해제

              placeholder: (_, __) => _placeholderBox(),
              errorWidget: (_, __, ___) {
                // https 실패 시 http로 한 번 더 폴백
                if (primaryUrl.startsWith('https://')) {
                  final httpUrl = primaryUrl.replaceFirst('https://', 'http://');
                  return CachedNetworkImage(
                    key: ValueKey(httpUrl),
                    imageUrl: httpUrl,
                    fit: BoxFit.cover,
                    memCacheWidth: targetW,
                    memCacheHeight: targetH,
                    maxWidthDiskCache: targetW,
                    maxHeightDiskCache: targetH,
                    fadeInDuration: Duration.zero,
                    fadeOutDuration: Duration.zero,
                    placeholder: (_, __) => _placeholderBox(),
                    errorWidget: (_, __, ___) => _errorBox(),
                  );
                }
                return _errorBox();
              },
            );
          },
        ),
      ),
    );
  }

  Widget _placeholderBox() => Container(
    color: Colors.grey[200],
    child: const Center(
      child: SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.black500,
        ),
      ),
    ),
  );
  Widget _errorBox() =>
      Container(color: Colors.grey[300], child: const Icon(Icons.broken_image));
}