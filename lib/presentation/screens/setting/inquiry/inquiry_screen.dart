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
  late PageController _pageController;
  int currentIndex = 0;
  int _completedCount = 0;
  int _requestCount = 0;
  late InquiryRepository _repository;
  List<InquiryListModel> _completedInquiries = [];
  List<InquiryListModel> _pendingInquiries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: currentIndex);
    _initializeRepository();
    _loadInquiries();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _initializeRepository() {
    final client = Supabase.instance.client;
    final api = InquiryApi(client);
    _repository = InquiryRepository(api);
  }

  Future<void> _loadInquiries() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final completedInquiries = await _repository.getCompletedInquiries();
      final pendingInquiries = await _repository.getPendingInquiries();

      setState(() {
        _completedInquiries = completedInquiries;
        _pendingInquiries = pendingInquiries;
        _completedCount = completedInquiries.length;
        _requestCount = pendingInquiries.length;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading inquiries: $e');
      setState(() {
        _isLoading = false;
      });
    }
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
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : PageView(
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
    return _buildInquiryList(_completedInquiries);
  }

  Widget _buildRequestTab() {
    return _buildInquiryList(_pendingInquiries);
  }

  Widget _buildInquiryList(List<InquiryListModel> inquiries) {
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
          userId: inquiry.username,
          request: inquiry.title,
          details: inquiry.content,
          date: inquiry.formattedDate,
          status: 'completed',
        );
      },
    );
  }
}
