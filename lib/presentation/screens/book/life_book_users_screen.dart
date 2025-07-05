import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:logue/core/themes/app_colors.dart';
import 'package:logue/core/widgets/follow/follow_user_tile.dart';
import 'package:logue/presentation/screens/profile/other_profile_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/follow_state_provider.dart';

class LifebookUsersScreen extends ConsumerStatefulWidget {
  final List<Map<String, dynamic>> users;

  const LifebookUsersScreen({super.key, required this.users});

  @override
  ConsumerState<LifebookUsersScreen> createState() => _LifebookUsersScreenState();
}

class _LifebookUsersScreenState extends ConsumerState<LifebookUsersScreen> {
  late List<Map<String, dynamic>> lifebookUsers;
  late String currentUserId;

  @override
  void initState() {
    super.initState();
    currentUserId = Supabase.instance.client.auth.currentUser?.id ?? '';
    lifebookUsers = _sortUsers(widget.users);
  }

  List<Map<String, dynamic>> _sortUsers(List<Map<String, dynamic>> users) {
    final sorted = [...users];
    sorted.sort((a, b) {
      // 내 프로필이 최상단
      if (a['id'] == currentUserId) return -1;
      if (b['id'] == currentUserId) return 1;
      
      // 팔로우한 사람이 위로
      final aFollowing = ref.read(followStateProvider(a['id']));
      final bFollowing = ref.read(followStateProvider(b['id']));
      
      if (aFollowing && !bFollowing) return -1;
      if (!aFollowing && bFollowing) return 1;
      
      return 0;
    });
    return sorted;
  }

  Future<void> _handleFollow(String userId) async {
    final followNotifier = ref.read(followStateProvider(userId).notifier);
    followNotifier.optimisticFollow();
    try {
      await followNotifier.follow();
    } catch (e) {
      followNotifier.optimisticUnfollow();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('팔로우에 실패했어요. 다시 시도해 주세요.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Provider 상태 변화 감지
    for (final user in lifebookUsers) {
      ref.watch(followStateProvider(user['id']));
    }

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          title: const Text(
            '인생 책으로 설정한 사람',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.black900,
              fontWeight: FontWeight.w500,
            ),
          ),
          leading: IconButton(
            icon: SvgPicture.asset('assets/back_arrow.svg'),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ),
        backgroundColor: Colors.white,
        body: ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 0),
          itemCount: lifebookUsers.length,
          itemBuilder: (context, index) {
            final user = lifebookUsers[index];
            final isFollowing = ref.watch(followStateProvider(user['id']));
            return FollowUserTile(
              currentUserId: currentUserId,
              userId: user['id'],
              username: user['username'],
              name: user['name'],
              avatarUrl: user['avatar_url'] ?? 'basic',
              isMyProfile: false,
              isFollowing: isFollowing,
              onTapFollow: () async {
                await _handleFollow(user['id']);
              },
              onTapProfile: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OtherProfileScreen(userId: user['id']),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}