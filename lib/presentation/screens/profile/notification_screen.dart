import 'package:flutter/material.dart';
import 'package:logue/core/themes/app_colors.dart';
import 'package:logue/domain/usecases/get_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({Key? key}) : super(key: key);

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final client = Supabase.instance.client;
  late final GetNotifications _getNotifications;
  List<Map<String, dynamic>> _notifications = [];
  bool isNotificationOn = true;

  @override
  void initState() {
    super.initState();
    _getNotifications = GetNotifications(client);
    _loadNotifications();
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
        leading: BackButton(),
        title: const Text('알림'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          SwitchListTile(
            title: const Text('서비스 알림 수신 설정'),
            value: isNotificationOn,
            onChanged: (val) {
              setState(() {
                isNotificationOn = val;
              });
              // TODO: 실제 알림 권한 저장 로직
            },
          ),
          const Divider(height: 1),
          Expanded(
            child: _notifications.isEmpty
                ? const Center(child: Text('알림이 없습니다'))
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
                  title: Text(content, style: TextStyle(fontSize: 14, color: AppColors.black500),),
                  onTap: () {
                    if (type == 'follow') {
                      _goToProfile(sender['id']);
                    } else if (type == 'book_added' && bookId != null) {
                      _goToPost(bookId);
                    }
                  },
                  trailing: IconButton(
                    icon: const Icon(Icons.close, size: 16,),
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