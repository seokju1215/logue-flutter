import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:app_settings/app_settings.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_logue/core/themes/app_colors.dart';
import 'package:my_logue/domain/usecases/get_notifications.dart';
import 'package:my_logue/core/constants/app_constants.dart';
import 'package:my_logue/presentation/screens/profile/other_profile_screen.dart';
import 'package:my_logue/presentation/screens/setting/inquiry/inquiry_screen.dart';
import 'package:my_logue/presentation/screens/main_navigation_screen.dart';
import 'package:my_logue/presentation/screens/profile/follow/follow_tab_screen.dart';

import '../home/home_screen.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({Key? key}) : super(key: key);

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> with WidgetsBindingObserver {
  final client = Supabase.instance.client;
  late final GetNotifications _getNotifications;
  List<Map<String, dynamic>> _notifications = [];
  bool isNotificationOn = true;

  @override
  void initState() {
    super.initState();
    debugPrint('🚀 NotificationScreen 초기화 시작');

    _getNotifications = GetNotifications(client);
    debugPrint('✅ GetNotifications 인스턴스 생성 완료');

    debugPrint('📖 모든 알림 읽음 처리 시작');
    _markAllAsRead();

    debugPrint('📥 알림 로딩 시작');
    _loadNotifications();

    debugPrint('🔔 알림 권한 확인 시작');
    _checkNotificationPermission();

    WidgetsBinding.instance.addObserver(this);
    debugPrint('👁️ WidgetsBindingObserver 등록 완료');

    debugPrint('✅ NotificationScreen 초기화 완료');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkNotificationPermission();
    }
  }

  Future<void> _checkNotificationPermission() async {
    final status = await Permission.notification.status;
    setState(() {
      isNotificationOn = status.isGranted;
    });
  }

  Future<void> _markAllAsRead() async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      debugPrint('📖 모든 알림 읽음 처리 시작 - 사용자 ID: $userId');

      // 읽지 않은 알림 개수 확인
      final unreadCount = await client
          .from('notifications')
          .select('id')
          .eq('recipient_id', userId)
          .eq('is_read', false);

      debugPrint('📊 읽지 않은 알림 개수: ${unreadCount.length}');

      if (unreadCount.isNotEmpty) {
        final result = await client
            .from('notifications')
            .update({'is_read': true})
            .eq('recipient_id', userId)
            .eq('is_read', false);

        debugPrint('✅ 알림 읽음 처리 완료 - 업데이트된 행: $result');
      } else {
        debugPrint('ℹ️ 읽지 않은 알림이 없음');
      }
    } catch (e) {
      debugPrint('❌ 알림 읽음 처리 실패: $e');
      debugPrint('❌ 에러 타입: ${e.runtimeType}');
      if (e is PostgrestException) {
        debugPrint('❌ PostgrestException 상세:');
        debugPrint('   - Message: ${e.message}');
        debugPrint('   - Code: ${e.code}');
        debugPrint('   - Details: ${e.details}');
        debugPrint('   - Hint: ${e.hint}');
      }
    }
  }

  Future<void> _loadNotifications() async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      debugPrint('🚀 알림 로딩 시작 - 사용자 ID: $userId');

      final data = await _getNotifications(userId);

      debugPrint('📥 백엔드에서 받은 알림 데이터:');
      debugPrint('📊 총 알림 개수: ${data.length}');

      for (int i = 0; i < data.length; i++) {
        final notification = data[i];
        debugPrint('🔔 알림 #$i:');
        debugPrint('   - ID: ${notification['id']}');
        debugPrint('   - Type: ${notification['type']}');
        debugPrint('   - Created At: ${notification['created_at']}');
        debugPrint('   - Is Read: ${notification['is_read']}');

        if (notification['sender'] != null) {
          final sender = notification['sender'];
          debugPrint('   - Sender ID: ${sender['id']}');
          debugPrint('   - Sender Username: ${sender['username']}');
          debugPrint('   - Sender Avatar: ${sender['avatar_url']}');
        }

        if (notification['book_id'] != null) {
          debugPrint('   - Book ID: ${notification['book_id']}');
        }

        debugPrint('   - Raw Data: $notification');
        debugPrint('   ---');
      }

      setState(() {
        _notifications = data;
      });

      debugPrint('✅ 알림 로딩 완료 - UI 업데이트됨');
    } catch (e) {
      debugPrint('❌ 알림 로딩 실패: $e');
      debugPrint('❌ 에러 타입: ${e.runtimeType}');
      if (e is PostgrestException) {
        debugPrint('❌ PostgrestException 상세:');
        debugPrint('   - Message: ${e.message}');
        debugPrint('   - Code: ${e.code}');
        debugPrint('   - Details: ${e.details}');
        debugPrint('   - Hint: ${e.hint}');
      }
    }
  }

  void _goToProfile(String senderId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OtherProfileScreen(userId: senderId),
      ),
    );
  }

  /// 내 프로필의 팔로잉 탭으로 이동
  void _goToMyProfileFollowingTab() async {
    final client = Supabase.instance.client;
    final currentUserId = client.auth.currentUser?.id;

    if (currentUserId == null) return;

    try {
      debugPrint('👤 내 프로필 팔로잉 탭 이동 시작:');
      debugPrint('   - 현재 사용자 ID: $currentUserId');

      // 현재 사용자의 프로필 정보 가져오기
      debugPrint('📋 프로필 정보 조회 시작');
      final profileResponse = await client
          .from('profiles')
          .select('username')
          .eq('id', currentUserId)
          .single();

      final username = profileResponse['username'] as String;
      debugPrint('✅ 프로필 정보 조회 완료 - Username: $username');

      // follows 테이블에서 팔로워/팔로잉 수 계산
      debugPrint('👥 팔로워/팔로잉 수 계산 시작');

      final followerRes = await client
          .from('follows')
          .select('id')
          .eq('following_id', currentUserId);
      final followerCount = followerRes.length;
      debugPrint('   - 팔로워 수: $followerCount');

      final followingRes = await client
          .from('follows')
          .select('id')
          .eq('follower_id', currentUserId);
      final followingCount = followingRes.length;
      debugPrint('   - 팔로잉 수: $followingCount');

      debugPrint('🚀 FollowTabScreen으로 네비게이션 시작');
      debugPrint('   - initialTabIndex: 1 (팔로잉 탭)');
      debugPrint('   - isMyProfile: true');

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => MainNavigationScreen(
            initialTabIndex: 0, // 홈 탭
            child: HomeScreen(
              navigatorKey: GlobalKey<NavigatorState>(),
              initialTab: 1, // ✅ "팔로잉" 탭부터
            ),
          ),
        ),
            (route) => false,
      );

      debugPrint('✅ FollowTabScreen 네비게이션 완료');
    } catch (e) {
      debugPrint('❌ 프로필 정보 가져오기 실패: $e');
      debugPrint('❌ 에러 타입: ${e.runtimeType}');
      if (e is PostgrestException) {
        debugPrint('❌ PostgrestException 상세:');
        debugPrint('   - Message: ${e.message}');
        debugPrint('   - Code: ${e.code}');
        debugPrint('   - Details: ${e.details}');
        debugPrint('   - Hint: ${e.hint}');
      }
    }
  }

  void _goToInquiryScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const InquiryScreen(),
      ),
    );
  }

  Future<void> _deleteNotification(Map<String, dynamic> notification) async {
    final userId = client.auth.currentUser?.id;
    final notifType = notification['type'];

    if (userId == null) return;

    try {
      debugPrint('🗑️ 알림 삭제 시작:');
      debugPrint('   - 알림 ID: ${notification['id']}');
      debugPrint('   - 알림 타입: $notifType');
      debugPrint('   - 사용자 ID: $userId');
      debugPrint('   - 통합된 알림: ${notification['integrated'] ?? false}');

      if (notifType == 'post') {
        if (notification['integrated'] == true) {
          debugPrint('📝 통합된 포스트 알림 삭제 - 모든 포스트 알림 삭제');
          final result = await client.from('notifications').delete().match({
            'recipient_id': userId,
            'type': 'post',
          });
          debugPrint('✅ 통합된 포스트 알림 삭제 완료 - 삭제된 행: $result');
        } else {
          debugPrint('📝 개별 포스트 알림 삭제');
          final result = await client.from('notifications').delete().eq('id', notification['id']);
          debugPrint('✅ 개별 포스트 알림 삭제 완료 - 삭제된 행: $result');
        }
      } else {
        debugPrint('🔔 개별 알림 삭제');
        final result = await client.from('notifications').delete().eq('id', notification['id']);
        debugPrint('✅ 개별 알림 삭제 완료 - 삭제된 행: $result');
      }

      debugPrint('🔄 알림 목록 새로고침 시작');
      await _loadNotifications();
      debugPrint('✅ 알림 목록 새로고침 완료');
    } catch (e) {
      debugPrint('❌ 알림 삭제 실패: $e');
      debugPrint('❌ 에러 타입: ${e.runtimeType}');
      if (e is PostgrestException) {
        debugPrint('❌ PostgrestException 상세:');
        debugPrint('   - Message: ${e.message}');
        debugPrint('   - Code: ${e.code}');
        debugPrint('   - Details: ${e.details}');
        debugPrint('   - Hint: ${e.hint}');
      }
    }
  }

  Future<void> _deleteAllNotifications() async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      debugPrint('🗑️ 모든 알림 삭제 시작:');
      debugPrint('   - 사용자 ID: $userId');
      debugPrint('   - 현재 알림 개수: ${_notifications.length}');

      final result = await client
          .from('notifications')
          .delete()
          .eq('recipient_id', userId);

      debugPrint('✅ 모든 알림 삭제 완료 - 삭제된 행: $result');

      setState(() {
        _notifications.clear();
      });

      debugPrint('🔄 UI 업데이트 완료 - 알림 목록 비움');

    } catch (e) {
      debugPrint('❌ 모든 알림 삭제 실패: $e');
      debugPrint('❌ 에러 타입: ${e.runtimeType}');

      if (e is PostgrestException) {
        debugPrint('❌ PostgrestException 상세:');
        debugPrint('   - Message: ${e.message}');
        debugPrint('   - Code: ${e.code}');
        debugPrint('   - Details: ${e.details}');
        debugPrint('   - Hint: ${e.hint}');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('알림 삭제 중 오류가 발생했습니다.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // ====== 추가: 알림 가공 + 정렬 유틸 ======
  DateTime? _parseTs(dynamic v) {
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  List<Map<String, dynamic>> _processAndSortNotifications(List<Map<String, dynamic>> src) {
    final processed = <Map<String, dynamic>>[];
    final postNotifications = <Map<String, dynamic>>[];
    final postSenders = <String>{};

    // 1) 타입 분류
    for (final n in src) {
      final type = n['type'];
      if (type == 'follow' || type == 'inquiry') {
        processed.add(n);
      } else if (type == 'post') {
        postNotifications.add(n);
        final senderId = n['sender']?['id'];
        if (senderId is String) postSenders.add(senderId);
      }
    }

    // 2) post 통합 처리
    if (postNotifications.isNotEmpty) {
      // 묶인 post 내 가장 최신 timestamp
      DateTime? latestPostTs;
      for (final n in postNotifications) {
        final ts = _parseTs(n['created_at']);
        if (ts != null && (latestPostTs == null || ts.isAfter(latestPostTs!))) {
          latestPostTs = ts;
        }
      }

      if (postSenders.length > 1) {
        // 다수 발신자 → 통합
        final first = postNotifications.first;
        final integrated = Map<String, dynamic>.from(first);
        integrated['integrated'] = true;
        integrated['total_senders'] = postSenders.length;

        // ✅ 가장 최신 created_at로 덮어쓰기
        if (latestPostTs != null) {
          integrated['created_at'] = latestPostTs.toIso8601String();
        }
        processed.add(integrated);
      } else {
        // 한 명이면 최신 1건만
        Map<String, dynamic>? latestItem;
        DateTime? latestTs;
        for (final n in postNotifications) {
          final ts = _parseTs(n['created_at']);
          if (ts != null && (latestTs == null || ts.isAfter(latestTs))) {
            latestTs = ts;
            latestItem = n;
          }
        }
        if (latestItem != null) {
          processed.add(latestItem);
        }
      }
    }

    // 3) created_at 기준 내림차순 정렬
    processed.sort((a, b) {
      final ta = _parseTs(a['created_at']) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final tb = _parseTs(b['created_at']) ?? DateTime.fromMillisecondsSinceEpoch(0);
      return tb.compareTo(ta);
    });

    debugPrint('📝 포스트 알림 발신자 수: ${postSenders.length}');
    debugPrint('📊 처리된 알림 개수(정렬 적용): ${processed.length}');
    return processed;
  }
  // =====================================

  @override
  Widget build(BuildContext context) {
    debugPrint('🏗️ NotificationScreen 빌드 시작');
    debugPrint('📊 현재 알림 개수: ${_notifications.length}');

    // 🔧 변경: 여기서 가공 + 정렬
    final processedNotifications = _processAndSortNotifications(_notifications);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          '알림',
          style: TextStyle(
            fontSize: 16,
            color: AppColors.black900,
            fontWeight: FontWeight.w500,
          ),
        ),
        leading: IconButton(
          icon: SvgPicture.asset('assets/back_arrow.svg'),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '',
                  style: TextStyle(fontSize: 12, color: AppColors.black500),
                ),
                GestureDetector(
                  onTap: () => _deleteAllNotifications(),
                  child: const Text(
                    '모두 지우기',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.black500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: processedNotifications.length,
              itemBuilder: (context, index) {
                final item = processedNotifications[index];
                final type = item['type'];
                final sender = item['sender'];
                final username = sender?['username'] ?? '알 수 없음';

                String content = '';
                if (type == 'follow') {
                  content = '$username님이 팔로우하기 시작했어요.';
                } else if (type == 'post') {
                  if (item['integrated'] == true) {
                    final totalSenders = (item['total_senders'] as int?) ?? 1;
                    content = '$username님 외 ${totalSenders - 1}명이 새로운 인생 책을 추가했어요.';
                  } else {
                    content = '$username님이 새로운 인생 책을 추가했어요.';
                  }
                } else if (type == 'inquiry') {
                  content = '요청하신 책이 로그에 새롭게 추가됐어요!';
                }

                return ListTile(
                  contentPadding: const EdgeInsets.only(left: 22, right: 10),
                  title: Text(
                    content,
                    style: const TextStyle(fontSize: 14, color: AppColors.black500),
                  ),
                  onTap: () {
                    if (type == 'follow') {
                      if (sender?['id'] != null) {
                        _goToProfile(sender['id']);
                      }
                    } else if (type == 'post') {
                      _goToMyProfileFollowingTab();
                    } else if (type == 'inquiry') {
                      _goToInquiryScreen();
                    }
                  },
                  trailing: IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () => _deleteNotification(item),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}