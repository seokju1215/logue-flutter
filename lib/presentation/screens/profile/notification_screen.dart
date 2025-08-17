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
      
      // 각 알림의 상세 정보 출력
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
      
      // FollowTabScreen으로 이동 (팔로잉 탭 선택)
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FollowTabScreen(
            userId: currentUserId,
            username: username,
            initialTabIndex: 1, // 팔로잉 탭
            followerCount: followerCount,
            followingCount: followingCount,
            isMyProfile: true,
          ),
        ),
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

  /// inquiry_screen으로 이동
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



  /// 모든 알림 삭제
  Future<void> _deleteAllNotifications() async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      debugPrint('🗑️ 모든 알림 삭제 시작:');
      debugPrint('   - 사용자 ID: $userId');
      debugPrint('   - 현재 알림 개수: ${_notifications.length}');

      // 모든 알림 삭제
      final result = await client
          .from('notifications')
          .delete()
          .eq('recipient_id', userId);

      debugPrint('✅ 모든 알림 삭제 완료 - 삭제된 행: $result');

      // UI 업데이트
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

      // 에러 메시지 표시
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

  @override
  Widget build(BuildContext context) {
    debugPrint('🏗️ NotificationScreen 빌드 시작');
    debugPrint('📊 현재 알림 개수: ${_notifications.length}');
    
    // 포스트 알림을 그룹화하여 중복 제거
    final processedNotifications = <Map<String, dynamic>>[];
    final postSenders = <String>{};
    final postNotifications = <Map<String, dynamic>>[];
    
    // 알림을 타입별로 분류
    for (final notification in _notifications) {
      final type = notification['type'];
      
      if (type == 'follow' || type == 'inquiry') {
        // 팔로우와 문의 알림은 그대로 추가
        processedNotifications.add(notification);
      } else if (type == 'post') {
        // 포스트 알림은 별도로 수집
        postNotifications.add(notification);
        postSenders.add(notification['sender']['id']);
      }
    }
    
    // 포스트 알림이 있으면 하나로 통합
    if (postNotifications.isNotEmpty) {
      final firstPostNotification = postNotifications.first;
      final totalSenders = postSenders.length;
      
      if (totalSenders > 1) {
        // 여러 발신자가 있는 경우 통합된 메시지 생성
        final integratedNotification = Map<String, dynamic>.from(firstPostNotification);
        integratedNotification['integrated'] = true;
        integratedNotification['total_senders'] = totalSenders;
        processedNotifications.add(integratedNotification);
      } else {
        // 발신자가 한 명인 경우 그대로 추가
        processedNotifications.add(firstPostNotification);
      }
    }
    
    debugPrint('📝 포스트 알림 발신자 수: ${postSenders.length}');
    debugPrint('🔍 포스트 알림 발신자 ID들: $postSenders');
    debugPrint('📊 처리된 알림 개수: ${processedNotifications.length}');

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
                   child: Text(
                     '모두 지우기',
                     style: const TextStyle(
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
                final username = sender['username'];
                final notifId = item['id'];

                String content = '';
                if (type == 'follow') {
                  content = '$username님이 팔로우하기 시작했어요.';
                } else if (type == 'post') {
                  if (item['integrated'] == true) {
                    final totalSenders = item['total_senders'];
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
                      // 팔로우 알림: 상대방 프로필로 이동
                      _goToProfile(sender['id']);
                    } else if (type == 'post') {
                      // 포스트 알림: 내 프로필의 팔로잉 탭으로 이동
                      _goToMyProfileFollowingTab();
                    } else if (type == 'inquiry') {
                      // 문의 알림: inquiry_screen으로 이동
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