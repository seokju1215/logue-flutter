import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:my_logue/core/themes/app_colors.dart';
import 'package:my_logue/core/themes/stroke_text_style.dart';
import 'package:my_logue/core/widgets/dialogs/contact_permission_dialog.dart';
import 'package:my_logue/presentation/screens/home/find_friends/input_phone_number_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_logue/core/widgets/post/post_item.dart';
import 'package:my_logue/core/widgets/follow/follow_user_tile.dart';
import '../../../data/models/book_post_model.dart';
import '../../../data/repositories/user_repository.dart';
import '../profile/other_profile_screen.dart';
import '../../../core/providers/follow_state_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'users_with_same_books_screen.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

class HomeRecommendTab extends ConsumerStatefulWidget {
  const HomeRecommendTab({super.key});

  @override
  ConsumerState<HomeRecommendTab> createState() => _HomeRecommendTabState();

  /// 캐시를 무시하고 강제로 새로고침 (add_book_screen에서 책 변경 시 호출)
  static void refreshUsersWithSameBooks() {
    debugPrint('🔄 책 변경 감지 - 홈 화면 친구 목록 캐시 새로고침 요청');
    _HomeRecommendTabState._needsRefresh = true;
  }
}

class _HomeRecommendTabState extends ConsumerState<HomeRecommendTab> {
  final client = Supabase.instance.client;
  List<Map<String, dynamic>> usersWithSameBooks = [];
  List<Map<String, dynamic>> recentActiveUsers = [];
  bool isLoading = true;
  bool isLoadingUsers = true;

  // 캐싱을 위한 변수들
  static List<Map<String, dynamic>> _cachedUsersWithSameBooks = [];
  static bool _hasCachedData = false;
  static bool _needsRefresh = false; // 책 변경 감지 플래그

  @override
  void initState() {
    super.initState();
    _loadUsersWithSameBooks();
    _fetchRecentActiveUsers();
  }

  /// 캐시된 데이터가 있는지 확인하고 적절히 로드
  void _loadUsersWithSameBooks() {
    if (_hasCachedData && !_needsRefresh) {
      // 캐시가 있고 새로고침이 필요하지 않은 경우 캐시된 데이터 사용
      debugPrint('📦 캐시된 데이터 사용');
      setState(() {
        usersWithSameBooks = List.from(_cachedUsersWithSameBooks);
        isLoading = false;
      });
      return;
    }

    // 캐시가 없거나 새로고침이 필요한 경우 새로 로드
    if (_needsRefresh) {
      debugPrint('🔄 책 변경 감지됨 - 새로 데이터 로드');
    } else {
      debugPrint('🔄 캐시 없음 - 새로 데이터 로드');
    }
    _fetchUsersWithSameBooks();
  }

