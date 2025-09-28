import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class ImageSizeUtil {
  /// 네트워크 이미지의 크기를 가져옵니다
  static Future<Size?> getNetworkImageSize(String imageUrl) async {
    try {
      final completer = Completer<ui.Image>();
      final imageProvider = NetworkImage(imageUrl);
      
      final imageStream = imageProvider.resolve(const ImageConfiguration());
      late ImageStreamListener listener;
      
      listener = ImageStreamListener((ImageInfo info, bool synchronousCall) {
        completer.complete(info.image);
        imageStream.removeListener(listener);
      }, onError: (exception, stackTrace) {
        completer.completeError(exception);
        imageStream.removeListener(listener);
      });
      
      imageStream.addListener(listener);
      
      final ui.Image image = await completer.future;
      return Size(image.width.toDouble(), image.height.toDouble());
    } catch (e) {
      debugPrint('이미지 크기 가져오기 실패: $e');
      return null;
    }
  }
  
  /// 이미지 크기 기반으로 컨테이너 크기 계산
  static Size calculateContainerSize({
    required Size imageSize,
    required double maxWidth,
    double? maxHeight,
  }) {
    double width = imageSize.width;
    double height = imageSize.height;
    
    // 너비가 최대 너비를 초과하면 비율에 맞게 축소
    if (width > maxWidth) {
      final ratio = maxWidth / width;
      width = maxWidth;
      height = height * ratio;
    }
    
    // 최대 높이가 지정되어 있고 초과하면 비율에 맞게 축소
    if (maxHeight != null && height > maxHeight) {
      final ratio = maxHeight / height;
      height = maxHeight;
      width = width * ratio;
    }
    
    return Size(width, height);
  }
}