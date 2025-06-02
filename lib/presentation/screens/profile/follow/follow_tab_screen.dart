import 'package:flutter/material.dart';
import 'package:logue/core/themes/app_colors.dart';
import 'package:logue/domain/entities/follow_list_type.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'follow_list_tab.dart';

class FollowTabScreen extends StatefulWidget {
  final String userId;
  final String username;
  final int initialTabIndex;
  final int followerCount;
  final int followingCount;
  final bool isMyProfile;


  const FollowTabScreen({
    super.key,
    required this.userId,
    required this.username,
    required this.initialTabIndex,
    required this.followerCount,
    required this.followingCount,
    required this.isMyProfile,
  });

  @override
  State<FollowTabScreen> createState() => _FollowTabScreenState();
}

class _FollowTabScreenState extends State<FollowTabScreen> {
  late int currentIndex;
  late PageController _pageController;
  int _followerCount = 0;
  int _followingCount = 0;
  @override
  void initState() {
    super.initState();
    currentIndex = widget.initialTabIndex;
    _pageController = PageController(initialPage: currentIndex);
    _followerCount = widget.followerCount;
    _followingCount = widget.followingCount;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.username,
          style: const TextStyle(color: AppColors.black900, fontSize: 16),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Material(
            color: Colors.white,
            child: Row(
              children: [
                _buildTab('팔로워', _followerCount, 0),
                _buildTab('팔로잉', _followingCount, 1),
              ],
            ),
          ),
        ),
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            currentIndex = index;
          });
        },
        children: [
          FollowListTab(
            type: FollowListType.followers,
            userId: widget.userId,
            isMyProfile: widget.isMyProfile,
            onChangedCount: _refreshCounts,
          ),
          FollowListTab(
            type: FollowListType.followings,
            userId: widget.userId,
            isMyProfile: widget.isMyProfile,
            onChangedCount: _refreshCounts,
          ),
        ],
      ),
    );
  }
  Future<void> _refreshCounts() async {
    final res = await Supabase.instance.client
        .from('profiles')
        .select('followers, following')
        .eq('id', widget.userId)
        .maybeSingle();

    if (res != null) {
      setState(() {
        _followerCount = res['followers'] ?? 0;
        _followingCount = res['following'] ?? 0;
      });
    }
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
              height: 48,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppColors.black500, width: 1),
                ),
              ),
              child: Text(
                '$label $count명',
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
}