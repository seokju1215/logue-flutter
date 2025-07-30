import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_logue/core/themes/app_colors.dart';
import 'package:my_logue/core/widgets/follow/follow_user_tile.dart';
import 'package:my_logue/domain/entities/follow_list_type.dart';

import 'package:my_logue/presentation/screens/profile/other_profile_screen.dart';

import '../../../../core/providers/follow_state_provider.dart';
import '../../../../core/constants/app_constants.dart';

class FollowListTab extends ConsumerStatefulWidget {
  final FollowListType type;
  final String userId;
  final bool isMyProfile;
  final VoidCallback? onChangedCount;

  const FollowListTab({
    super.key,
    required this.type,
    required this.userId,
    required this.isMyProfile,
    this.onChangedCount,
  });

  @override
  ConsumerState<FollowListTab> createState() => _FollowListTabState();
}

class _FollowListTabState extends ConsumerState<FollowListTab> {
  final client = Supabase.instance.client;

  List<Map<String, dynamic>> users = [];
  String? currentUserId;
  bool _shouldRefresh = false; // 언팔로우 발생 시 새로고침 플래그

  bool get isMyProfile => currentUserId == widget.userId;

  @override
  void initState() {
    super.initState();
    currentUserId = client.auth.currentUser?.id;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Provider가 완전히 초기화된 후에 데이터 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (users.isEmpty) {
        _fetchFollowList();
      }
    });
  }

  @override
  void didUpdateWidget(covariant FollowListTab oldWidget) {
    super.didUpdateWidget(oldWidget);

    // userId가 바뀌었거나, 탭 타입이 바뀌었을 때만 다시 불러오기
    // 화면이 다시 보여질 때는 불러오지 않음 (로컬 상태 유지)
    if (oldWidget.userId != widget.userId || oldWidget.type != widget.type) {
      _fetchFollowList();
    }
    
    // 언팔로우가 발생했을 때만 새로고침
    if (_shouldRefresh && widget.type == FollowListType.followings) {
      _shouldRefresh = false;
      _fetchFollowList();
    }
  }

  Future<void> _fetchFollowList() async {
    if (currentUserId == null) return;

    final userId = currentUserId!; // non-null로 promotion

    List<Map<String, dynamic>> rawList = [];

    if (widget.type == FollowListType.followers) {
      // 팔로워 탭: followers_with_profiles 뷰 사용
      final res = await client
          .from('followers_with_profiles')
          .select()
          .eq('following_id', widget.userId);
      rawList = List<Map<String, dynamic>>.from(res);
    } else {
      // 팔로잉 탭: followings_with_profiles 뷰 사용
      final res = await client
          .from('followings_with_profiles')
          .select()
          .eq('follower_id', widget.userId);
      rawList = List<Map<String, dynamic>>.from(res);
    }

    debugPrint('[DEBUG] rawList length: ${rawList.length}');

    // 내 계정이 있으면 맨 위로
    if (widget.type == FollowListType.followers && !isMyProfile) {
      final index = rawList.indexWhere((user) => user['id'] == userId);
      if (index != -1) {
        final me = rawList.removeAt(index);
        rawList.insert(0, me);
      }
    }
    if (widget.type == FollowListType.followings && !isMyProfile) {
      final index = rawList.indexWhere((user) => user['id'] == userId);
      if (index != -1) {
        final me = rawList.removeAt(index);
        rawList.insert(0, me);
      }
    }

    // 팔로잉 탭인 경우 실제 팔로우 상태를 DB에서 직접 확인하고 Provider 업데이트
    List<Map<String, dynamic>> sortedList = [];
    
    if (widget.type == FollowListType.followings && isMyProfile && currentUserId != null) {
      // 팔로잉 탭에서는 실제 팔로우 상태를 DB에서 확인
      for (final user in rawList) {
        final userId = user['id'] as String;
        try {
          final followRes = await client
              .from('follows')
              .select('id')
              .eq('follower_id', currentUserId!)
              .eq('following_id', userId)
              .maybeSingle();
          
          final isFollowing = followRes != null;
          sortedList.add({
            ...user,
            'isFollowing': isFollowing,
          });
          
          // Provider 상태도 업데이트
          ref.read(followStateProvider(userId).notifier).safeSet(isFollowing);
        } catch (e) {
          debugPrint('⚠️ 팔로우 상태 확인 실패: $e');
          sortedList.add({
            ...user,
            'isFollowing': false,
          });
        }
      }
    } else {
      // 팔로워 탭에서는 Provider 상태 사용
      for (final user in rawList) {
        final userId = user['id'] as String;
        bool isFollowing = false;
        try {
          isFollowing = ref.read(followStateProvider(userId));
        } catch (e) {
          debugPrint('⚠️ Provider 초기화 중 - 기본값 false 사용: $e');
          isFollowing = false;
        }
        sortedList.add({
          ...user,
          'isFollowing': isFollowing,
        });
      }
    }

    // 팔로잉 탭일 때는 팔로우하지 않은 사용자 제거
    if (widget.type == FollowListType.followings && isMyProfile) {
      sortedList = sortedList.where((user) => user['isFollowing'] == true).toList();
    }

    // 내 계정이 제일 위에 오도록 정렬
    sortedList.sort((a, b) {
      // 내 계정이 제일 위에
      if (a['id'] == currentUserId && b['id'] != currentUserId) return -1;
      if (a['id'] != currentUserId && b['id'] == currentUserId) return 1;
      
      // 그 다음 팔로우한 계정
      if (a['isFollowing'] == true && b['isFollowing'] != true) return -1;
      if (a['isFollowing'] != true && b['isFollowing'] == true) return 1;
      
      // 이름 순으로 정렬
      final nameA = a['name'] ?? '';
      final nameB = b['name'] ?? '';
      return nameA.compareTo(nameB);
    });

    setState(() {
      users = sortedList;
    });
  }

  // 리스트가 같은지 비교하는 헬퍼 함수
  bool _areListsEqual(List<Map<String, dynamic>> list1, List<Map<String, dynamic>> list2) {
    if (list1.length != list2.length) return false;
    
    for (int i = 0; i < list1.length; i++) {
      if (list1[i]['id'] != list2[i]['id'] || 
          list1[i]['isFollowing'] != list2[i]['isFollowing']) {
        return false;
      }
    }
    return true;
  }

  Future<void> _updateFollowStatus(String userId) async {
    try {
      debugPrint('🔍 _updateFollowStatus 시작 - userId: $userId');
      
      // Provider 기반으로 팔로우 상태 확인
      final followNotifier = ref.read(followStateProvider(userId).notifier);
      await followNotifier.refresh();
      final isFollowing = ref.read(followStateProvider(userId));
      
      debugPrint('🔍 팔로우 상태 확인 결과: $isFollowing');

      setState(() {
        if (widget.type == FollowListType.followings && isMyProfile && !isFollowing) {
          // 팔로잉 탭에서 언팔로우된 경우 목록에서 제거
          debugPrint('🔍 팔로잉 탭에서 언팔로우 - 목록에서 제거');
          users.removeWhere((u) => u['id'] == userId);
        } else {
          // 팔로우 상태만 업데이트
          users = users.map((u) {
            if (u['id'] == userId) {
              return {...u, 'isFollowing': isFollowing};
            }
            return u;
          }).toList();
        }
      });
      
      debugPrint('🔍 _updateFollowStatus 완료');
    } catch (e) {
      debugPrint('❌ 팔로우 상태 업데이트 실패: $e');
    }
  }

  Future<void> _handleRemoveFollower(String targetUserId) async {
    try {
      // 로컬에서 즉시 제거
      setState(() {
        final index = users.indexWhere((u) => u['id'] == targetUserId);
        if (index != -1) {
          users.removeAt(index);
        }
      });
      
      // 카운트 즉시 업데이트
      widget.onChangedCount?.call();
      
      // 서버에 요청 (백그라운드)
      client.rpc('remove_follower', params: {
      'target_user_id': targetUserId,
      }).catchError((e) async {
        debugPrint('❌ 팔로워 제거 실패: $e');
        // 실패 시 다시 추가
        if (mounted) {
          // 사용자 정보를 다시 가져와서 목록에 추가
          try {
            final userData = await client
                .from('profiles')
                .select()
                .eq('id', targetUserId)
                .single();
            
            setState(() {
              users.add({
                ...userData,
                'isFollowing': true,
                'isSelf': false,
              });
            });
          } catch (err) {
            debugPrint('❌ 사용자 정보 가져오기 실패: $err');
          }
          widget.onChangedCount?.call();
        }
      });
    } catch (e) {
      debugPrint('❌ 팔로워 제거 처리 실패: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        // 실시간으로 팔로우 상태 업데이트 (정렬은 하지 않음)
        List<Map<String, dynamic>> displayUsers = users.map((user) {
          final userId = user['id'] as String;
          final isFollowing = ref.watch(followStateProvider(userId));
          final isSelf = user['id'] == currentUserId;
          
          return {
            ...user,
            'isFollowing': isFollowing,
            'isSelf': isSelf,
          };
        }).toList();

        // 팔로잉 탭일 때는 팔로우하지 않은 사용자 제거
        if (widget.type == FollowListType.followings && isMyProfile) {
          displayUsers = displayUsers.where((user) => user['isFollowing'] == true).toList();
        }

        if (displayUsers.isEmpty) {
          return Center(
            child: Transform.translate(
              offset: AppConstants.getCenterOffsetWithTabBar(context),
              child: const Text(
                "친구를 팔로우해 서로의 인생 책을 공유해보세요.",
                style: TextStyle(fontSize: 12, color: AppColors.black500),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        return ListView.builder(
          itemCount: displayUsers.length,
          itemBuilder: (context, index) {
            final user = displayUsers[index];
            final avatarUrl = user['avatar_url'] ?? 'basic';
            final username = user['username'] ?? '사용자';
            final name = user['name'] ?? '';
            final isFollowing = user['isFollowing'] == true;

            return FollowUserTile(
              userId: user['id'],
              username: username,
              name: name,
              avatarUrl: avatarUrl,
              isMyProfile: isMyProfile,
              tabType: widget.type,
              isFollowing: isFollowing,
              onTapFollow: () async {
                try {
                  final followNotifier = ref.read(followStateProvider(user['id']).notifier);
                  followNotifier.optimisticFollow();
                  
                  // 로컬 상태 즉시 업데이트
                  setState(() {
                    users = users.map((u) {
                      if (u['id'] == user['id']) {
                        return {...u, 'isFollowing': true};
                      }
                      return u;
                    }).toList();
                  });
                  
                  widget.onChangedCount?.call();
                  await followNotifier.follow();
                } catch (e) {
                  debugPrint('❌ 팔로우 실패: $e');
                  final followNotifier = ref.read(followStateProvider(user['id']).notifier);
                  followNotifier.optimisticUnfollow();
                  
                  // 실패 시 롤백
                  setState(() {
                    users = users.map((u) {
                      if (u['id'] == user['id']) {
                        return {...u, 'isFollowing': false};
                      }
                      return u;
                    }).toList();
                  });
                  
                  widget.onChangedCount?.call();
                }
              },
              onTapUnfollow: () async {
                try {
                  final followNotifier = ref.read(followStateProvider(user['id']).notifier);
                  followNotifier.optimisticUnfollow();
                  
                  // 팔로잉 탭에서 언팔로우 시 즉시 목록에서 제거
                  if (widget.type == FollowListType.followings) {
                    setState(() {
                      users.removeWhere((u) => u['id'] == user['id']);
                    });
                  } else {
                    // 팔로워 탭에서는 상태만 업데이트
                    setState(() {
                      users = users.map((u) {
                        if (u['id'] == user['id']) {
                          return {...u, 'isFollowing': false};
                        }
                        return u;
                      }).toList();
                    });
                  }
                  
                  widget.onChangedCount?.call();
                  await followNotifier.unfollow();
                } catch (e) {
                  debugPrint('❌ 언팔로우 실패: $e');
                  final followNotifier = ref.read(followStateProvider(user['id']).notifier);
                  followNotifier.optimisticFollow();
                  
                  // 실패 시 롤백 (팔로잉 탭에서 제거된 경우 다시 추가)
                  if (widget.type == FollowListType.followings) {
                    setState(() {
                      users.add({
                        ...user,
                        'isFollowing': true,
                      });
                    });
                  } else {
                    setState(() {
                      users = users.map((u) {
                        if (u['id'] == user['id']) {
                          return {...u, 'isFollowing': true};
                        }
                        return u;
                      }).toList();
                    });
                  }
                  
                  widget.onChangedCount?.call();
                }
              },
              onTapRemove: () => _handleRemoveFollower(user['id']),
              currentUserId: Supabase.instance.client.auth.currentUser?.id ?? '',
              onTapProfile: () async {
                debugPrint('🔍 프로필 화면으로 이동: ${user['id']}');
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OtherProfileScreen(userId: user['id']),
                  ),
                );
                
                debugPrint('🔍 프로필 화면에서 돌아옴 - result: $result');
                
                // 프로필 화면에서 돌아왔을 때 팔로우 상태가 변경되었을 수 있으므로
                // 해당 사용자의 팔로우 상태를 다시 확인
                if (result == true) {
                  debugPrint('🔍 팔로우 상태 변경 감지 - 강제 새로고침 실행');
                  
                  // 강제 새로고침으로 최신 상태 확인
                  final followNotifier = ref.read(followStateProvider(user['id']).notifier);
                  await followNotifier.forceRefresh();
                  
                  // 팔로잉 탭에서 언팔로우된 경우 목록에서 제거
                  if (widget.type == FollowListType.followings && isMyProfile) {
                    final isFollowing = ref.read(followStateProvider(user['id']));
                    
                    if (!isFollowing) {
                      setState(() {
                        users.removeWhere((u) => u['id'] == user['id']);
                      });
                      
                      // 카운트 업데이트
                      widget.onChangedCount?.call();
                      debugPrint('🔍 팔로잉 탭에서 사용자 제거 완료: ${user['id']}');
                    }
                  } else {
                    // 다른 탭에서는 상태만 업데이트
                  await _updateFollowStatus(user['id']);
                  }
                } else {
                  debugPrint('🔍 팔로우 상태 변경 없음');
                }
              },
            );
          },
        );
      },
    );
  }
}
