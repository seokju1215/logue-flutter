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
    _getNotifications = GetNotifications(client);
    _markAllAsRead();
    _loadNotifications();
    _checkNotificationPermission();
    WidgetsBinding.instance.addObserver(this);
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
      await client
          .from('notifications')
          .update({'is_read': true})
          .eq('recipient_id', userId)
          .eq('is_read', false);
    } catch (e) {
      debugPrint('❌ 알림 읽음 처리 실패: $e');
    }
  }

  Future<void> _loadNotifications() async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final data = await _getNotifications(userId);
      setState(() {
        _notifications = data;
      });
    } catch (e) {
      debugPrint('❌ 알림 로딩 실패: $e');
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
      // 현재 사용자의 프로필 정보 가져오기
      final profileResponse = await client
          .from('profiles')
          .select('username')
          .eq('id', currentUserId)
          .single();
      
      final username = profileResponse['username'] as String;
      
      // follows 테이블에서 팔로워/팔로잉 수 계산
      final followerRes = await client
          .from('follows')
          .select('id')
          .eq('following_id', currentUserId);
      final followerCount = followerRes.length;

      final followingRes = await client
          .from('follows')
          .select('id')
          .eq('follower_id', currentUserId);
      final followingCount = followingRes.length;
      
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
    } catch (e) {
      debugPrint('❌ 프로필 정보 가져오기 실패: $e');
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

    if (notifType == 'post') {
      await client.from('notifications').delete().match({
        'recipient_id': userId,
        'type': 'post',
      });
    } else {
      await client.from('notifications').delete().eq('id', notification['id']);
    }

    _loadNotifications();
  }

  @override
  Widget build(BuildContext context) {
    final postSenders = <String>{};

    for (final n in _notifications) {
      if (n['type'] == 'post') {
        postSenders.add(n['sender']['id']);
      }
    }

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
          Expanded(
            child: ListView.builder(
              itemCount: _notifications.length,
              itemBuilder: (context, index) {
                final item = _notifications[index];
                final type = item['type'];
                final sender = item['sender'];
                final username = sender['username'];
                final notifId = item['id'];

                String content = '';
                if (type == 'follow') {
                  content = '$username님이 팔로우하기 시작했어요.';
                } else if (type == 'post') {
                  final totalSenders = postSenders.length;
                  if (totalSenders > 1) {
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