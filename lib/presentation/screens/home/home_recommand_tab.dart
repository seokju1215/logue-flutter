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
import 'package:permission_handler/permission_handler.dart';
import 'package:app_settings/app_settings.dart';
import 'package:my_logue/presentation/screens/home/find_friends/find_friends_screen.dart';

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

  /// 친구 찾기 버튼 클릭 시 처리
  Future<void> _handleFindFriends() async {
    try {
      // 1) 먼저 profiles 테이블에 contact_number가 있는지 확인
      final currentUserId = client.auth.currentUser?.id;
      if (currentUserId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인이 필요합니다.'), duration: Duration(seconds: 2)),
        );
        return;
      }

      // profiles 테이블에서 contact_number 확인
      final profileResponse = await client
          .from('profiles')
          .select('contact_number')
          .eq('id', currentUserId)
          .maybeSingle();

      final contactNumber = profileResponse?['contact_number'] as String?;
      
      // 2) 주소록에서 모든 전화번호 목록 가져오기
      debugPrint('📱 주소록에서 전화번호 목록 가져오기 시작');
      
      // 연락처 권한 확인
      final currentPermission = await FlutterContacts.requestPermission(readonly: true);
      debugPrint('🔐 현재 연락처 권한 상태: $currentPermission');

      if (currentPermission) {
        // 권한이 이미 있음, 주소록에서 전화번호 가져오기
        debugPrint('✅ 권한이 이미 있음, 주소록에서 전화번호 가져오기 시작');
        final contactPhoneNumbers = await _getPhoneNumbersFromContacts();
        
        if (contactNumber != null && contactNumber.isNotEmpty) {
          // contact_number가 있으면 바로 FindFriendsScreen으로 이동
          debugPrint('📱 사용자 전화번호가 등록되어 있음: $contactNumber');
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FindFriendsScreen(
                  contactNumber: contactNumber,
                  contactPhoneNumbers: contactPhoneNumbers,
                ),
              ),
            );
          }
        } else {
          // contact_number가 없으면 input_phone_number_screen으로 이동
          debugPrint('📱 사용자 전화번호가 등록되지 않음, input_phone_number_screen으로 이동');
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => InputPhoneNumberScreen(
                  contactPhoneNumbers: contactPhoneNumbers,
                ),
              ),
            );
          }
        }
      } else {
        // 권한이 없음, 권한 요청
        debugPrint('❌ 권한이 없음, 권한 요청 시작');
        final permission = await FlutterContacts.requestPermission();
        debugPrint('🔐 권한 요청 결과: $permission');

        if (permission) {
          // 권한 승인됨, 주소록에서 전화번호 가져오기
          debugPrint('✅ 권한 승인됨, 주소록에서 전화번호 가져오기 시작');
          final contactPhoneNumbers = await _getPhoneNumbersFromContacts();
          
          if (contactNumber != null && contactNumber.isNotEmpty) {
            // contact_number가 있으면 바로 FindFriendsScreen으로 이동
            debugPrint('📱 사용자 전화번호가 등록되어 있음: $contactNumber');
            if (mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FindFriendsScreen(
                    contactNumber: contactNumber,
                    contactPhoneNumbers: contactPhoneNumbers,
                  ),
                ),
              );
            }
          } else {
            // contact_number가 없으면 input_phone_number_screen으로 이동
            debugPrint('📱 사용자 전화번호가 등록되지 않음, input_phone_number_screen으로 이동');
            if (mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => InputPhoneNumberScreen(
                    contactPhoneNumbers: contactPhoneNumbers,
                  ),
                ),
              );
            }
          }
        } else {
          // 권한 거부됨
          debugPrint('❌ 권한 거부됨');
          await showDialog(
            context: context,
            builder: (ctx) => ContactPermissionDialog(
              onConfirm: () async {
                Navigator.pop(ctx);
                // 설정창 열기
                try {
                  await AppSettings.openAppSettings();
                } catch (e) {
                  debugPrint('❌ 설정창 열기 실패: $e');
                  // fallback: permission_handler 사용
                  try {
                    await openAppSettings();
                  } catch (e2) {
                    debugPrint('❌ permission_handler로도 설정창 열기 실패: $e2');
                  }
                }
              },
            ),
          );
        }
      }
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
      debugPrint('📱 ===== 주소록 정보 상세 출력 =====');
      debugPrint('📱 전체 연락처 개수: ${contacts.length}개');
      
      final phoneNumbers = <String>[];
      final contactDetails = <String>[];
      
      for (int i = 0; i < contacts.length; i++) {
        final contact = contacts[i];
        final contactName = contact.displayName ?? '이름 없음';
        final contactId = contact.id;
        
        debugPrint('📱 연락처 [$i]: ID=$contactId, 이름="$contactName"');
        
        if (contact.phones.isNotEmpty) {
          debugPrint('📱   전화번호 개수: ${contact.phones.length}개');
          
          for (int j = 0; j < contact.phones.length; j++) {
            final phone = contact.phones[j];
            final originalNumber = phone.number;
            final cleanPhone = phone.number.replaceAll(RegExp(r'[^\d]'), '');
            
            debugPrint('📱     전화번호 [$j]: 원본="$originalNumber", 정리="$cleanPhone"');
            
            if (cleanPhone.isNotEmpty) {
              phoneNumbers.add(cleanPhone);
              contactDetails.add('$contactName: $cleanPhone');
            }
          }
        } else {
          debugPrint('📱   전화번호 없음');
        }
        
        // 연락처 정보가 너무 많으면 처음 10개만 출력
        if (i >= 9) {
          debugPrint('📱 ... (이하 ${contacts.length - 10}개 연락처 생략)');
          break;
        }
      }

      // 중복 제거
      final uniquePhoneNumbers = phoneNumbers.toSet().toList();

      debugPrint('📱 ===== 전화번호 처리 결과 =====');
      debugPrint('📱 총 전화번호 개수: ${phoneNumbers.length}개');
      debugPrint('📱 중복 제거 후 개수: ${uniquePhoneNumbers.length}개');
      debugPrint('📱 전화번호 샘플 (처음 10개): ${uniquePhoneNumbers.take(10).toList()}');
      
      if (uniquePhoneNumbers.length > 10) {
        debugPrint('📱 ... (이하 ${uniquePhoneNumbers.length - 10}개 전화번호 생략)');
      }

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

  Future<List<String>> _getPhoneNumbersFromContacts() async {
    try {
      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: false,
      );
      final phoneNumbers = <String>[];
      for (final contact in contacts) {
        if (contact.phones.isNotEmpty) {
          for (final phone in contact.phones) {
            final cleanPhone = phone.number.replaceAll(RegExp(r'[^\d]'), '');
            if (cleanPhone.isNotEmpty) {
              phoneNumbers.add(cleanPhone);
            }
          }
        }
      }
      return phoneNumbers;
    } catch (e) {
      debugPrint('❌ 주소록에서 전화번호 가져오기 실패: $e');
      return [];
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