  Future<void> _fetchUsersWithSameBooks() async {
    try {
      debugPrint('🚀 인생책이 겹치는 사람 조회 시작');
      final userRepository = UserRepository(client);
      final users = await userRepository.getUsersWithSameBooks();

      if (mounted) {
        // 팔로우한 사람들을 먼저, 팔로우하지 않은 사람들을 나중에 정렬
        final sortedUsers = await _sortUsersByFollowStatus(users);

        // 데이터를 캐시에 저장
        _cachedUsersWithSameBooks = List.from(sortedUsers);
        _hasCachedData = true;
        _needsRefresh = false; // 새로고침 플래그 리셋

        debugPrint('✅ 인생책이 겹치는 사람 조회 완료 - ${sortedUsers.length}명, 캐시 저장됨');

        setState(() {
          usersWithSameBooks = sortedUsers;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ 인생책이 겹치는 사람 조회 실패: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<List<Map<String, dynamic>>> _sortUsersByFollowStatus(
      List<Map<String, dynamic>> users) async {
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

  Future<void> _handleFindFriends() async {
    try {
      // 1) 권한 체크 & 요청 (한 번에 처리)
      final hasPermission = await FlutterContacts.requestPermission(readonly: true);

      if (!mounted) return;

      if (hasPermission) {
        // 2) 권한 승인된 경우에만 연락처 조회
        await _getContactsAndNavigate();
        return;
      }

      // 3) 권한 거부: 안내 다이얼로그 (설정 이동 유도 등)
      await showDialog(
        context: context,
        builder: (ctx) => ContactPermissionDialog(
          onConfirm: () async {
            Navigator.pop(ctx);
            // (선택) permission_handler로 설정 열기 가능
            // await openAppSettings(); // permission_handler 패키지 사용 시
          },
        ),
      );
    } catch (e) {
      debugPrint('❌ 친구 찾기 실패: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('친구 찾기 중 오류가 발생했습니다.'), duration: Duration(seconds: 2)),
      );
    }
  }

  /// 주소록에서 전화번호를 가져오고 화면 이동
  Future<void> _getContactsAndNavigate() async {
    try {
      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: false,
      );

      await _processContactsAndNavigate(contacts);
    } catch (e) {
      debugPrint('❌ 주소록에서 전화번호 가져오기 실패: $e');
      if (!mounted) return;
    }
  }

  /// 연락처 목록을 처리하고 화면 이동
  Future<void> _processContactsAndNavigate(List<Contact> contacts) async {
    try {
      final phoneNumbers = <String>[];
      for (final contact in contacts) {
        if (contact.phones.isNotEmpty) {
          for (final phone in contact.phones) {
            // 전화번호에서 특수문자 제거하고 숫자만 추출
            final cleanPhone =
                phone.number.replaceAll(RegExp(r'[^\d]'), '');
            if (cleanPhone.isNotEmpty) {
              phoneNumbers.add(cleanPhone);
            }
          }
        }
      }

      // 중복 제거
      final uniquePhoneNumbers = phoneNumbers.toSet().toList();

      debugPrint('📱 주소록에서 가져온 전화번호 목록:');
      debugPrint('📱 총 전화번호 개수: ${phoneNumbers.length}개');
      debugPrint('📱 중복 제거 후 개수: ${uniquePhoneNumbers.length}개');
      debugPrint('📱 전화번호 목록: $uniquePhoneNumbers');

      // 친구 찾기 화면으로 이동하면서 연락처 목록 전달
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => InputPhoneNumberScreen(
              contactPhoneNumbers: uniquePhoneNumbers,
            ),
          ),
        );
      }
    } catch (e) {
      print('❌ 연락처 처리 중 오류 발생: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('연락처 처리 중 오류가 발생했습니다.'),
            duration: Duration(seconds: 2),
          ),
        );
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
              child: StrokeTextStyle.createStrokeText(
                  text: '내 지인 중에서 LOGUE 유저 찾아보기',
                  fontSize: 16,
                  color: AppColors.black900,
                  fontWeight: FontWeight.w400,
                  height: 1.187)),
          const SizedBox(height: 13),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 21),
            child: Row(
              children: [
                const Expanded(child: SizedBox()),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      await _handleFindFriends();
                    },
                    style: _outlinedStyle(context),
                    child: const Text(
                      '친구 찾기',
                      style: TextStyle(
                          fontSize: 13,
                          color: AppColors.black900,
                          height: 1.25),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 35),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                StrokeTextStyle.createStrokeText(
                    text: "나와 인생책이 겹치는 친구",
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: AppColors.black900,
                    height: 1.187),
                if (!isLoading)
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
          if (isLoading)
            const Padding(
              padding: EdgeInsets.only(top: 15), // 원하는 만큼 내림
              child: Center(child: CircularProgressIndicator()),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (usersWithSameBooks.isNotEmpty) ...[
                  const SizedBox(height: 15),
                  Column(
                    children: usersWithSameBooks.take(3).map((user) {
                      final isFollowing =
                          ref.watch(followStateProvider(user['user_id']));
                      return FollowUserTile(
                        currentUserId: client.auth.currentUser?.id ?? '',
                        userId: user['user_id'],
                        username: user['username'] ?? '',
                        name: user['name'] ?? '',
                        avatarUrl: user['avatar_url'] ?? 'basic',
                        isMyProfile: false,
                        onTapFollow: () async {
                          final followNotifier = ref.read(
                              followStateProvider(user['user_id']).notifier);
                          followNotifier.optimisticFollow();
                          try {
                            await followNotifier.follow();
                          } catch (e) {
                            followNotifier.optimisticUnfollow();
                          }
                        },
                        onTapUnfollow: () async {
                          final followNotifier = ref.read(
                              followStateProvider(user['user_id']).notifier);
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
                              builder: (_) =>
                                  OtherProfileScreen(userId: user['user_id']),
                            ),
                          );
                        },
                        isFollowing: isFollowing,
                      );
                    }).toList(),
                  ),
                  SizedBox(
                    height: 50,
                    child: Column(
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
                              child: const Text(
                                "더보기",
                                style: TextStyle(
                                  color: AppColors.black900,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                          ),
                        usersWithSameBooks.length > 3
                            ? const SizedBox(height: 0)
                            : SizedBox(height: 30),
                        const Divider(height: 1, color: AppColors.black300),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          if (usersWithSameBooks.isNotEmpty) const SizedBox(height: 17),
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
          SizedBox(
            height: 16,
          ),
          if (isLoadingUsers)
            const Center(child: CircularProgressIndicator())
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 0),
                Column(
                  children: recentActiveUsers.take(50).map((user) {
                    final isFollowing =
                        ref.watch(followStateProvider(user['user_id']));
                    return FollowUserTile(
                      currentUserId: client.auth.currentUser?.id ?? '',
                      userId: user['user_id'],
                      username: user['username'] ?? '',
                      name: user['name'] ?? '',
                      avatarUrl: user['avatar_url'] ?? 'basic',
                      isMyProfile: false,
                      onTapFollow: () async {
                        final followNotifier = ref.read(
                            followStateProvider(user['user_id']).notifier);
                        followNotifier.optimisticFollow();
                        try {
                          await followNotifier.follow();
                        } catch (e) {
                          followNotifier.optimisticUnfollow();
                        }
                      },
                      onTapUnfollow: () async {
                        final followNotifier = ref.read(
                            followStateProvider(user['user_id']).notifier);
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
                            builder: (_) =>
                                OtherProfileScreen(userId: user['user_id']),
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
