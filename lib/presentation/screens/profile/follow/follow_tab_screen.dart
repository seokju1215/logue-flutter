import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:my_logue/core/themes/app_colors.dart';
import 'package:my_logue/domain/entities/follow_list_type.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'follow_list_tab.dart';
import '../../../../core/providers/follow_state_provider.dart';

class FollowTabScreen extends ConsumerStatefulWidget {
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
  ConsumerState<FollowTabScreen> createState() => _FollowTabScreenState();
}

class _FollowTabScreenState extends ConsumerState<FollowTabScreen> {
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

  // Provider 기반으로 팔로잉/팔로워 수 자동 갱신
  void _updateCounts() {
    final client = Supabase.instance.client;
    
    // 실시간으로 카운트 갱신
    client
        .from('follows')
        .select('id')
        .eq('following_id', widget.userId)
        .then((followerRes) {
          client
              .from('follows')
              .select('id')
              .eq('follower_id', widget.userId)
              .then((followingRes) {
                if (mounted) {
                  setState(() {
                    _followerCount = followerRes.length;
                    _followingCount = followingRes.length;
                  });
                }
              });
        });
  }

  @override
  Widget build(BuildContext context) {
    // Provider 상태 변화 감지하여 카운트 자동 갱신
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateCounts();
    });

    // Provider 상태 변화를 감지하여 모든 탭 자동 갱신
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId != null) {
      // Provider 상태 변화를 감지
      ref.watch(followStateProvider(currentUserId));
    }

    return WillPopScope(
      onWillPop: () async {
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: Text(
            widget.username,
            style: const TextStyle(color: AppColors.black900, fontSize: 16),
          ),
          leading: IconButton(
            icon: SvgPicture.asset('assets/back_arrow.svg'),
            onPressed: () {
              Navigator.pop(context);
            },
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
              onChangedCount: _updateCounts, // Provider 기반 갱신
            ),
            FollowListTab(
              type: FollowListType.followings,
              userId: widget.userId,
              isMyProfile: widget.isMyProfile,
              onChangedCount: _updateCounts, // Provider 기반 갱신
            ),
          ],
        ),
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