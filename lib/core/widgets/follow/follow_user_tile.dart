import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_logue/core/themes/app_colors.dart';
import 'package:my_logue/domain/entities/follow_list_type.dart';

import '../../providers/follow_state_provider.dart';
import '../../../data/utils/mixpanel_util.dart';


class FollowUserTile extends ConsumerWidget {
  final String userId;
  final String username;
  final String name;
  final String avatarUrl;
  final bool isMyProfile;
  final FollowListType? tabType;
  final VoidCallback? onTapFollow;
  final VoidCallback? onTapUnfollow;
  final VoidCallback? onTapRemove;
  final VoidCallback? onTapProfile;
  final String currentUserId;
  final bool? isFollowing; // 로컬 상태를 우선 사용 (nullable)

  const FollowUserTile({
    super.key,
    required this.userId,
    required this.username,
    required this.name,
    required this.avatarUrl,
    required this.isMyProfile,
    required this.currentUserId,
    this.tabType,
    this.onTapFollow,
    this.onTapUnfollow,
    this.onTapRemove,
    this.onTapProfile,
    this.isFollowing,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 로컬 상태가 있으면 우선 사용, 없으면 Riverpod 상태 사용
    final followingState = isFollowing ?? ref.watch(followStateProvider(userId));
    final followNotifier = ref.read(followStateProvider(userId).notifier);

    final showFollowButton = () {
      if (userId == currentUserId) return false;
      if (!(followingState ?? false)) return true;
      return false;
    }();

    final showUnfollowButton = () {
      if (userId == currentUserId) return false;
      if (followingState ?? false) return true;
      return false;
    }();

    final showRemoveButton = isMyProfile && tabType == FollowListType.followers;

    return Padding(
      padding: showRemoveButton
          ? const EdgeInsets.fromLTRB(22, 8, 10, 8)
          : const EdgeInsets.fromLTRB(22, 8, 22, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: GestureDetector(
              onTap: onTapProfile,
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 27,
                    backgroundImage:
                    avatarUrl == 'basic' ? null : NetworkImage(avatarUrl),
                    child: avatarUrl == 'basic'
                        ? Image.asset('assets/basic_avatar.png')
                        : null,
                  ),
                  const SizedBox(width: 22),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(username,
                          style: const TextStyle(
                              fontSize: 14, color: AppColors.black900)),
                      Text(name,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.black500)),
                    ],
                  ),
                ],
              ),
            ),
          ),

          if (showFollowButton)
            OutlinedButton(
              onPressed: () {
                print('팔로우 버튼 클릭됨: userId = $userId');
                // 팔로우 트래킹
                MixpanelUtil.trackFollow(userId);
                // 부모 컴포넌트에서 처리하도록 콜백만 호출
                onTapFollow?.call();
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.black900, width: 1),
                padding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
                minimumSize: const Size(0, 0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              child: const Text(
                "팔로우",
                style: TextStyle(
                    fontSize: 12,
                    color: AppColors.black900,
                    fontWeight: FontWeight.w400),
              ),
            )
          else
            const SizedBox(height: 26),

          if (showRemoveButton)
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: onTapRemove,
            ),
        ],
      ),
    );
  }
}