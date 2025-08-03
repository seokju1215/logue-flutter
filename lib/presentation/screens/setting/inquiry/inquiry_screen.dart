import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:my_logue/core/widgets/common/common_outlined_button.dart';
import 'package:my_logue/core/widgets/inquiry/inquiry_card.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../data/models/inquiry_models.dart';
import '../../../../data/repositories/inquiry_repository.dart';
import '../../../../data/datasources/inquiry_api.dart';

class InquiryScreen extends StatefulWidget {
  const InquiryScreen({Key? key}) : super(key: key);

  @override
  State<InquiryScreen> createState() => _InquiryScreenState();
}

class _InquiryScreenState extends State<InquiryScreen> {
  late Future<List<Map<String, dynamic>>> _futureInquiries;
  late PageController _pageController;
  int currentIndex = 0;
  int _completedCount = 485;
  int _requestCount = 41;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: currentIndex);
    _loadInquiries();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _loadInquiries() {
    final client = Supabase.instance.client;
    final currentUser = client.auth.currentUser;

    if (currentUser == null) {
      // 사용자가 로그인하지 않은 경우 처리
      setState(() {
        _futureInquiries = Future.value([]);
      });
      return;
    }

    final userId = currentUser.id;
    final api = InquiryApi(client);
    final repository = InquiryRepository(api);

    setState(() {
      _futureInquiries = repository.getInquiries(userId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          '고객센터 / 소통',
          style: TextStyle(
            fontSize: 16,
            color: AppColors.black900,
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: SvgPicture.asset('assets/back_arrow.svg'),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 22, top: 11),
            child: Text(
              '앱 내에 없는 책, 원하시는 기능이나 콘텐츠\n오류나 악성유저 등이 있다면 언제든 알려주세요!',
              style: TextStyle(fontSize: 16, color: AppColors.black900),
            ),
          ),
          const SizedBox(
            height: 15,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 22),
            child: Row(
              children: [
                const Expanded(child: SizedBox()),
                Expanded(
                  child: CommonOutlinedButton(
                      text: "고객센터",
                      onTap: () {
                        Navigator.of(context, rootNavigator: true).push(
                          MaterialPageRoute(
                            builder: (_) => InquiryScreen(),
                          ),
                        );
                      }),
                )
              ],
            ),
          ),
          const SizedBox(height: 17),
          // 탭바 추가
          Material(
            color: Colors.white,
            child: Row(
              children: [
                _buildTab('책 추가 완료', _completedCount, 0),
                _buildTab('책 추가 요청', _requestCount, 1),
              ],
            ),
          ),
          // 탭뷰 추가
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  currentIndex = index;
                });
              },
              children: [
                _buildCompletedTab(),
                _buildRequestTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String label, int count, int index) {
    final isSelected = currentIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
          );
        },
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Container(
              height: 30,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppColors.black500, width: 1),
                ),
              ),
              child: Text(
                '$label($count)',
                style: TextStyle(
                  color: isSelected ? AppColors.black900 : AppColors.black500,
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            if (isSelected)
              const Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Divider(
                  thickness: 2,
                  height: 0,
                  color: AppColors.black900,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedTab() {
    return _buildInquiryList(_getCompletedInquiries());
  }

  Widget _buildRequestTab() {
    return _buildInquiryList(_getRequestInquiries());
  }

  List<Map<String, dynamic>> _getCompletedInquiries() {
    // 임시 데이터 - 실제로는 API에서 가져와야 함
    return [
      {
        'user_id': 'seo_yeon21',
        'request': '민음사 북클럽에서 나온 도서들 요청드립니다.',
        'details': '빛이 나지 않아요 경주는 왜냐하면 본드가의 댈러웨이 부인 보이지....',
        'date': '2025/07/28',
        'status': 'completed'
      },
      {
        'user_id': 'seo_yeon21',
        'request': '전국불효자랑 도서 추가',
        'details': '추가 부탁드립니다.',
        'date': '2025/07/28',
        'status': 'completed'
      },
      {
        'user_id': 'seo_yeon21',
        'request': '없는 도서 추가 요청합니다',
        'details': '이집트 신화의 신비로운 여정 ISBN 9791173195792 추가요청입니다.',
        'date': '2025/07/28',
        'status': 'completed'
      },
    ];
  }

  List<Map<String, dynamic>> _getRequestInquiries() {
    // 임시 데이터 - 실제로는 API에서 가져와야 함
    return [
      {
        'user_id': 'seo_yeon21',
        'request': '넷플릭스하다',
        'details': '추가해주세요',
        'date': '2025/07/28',
        'status': 'pending'
      },
      {
        'user_id': 'seo_yeon21',
        'request': '너머의 아이들',
        'details': '천선란 단편소설',
        'date': '2025/07/28',
        'status': 'pending'
      },
      {
        'user_id': 'seo_yeon21',
        'request': '기억의 기억들 도서 추가 부탁드립니다',
        'details': '추가 부탁드립니다.',
        'date': '2025/07/28',
        'status': 'pending'
      },
    ];
  }

  Widget _buildInquiryList(List<Map<String, dynamic>> inquiries) {
    if (inquiries.isEmpty) {
      return const Center(
        child: Text(
          '요청이 없습니다.',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.black500,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: inquiries.length,
      itemBuilder: (context, index) {
        final inquiry = inquiries[index];
        return InquiryCard(
          userId: inquiry['user_id'] ?? '',
          request: inquiry['request'] ?? '',
          details: inquiry['details'],
          date: inquiry['date'] ?? '',
          status: inquiry['status'] ?? '',
        );
      },
    );
  }
}
