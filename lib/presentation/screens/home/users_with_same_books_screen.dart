import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:my_logue/core/themes/app_colors.dart';
import 'package:my_logue/core/widgets/follow/follow_user_tile.dart';
import 'package:my_logue/presentation/screens/profile/other_profile_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/providers/follow_state_provider.dart';

class UsersWithSameBooksScreen extends ConsumerStatefulWidget {
  final List<Map<String, dynamic>> users;

  const UsersWithSameBooksScreen({
    super.key,
    required this.users,
  });

  @override
  ConsumerState<UsersWithSameBooksScreen> createState() => _UsersWithSameBooksScreenState();
}

class _UsersWithSameBooksScreenState extends ConsumerState<UsersWithSameBooksScreen> {
  late List<Map<String, dynamic>> sortedUsers;
  final client = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    sortedUsers = _sortUsers(widget.users);
  }

  List<Map<String, dynamic>> _sortUsers(List<Map<String, dynamic>> users) {
    final currentUserId = client.auth.currentUser?.id;
    if (currentUserId == null) return users;

    final sortedUsers = users.map((user) {
      final isFollowing = ref.read(followStateProvider(user['user_id']));
      return Map<String, dynamic>.from({
        ...user,
        'isFollowing': isFollowing,
      });
    }).toList();

    sortedUsers.sort((a, b) {
      // 내 프로필이 최상단
      if (a['user_id'] == currentUserId) return -1;
      if (b['user_id'] == currentUserId) return 1;

      // 팔로우한 사람이 위로
      if (a['isFollowing'] == true && b['isFollowing'] != true) return -1;
      if (a['isFollowing'] != true && b['isFollowing'] == true) return 1;

      // 겹치는 책 수로 정렬 (내림차순)
      final aCount = a['overlap_count'] ?? 0;
      final bCount = b['overlap_count'] ?? 0;
      return bCount.compareTo(aCount);
    });

    return sortedUsers;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: SvgPicture.asset('assets/back_arrow.svg'),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '나와 인생책이 겹치는 친구',
          style: TextStyle(
            color: AppColors.black900,
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: sortedUsers.length,
              itemBuilder: (context, index) {
                final user = sortedUsers[index];
                final isFollowing = ref.watch(followStateProvider(user['user_id']));
                
                return FollowUserTile(
                  currentUserId: client.auth.currentUser?.id ?? '',
                  userId: user['user_id'],
                  username: user['username'] ?? '',
                  name: user['name'] ?? '',
                  avatarUrl: user['avatar_url'] ?? 'basic',
                  isMyProfile: false,
                  onTapFollow: () async {
                    final followNotifier = ref.read(followStateProvider(user['user_id']).notifier);
                    followNotifier.optimisticFollow();
                    try {
                      await followNotifier.follow();
                    } catch (e) {
                      followNotifier.optimisticUnfollow();
                    }
                  },
                  onTapUnfollow: () async {
                    final followNotifier = ref.read(followStateProvider(user['user_id']).notifier);
                    followNotifier.optimisticUnfollow();
                    try {
                      await followNotifier.unfollow();
                    } catch (e) {
                      followNotifier.optimisticFollow();
                    }
                  },
                  onTapProfile: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OtherProfileScreen(userId: user['user_id']),
                      ),
                    );
                  },
                  isFollowing: isFollowing,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
} 