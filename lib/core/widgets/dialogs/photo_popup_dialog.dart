import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:my_logue/core/themes/app_colors.dart';
import 'package:my_logue/data/models/photo_popup_model.dart';
import 'package:my_logue/data/utils/image_size_util.dart';
import 'package:my_logue/presentation/screens/webview_screen.dart';

class PhotoPopupDialog extends StatefulWidget {
  final PhotoPopupModel photoPopup;

  const PhotoPopupDialog({
    super.key,
    required this.photoPopup,
  });

  @override
  State<PhotoPopupDialog> createState() => _PhotoPopupDialogState();
}

class _PhotoPopupDialogState extends State<PhotoPopupDialog> with TickerProviderStateMixin {
  Size? _imageSize;
  bool _isImageLoaded = false;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));
    _loadImageSize();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadImageSize() async {
    final size = await ImageSizeUtil.getNetworkImageSize(widget.photoPopup.photoUrl);
    if (mounted) {
      setState(() {
        _imageSize = size;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: Stack(
        children: [
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(color: Colors.black.withOpacity(0.3)),
            ),
          ),
          Center(
            child: GestureDetector(
              onTap: () {},
              child: Stack(
                children: [
                  Container(
                    width: MediaQuery.of(context).size.width * 0.9,
                    constraints: const BoxConstraints(maxWidth: 400),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 제목 및 설명 섹션 (있는 경우)
                        if (widget.photoPopup.title != null || widget.photoPopup.description != null)
                          _buildHeaderSection(context),
                        // 사진 섹션
                        _buildPhotoSection(context),
                        // 하단 버튼 섹션
                        _buildBottomSection(context),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.photoPopup.title != null) ...[
            Text(
              widget.photoPopup.title!,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.black900,
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (widget.photoPopup.description != null) ...[
            Text(
              widget.photoPopup.description!,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.black500,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildPhotoSection(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final popupWidth = screenWidth * 0.9;
    final maxPopupWidth = 400.0;
    final actualPopupWidth = popupWidth > maxPopupWidth ? maxPopupWidth : popupWidth;
    
    // 좌우 여백 고정
    final photoWidth = actualPopupWidth;
    
    // 이미지 크기가 로드되었으면 실제 비율로 계산, 아니면 기본값 사용
    double photoHeight = photoWidth; // 기본값 (정사각형)
    if (_imageSize != null) {
      final containerSize = ImageSizeUtil.calculateContainerSize(
        imageSize: _imageSize!,
        maxWidth: photoWidth,
      );
      photoHeight = containerSize.height;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 0),
      child: GestureDetector(
        onTap: () => _onPhotoTap(context),
        child: Container(
          width: photoWidth,
          height: photoHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(0),
              bottomRight: Radius.circular(0),
              topLeft: Radius.circular(10),
              topRight: Radius.circular(10),
            ),
            color: AppColors.black100,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(0),
              bottomRight: Radius.circular(0),
              topLeft: Radius.circular(10),
              topRight: Radius.circular(10),
            ),
            child: Stack(
              children: [
                // 실제 이미지 (페이드 애니메이션 적용)
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Image.network(
                    widget.photoPopup.photoUrl,
                    width: photoWidth,
                    height: photoHeight,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) {
                        // 이미지 로딩 완료
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted && !_isImageLoaded) {
                            setState(() {
                              _isImageLoaded = true;
                            });
                            _fadeController.forward();
                          }
                        });
                        return child;
                      }
                      // 로딩 중일 때는 투명하게 처리 (오버레이가 표시됨)
                      return const SizedBox.shrink();
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: photoWidth,
                        height: photoHeight,
                        color: AppColors.black100,
                        child: const Icon(
                          Icons.image_not_supported,
                          color: AppColors.black500,
                          size: 48,
                        ),
                      );
                    },
                  ),
                ),
                // 로딩 오버레이 (이미지가 로드되지 않았을 때만)
                if (!_isImageLoaded)
                  Container(
                    width: photoWidth,
                    height: photoHeight,
                    color: AppColors.black100,
                    child: const Center(
                      child: SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: AppColors.black500,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomSection(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.only(left: 13, right: 7),
      child: Row(
        children: [
          // 오늘 하루 보지 않기 텍스트 버튼 (왼쪽)
          GestureDetector(
            onTap: () => _onDontShowToday(context),
            child: const Text(
              '오늘 하루 보지 않기',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: AppColors.black900,
                decoration: TextDecoration.none,
              ),
            ),
          ),
          const Spacer(), // 공간을 최대한 확장
          // X 버튼 (오른쪽 끝)
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(
              Icons.close,
              size: 22,
              color: AppColors.black900,
            ),
          ),
        ],
      ),
    );
  }

  void _onPhotoTap(BuildContext context) async {
    debugPrint('🖼️ 사진 클릭됨!');
    debugPrint('🖼️ 링크: ${widget.photoPopup.link}');
    
    if (widget.photoPopup.link != null && widget.photoPopup.link!.isNotEmpty) {
      try {
        final url = widget.photoPopup.link!;
        debugPrint('🖼️ WebViewScreen으로 이동: $url');
        
        // WebViewScreen으로 네비게이션 (팝업은 그대로 유지)
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => WebViewScreen(
              url: url,
              title: widget.photoPopup.title,
            ),
          ),
        );
        
        debugPrint('🖼️ WebViewScreen에서 돌아옴 - 팝업은 유지');
        // 웹뷰 화면에서 돌아와도 팝업은 그대로 유지
      } catch (e) {
        debugPrint('❌ WebViewScreen 열기 실패: $e');
      }
    } else {
      debugPrint('⚠️ 링크가 없음 또는 비어있음');
    }
  }

  void _onDontShowToday(BuildContext context) {
    // 오늘 하루 보지 않기 로직은 서비스에서 처리
    Navigator.pop(context, 'dont_show_today');
  }
}