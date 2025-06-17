import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:app_settings/app_settings.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logue/core/themes/app_colors.dart';
import 'package:logue/domain/usecases/get_notifications.dart';

import '../../../core/widgets/common/custom_app_bar.dart';

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
    WidgetsBinding.instance.addObserver(this); // 앱으로 복귀 시 권한 재확인
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkNotificationPermission(); // 앱으로 돌아왔을 때 권한 상태 재확인
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
          .eq('is_read', false); // 안 읽은 것만 true로
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
    Navigator.pushNamed(context, '/other_profile', arguments: senderId);
  }

  void _goToPost(String bookId) {
    Navigator.pushNamed(context, '/post_detail', arguments: {'bookId': bookId});
  }

  Future<void> _deleteNotification(String notificationId) async {
    await client.from('notifications').delete().eq('id', notificationId);
    _loadNotifications();
  }

  @override
  Widget build(BuildContext context) {
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
            padding: const EdgeInsets.symmetric(horizontal: 22.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '서비스 알림 수신 설정',
                  style: TextStyle(fontSize: 14, color: AppColors.black900),
                ),
                Transform.scale(
                  scale: 0.8,
                  child: Switch(
                    value: isNotificationOn,
                    onChanged: (_) {
                      AppSettings.openAppSettings();
                    },
                    activeColor: AppColors.white500,
                    activeTrackColor: AppColors.black900,
                    inactiveThumbColor: AppColors.black900,
                    inactiveTrackColor: AppColors.white500,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _notifications.isEmpty
                ? const Center(child: Text('친구를 팔로우해 서로의 인생 책을 공유해보세요.', style: TextStyle(color: AppColors.black500, fontSize: 12),))
                : ListView.builder(
              itemCount: _notifications.length,
              itemBuilder: (context, index) {
                final item = _notifications[index];
                final type = item['type'];
                final sender = item['sender'];
                final username = sender['username'];
                final bookId = item['book_id'];
                final notifId = item['id'];

                final content = type == 'follow'
                    ? '$username님이 팔로우하기 시작했어요.'
                    : '$username님이 새로운 인생 책을 추가했어요.';

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 22),
                  title: Text(
                    content,
                    style: const TextStyle(fontSize: 14, color: AppColors.black500),
                  ),
                  onTap: () {
                    if (type == 'follow') {
                      _goToProfile(sender['id']);
                    } else if (type == 'post' && bookId != null) {
                      _goToPost(bookId);
                    }
                  },
                  trailing: IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () => _deleteNotification(notifId),
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