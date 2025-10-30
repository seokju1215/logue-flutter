import 'package:flutter/material.dart';
import 'package:my_logue/core/themes/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../data/utils/firebase_analytics_util.dart';

class BannerSlider extends StatefulWidget {
  final List<Map<String, dynamic>> banners;
  const BannerSlider({super.key, required this.banners});

  @override
  State<BannerSlider> createState() => _BannerSliderState();
}

class _BannerSliderState extends State<BannerSlider> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  void _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bannerHeight = (screenWidth * 210) / 393; // 393:210 비율 유지
    
    return Column(
      children: [
        SizedBox(
          height: bannerHeight,
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.banners.length,
            onPageChanged: (index) {
              setState(() => _currentPage = index);
            },
            itemBuilder: (context, index) {
              final banner = widget.banners[index];
              return GestureDetector(
                onTap: () async {
                  final url = banner['target_url'] as String?;
                  
                  // Firebase Analytics 이벤트 전송
                  try {
                    final bannerId = banner['id']?.toString() ?? 'unknown';
                    final bannerTitle = banner['title'] as String?;
                    final bannerType = banner['type'] as String? ?? 'promotion';
                    
                    debugPrint('🚀🚀🚀 홈에서 배너 클릭 이벤트 전송 시도');
                    await FirebaseAnalyticsUtil.logBannerClick(
                      bannerId: bannerId,
                      bannerType: bannerType,
                      sourceScreen: 'home_recommend_tab',
                      bannerTitle: bannerTitle,
                      bannerUrl: url,
                      position: 'top',
                    );
                    debugPrint('🎯🎯🎯 홈에서 배너 클릭 이벤트 전송 완료');
                  } catch (analyticsError) {
                    debugPrint('❌ 배너 클릭 이벤트 전송 실패: $analyticsError');
                  }
                  
                  if (url != null) _launchURL(url);
                },
                child: Image.network(
                  banner['image_url'],
                  fit: BoxFit.cover,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.banners.length, (index) {
            final isSelected = _currentPage == index;
            return Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppColors.black900 : AppColors.white500,
                border: Border.all(color: AppColors.black500),
              ),
            );
          }),
        ),
      ],
    );
  }
}