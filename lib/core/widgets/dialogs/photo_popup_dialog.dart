import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:my_logue/core/themes/app_colors.dart';
import 'package:my_logue/data/models/photo_popup_model.dart';

class PhotoPopupDialog extends StatelessWidget {
  final PhotoPopupModel photoPopup;
  final String? linkUrl; // 클릭 시 이동할 링크 URL

  const PhotoPopupDialog({
    super.key,
    required this.photoPopup,
    this.linkUrl,
  });

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
                        if (photoPopup.title != null || photoPopup.description != null)
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
          if (photoPopup.title != null) ...[
            Text(
              photoPopup.title!,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.black900,
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (photoPopup.description != null) ...[
            Text(
              photoPopup.description!,
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

    // 좌우 여백 고정 (20px * 2)
    final photoWidth = actualPopupWidth;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 0),
      child: GestureDetector(
        onTap: () => _onPhotoTap(context),
        child: Container(
          width: photoWidth,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: AppColors.black100,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(0),
              bottomRight: Radius.circular(0),
              topLeft: Radius.circular(10),
              topRight: Radius.circular(10),
            ),
            child: Image.network(
              photoPopup.photoUrl,
              width: photoWidth,
              fit: BoxFit.contain, // 원본 비율 유지하면서 컨테이너에 맞춤
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: photoWidth, // 에러 시 정사각형으로 표시
                  color: AppColors.black100,
                  child: const Icon(
                    Icons.image_not_supported,
                    color: AppColors.black500,
                    size: 48,
                  ),
                );
              },
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  height: photoWidth, // 로딩 시 정사각형으로 표시
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
                );
              },
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
    if (linkUrl != null && linkUrl!.isNotEmpty) {
      final uri = Uri.parse(linkUrl!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  void _onDontShowToday(BuildContext context) {
    // 오늘 하루 보지 않기 로직은 서비스에서 처리
    Navigator.pop(context, 'dont_show_today');
  }
}