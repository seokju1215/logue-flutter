import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:my_logue/core/widgets/common/common_outlined_button.dart';

import '../../../core/themes/app_colors.dart';

class SettingScreen extends StatefulWidget {
  const SettingScreen({Key? key}) : super(key: key);

  @override
  State<SettingScreen> createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen> {
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
            CommonOutlinedButton(text: "고객센터 / 소통"),
            SizedBox(height: 20,),
            CommonOutlinedButton(text: "알림 설정"),
          ],
        ),
      ),
    );
  }
}
