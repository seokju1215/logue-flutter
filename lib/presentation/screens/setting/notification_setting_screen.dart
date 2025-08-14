
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:app_settings/app_settings.dart';
import '../../../core/themes/app_colors.dart';

class NotificationSettingScreen extends StatefulWidget {
  const NotificationSettingScreen({Key? key}) : super(key: key);
  @override
  State<NotificationSettingScreen> createState() => _NotificationSettingScreenState();
}

class _NotificationSettingScreenState extends State<NotificationSettingScreen> {
  bool isNotificationOn = true;

  Future<void> _checkNotificationPermission() async {
    final status = await Permission.notification.status;
    setState(() {
      isNotificationOn = status.isGranted;
    });
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
        ],
      ),
    );
  }
}
