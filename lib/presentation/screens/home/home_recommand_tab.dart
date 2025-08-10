import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:my_logue/core/themes/app_colors.dart';
import 'package:my_logue/core/themes/stroke_text_style.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_logue/core/widgets/post/post_item.dart';
import 'package:my_logue/core/widgets/follow/follow_user_tile.dart';
import '../../../data/models/book_post_model.dart';
import '../../../data/repositories/user_repository.dart';
import '../profile/other_profile_screen.dart';
import '../../../core/providers/follow_state_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'users_with_same_books_screen.dart';

class HomeRecommendTab extends ConsumerStatefulWidget {
  const HomeRecommendTab({super.key});

  @override
  ConsumerState<HomeRecommendTab> createState() => _HomeRecommendTabState();
}

class _HomeRecommendTabState extends ConsumerState<HomeRecommendTab> {
  final client = Supabase.instance.client;
  List<Map<String, dynamic>> usersWithSameBooks = [];
  List<Map<String, dynamic>> recentActiveUsers = [];
  bool isLoading = true;
  bool isLoadingUsers = true;

  @override
  void initState() {
    super.initState();
    _fetchUsersWithSameBooks();
    _fetchRecentActiveUsers();
  }

  Future<void> _fetchUsersWithSameBooks() async {
    try {
      final userRepository = UserRepository(client);
      final users = await userRepository.getUsersWithSameBooks();
      
      if (mounted) {
        // 팔로우한 사람들을 먼저, 팔로우하지 않은 사람들을 나중에 정렬
        final sortedUsers = await _sortUsersByFollowStatus(users);
        
        setState(() {
          usersWithSameBooks = sortedUsers;
          isLoading = false;
        });
      }
    } catch (e) {
      print('❌ 인생책이 겹치는 사람 조회 실패: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<List<Map<String, dynamic>>> _sortUsersByFollowStatus(List<Map<String, dynamic>> users) async {
    final currentUserId = client.auth.currentUser?.id;
    if (currentUserId == null) return users;

    // 각 사용자의 팔로우 상태를 확인
    final List<Map<String, dynamic>> sortedUsers = [];
    final List<Map<String, dynamic>> followingUsers = [];
    final List<Map<String, dynamic>> nonFollowingUsers = [];

    for (final user in users) {
      final userId = user['user_id'];
      if (userId == currentUserId) continue; // 자기 자신은 제외

      // 팔로우 상태 확인
      final isFollowing = await _checkFollowStatus(userId);
      
      if (isFollowing) {
        followingUsers.add(user);
      } else {
        nonFollowingUsers.add(user);
      }
    }

    // 팔로우한 사람들을 먼저, 팔로우하지 않은 사람들을 나중에
    sortedUsers.addAll(followingUsers);
    sortedUsers.addAll(nonFollowingUsers);

    return sortedUsers;
  }

  Future<void> _fetchRecentActiveUsers() async {
    try {
      final userRepository = UserRepository(client);
      final users = await userRepository.getRecentActiveUsers();
      
      if (mounted) {
        setState(() {
          recentActiveUsers = users;
          isLoadingUsers = false;
        });
      }
    } catch (e) {
      print('❌ 최근 활성 유저 조회 실패: $e');
      if (mounted) {
        setState(() {
          isLoadingUsers = false;
        });
      }
    }
  }

  Future<bool> _checkFollowStatus(String targetUserId) async {
    try {
      final currentUserId = client.auth.currentUser?.id;
      if (currentUserId == null) return false;
      
      final response = await client
          .from('follows')
          .select('id')
          .eq('follower_id', currentUserId)
          .eq('following_id', targetUserId)
          .single();
      
      return response != null;
    } catch (e) {
      return false;
    }
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
    return SingleChildScrollView(
      primary: false,
      padding: const EdgeInsets.fromLTRB(0, 27, 0, 27),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 22),
            child: StrokeTextStyle.createStrokeText(text: '내 지인 중에서 LOGUE 유저 찾아보기', fontSize: 16 , color: AppColors.black900, fontWeight: FontWeight.w400, height: 1.187)
          ),
          const SizedBox(height: 13),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 21),
            child: Row(
              children: [
                const Expanded(child: SizedBox()),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {

                    },
                    style: _outlinedStyle(context),
                    child: const Text(
                      '친구 찾기',
                      style: TextStyle(fontSize: 13, color: AppColors.black900, height: 1.25),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 35),
          if (isLoading)
            const Center(child: CircularProgressIndicator())
          else if (usersWithSameBooks.isEmpty)
            const Padding(
              padding: EdgeInsets.only(left: 22),
              child: Text(
                '아직 인생책이 겹치는 사람이 없어요.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.black500,
                ),
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      StrokeTextStyle.createStrokeText(text: "나와 인생책이 겹치는 친구", fontSize: 16, fontWeight: FontWeight.w400, color: AppColors.black900, height: 1.187),
                      Text(
                        '${usersWithSameBooks.length}명',
                        style: const TextStyle(
                          fontSize: 16,
                          color: AppColors.black500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
                Column(
                  children: usersWithSameBooks.take(3).map((user) {
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
                  }).toList(),
                ),
                SizedBox(
                  height: 31,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (usersWithSameBooks.length > 3)
                        Center(
                          child: TextButton(
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => UsersWithSameBooksScreen(
                                    users: usersWithSameBooks,
                                  ),
                                ),
                              );
                              setState(() {}); // Provider 상태로만 UI 갱신
                            },
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              "더보기",
                              style: TextStyle(
                                color: AppColors.black900,
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                height: 1.0
                              ),
                            ),
                          ),
                        ),
                     usersWithSameBooks.length <= 3? const SizedBox(height: 31) : SizedBox(height: 10),
                      const Divider(height: 1, color: AppColors.black300),
                    ],
                  ),
                ),
              ],
            ),
          // 최근 활성 유저 섹션
          const SizedBox(height: 35),
          Padding(
            padding: const EdgeInsets.only(left: 22),
            child: StrokeTextStyle.createStrokeText(
              text: '최근 활동 친구',
              fontSize: 16,
              color: AppColors.black900,
              fontWeight: FontWeight.w400,
              height: 1.187,
            ),
          ),
          SizedBox(height: 16,),
          if (isLoadingUsers)
            const Center(child: CircularProgressIndicator())
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 0),
                Column(
                  children: recentActiveUsers.take(50).map((user) {
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
                  }).toList(),
                ),
                const SizedBox(height: 40),
              ],
            ),
        ],
      ),
    );
  }
}