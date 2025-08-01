import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:my_logue/core/widgets/common/common_outlined_button.dart';
import 'package:my_logue/presentation/screens/setting/inquiry/inquiry_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/themes/app_colors.dart';
import '../../../core/widgets/dialogs/delete_account_dialog.dart';
import '../../../core/widgets/dialogs/logout_dialog.dart';

class SettingScreen extends StatefulWidget {
  const SettingScreen({Key? key}) : super(key: key);

  @override
  State<SettingScreen> createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen> {
  void _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      debugPrint('❌ $url 열기 실패');
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('설정', style: TextStyle(fontSize: 16, color: AppColors.black900, fontWeight: FontWeight.w500,),),
        centerTitle: true,
        leading: IconButton(
          icon: SvgPicture.asset('assets/back_arrow.svg'),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: Column(
          children: [
            SizedBox(height: 26,),
            CommonOutlinedButton(text: "고객센터 / 소통", onTap : () {
              Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute(
                  builder: (_) => InquiryScreen(),
                ),
              );
            }),
            SizedBox(height: 20,),
            CommonOutlinedButton(text: "알림 설정"),
            SizedBox(height: 63,),
            CommonOutlinedButton(text: "법적 고지사항", onTap: () {
              _launchUrl('https://general-spatula-561.notion.site/2024e6fb980481589b15c74214c83718');
            }),
            SizedBox(height: 20,),
            CommonOutlinedButton(text: "로그아웃", onTap: () {
              showDialog(
                context: context,
                barrierDismissible: true,
                builder: (_) => LogoutDialog(
                  onConfirm: () async {
                    Navigator.pop(context); // 다이얼로그 닫기
                    try {
                      await Supabase.instance.client.auth.signOut();
                      if (mounted) {
                        Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
                      }
                    } catch (e) {
                      debugPrint('❌ 로그아웃 실패: $e');
                    }
                  },
                ),
              );

            },),
            SizedBox(height: 20,),
            CommonOutlinedButton(text: "계정탈퇴", onTap: () {
              showDialog(
                context: context,
                barrierDismissible: true,
                builder: (_) => DeleteAccountDialog(
                  onConfirm: () {
                    Navigator.pop(context); // 기존 다이얼로그 닫기
                    Navigator.pushNamed(context, '/delete_account_screen');
                  },
                ),
              );
            },),
          ],
        ),
      ),
    );
  }
}
