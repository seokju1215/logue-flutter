import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:my_logue/core/themes/app_colors.dart';
import 'package:my_logue/presentation/screens/add_book/search_book_screen.dart';
import 'package:my_logue/presentation/screens/main_navigation_screen.dart';
import 'package:reorderables/reorderables.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/widgets/book/book_frame.dart';
import '../../../core/widgets/dialogs/book_limit_dialog.dart';
import '../../../data/utils/mixpanel_util.dart';
import 'profile_tab.dart';
import 'archive_tab.dart';

class AddBookScreen extends StatefulWidget {
  final bool isLimitReached;
  const AddBookScreen({Key? key, required this.isLimitReached}) : super(key: key);

  @override
  State<AddBookScreen> createState() => _AddBookScreenState();
}

class _AddBookScreenState extends State<AddBookScreen> {
  late PageController _pageController;
  int _currentIndex = 0;
  String _profileTabKey = 'profile_${DateTime.now().millisecondsSinceEpoch}';
  String _archiveTabKey = 'archive_${DateTime.now().millisecondsSinceEpoch}';

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
    
    // 책 추가 화면 방문 트래킹
    MixpanelUtil.trackScreenView('Add Book');
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _refreshTabs() {
    setState(() {
      _profileTabKey = 'profile_${DateTime.now().millisecondsSinceEpoch}';
      _archiveTabKey = 'archive_${DateTime.now().millisecondsSinceEpoch}';
    });
  }

  ButtonStyle _outlinedStyle(BuildContext context) {
    return ButtonStyle(
      foregroundColor: MaterialStateProperty.all(AppColors.black900),
      backgroundColor: MaterialStateProperty.all(Colors.white),
      overlayColor: MaterialStateProperty.resolveWith<Color?>(
            (states) {
          if (states.contains(MaterialState.pressed)) {
            return AppColors.black100;
          }
          return null;
        },
      ),
      side: MaterialStateProperty.all(
        const BorderSide(color: AppColors.black500, width: 1),
      ),
      shape: MaterialStateProperty.all(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      padding: MaterialStateProperty.all(
        const EdgeInsets.symmetric(horizontal: 9),
      ),
      minimumSize: MaterialStateProperty.all(
        const Size(0, 34),
      ),
      textStyle: MaterialStateProperty.all(
        const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          height: 1.0,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pop(false);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: const Text('책 추가', style: TextStyle(color: AppColors.black900, fontSize: 16, fontWeight: FontWeight.w500)),
        ),
        body: Column(
          children: [
            // 탭바
            Container(
              color: Colors.white,
              child: Row(
                children: [
                  _buildTab('프로필', 0),
                  _buildTab('보관함', 1),
                ],
              ),
            ),
            // 탭뷰
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentIndex = index;
                  });
                },
                children: [
                  ProfileTab(
                    key: ValueKey(_profileTabKey),
                    isLimitReached: widget.isLimitReached,
                  ),
                  ArchiveTab(
                    key: ValueKey(_archiveTabKey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(String label, int index) {
    final isSelected = _currentIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          _pageController.animateToPage(index, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
          setState(() {
            _currentIndex = index;
          });
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
                label,
                style: TextStyle(
                  color: isSelected ? AppColors.black900 : AppColors.black500,
                  fontSize: 14,
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
}