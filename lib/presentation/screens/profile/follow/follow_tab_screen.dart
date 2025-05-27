import 'package:flutter/material.dart';
import 'package:logue/core/themes/app_colors.dart';
import 'package:logue/domain/entities/follow_list_type.dart';
import 'follow_list_tab.dart';

class FollowTabScreen extends StatefulWidget {
  final String userId;
  final String username;
  final int initialTabIndex;
  final int followerCount;
  final int followingCount;

  const FollowTabScreen({
    super.key,
    required this.userId,
    required this.username,
    required this.initialTabIndex,
    required this.followerCount,
    required this.followingCount,
  });

  @override
  State<FollowTabScreen> createState() => _FollowTabScreenState();
}

class _FollowTabScreenState extends State<FollowTabScreen> {
  late int currentIndex;

  @override
  void initState() {
    super.initState();
    currentIndex = widget.initialTabIndex;
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
                _buildTab('팔로워', widget.followerCount, 0),
                _buildTab('팔로잉', widget.followingCount, 1),
              ],
            ),
          ),
        ),
      ),
      body: IndexedStack(
        index: currentIndex,
        children: [
          FollowListTab(type: FollowListType.followers, userId: widget.userId),
          FollowListTab(type: FollowListType.followings, userId: widget.userId),
        ],
      ),
    );
  }

  Widget _buildTab(String label, int count, int index) {
    final isSelected = currentIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => currentIndex = index),
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Container(
              height: 48,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppColors.black500, width: 1), // 기본 연한 밑줄
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
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 2,
                  color: AppColors.black900,
                ),
              ),
          ],
        ),
      ),
    );
  }
}