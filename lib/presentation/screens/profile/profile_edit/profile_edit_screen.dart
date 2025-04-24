import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:logue/core/themes/app_colors.dart';
import 'package:logue/core/widgets/profile_edit/edit_avatar_button.dart';
import 'package:logue/core/widgets/profile_edit/profile_text_field.dart';
import 'package:logue/core/widgets/profile_edit/profile_link_tile.dart';
import 'package:logue/core/widgets/profile_edit/save_button.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController jobController = TextEditingController();
  final TextEditingController bioController = TextEditingController();
  String avatarUrl = 'basic';
  bool isEdited = false;

  @override
  void initState() {
    super.initState();
    // TODO: 초기 데이터 불러오기
  }

  void onValueChanged() {
    setState(() => isEdited = true);
  }

  void onSave() {
    // TODO: Supabase에 저장
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final profileLink = 'https://www.logue.it.kr_${usernameController.text}';
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('프로필 편집'),
        centerTitle: true,
        actions: [SaveButton(enabled: isEdited, onPressed: onSave)],
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 24),
            EditAvatarButton(
              avatarUrl: avatarUrl,
              onAvatarChanged: (url) {
                setState(() {
                  avatarUrl = url;
                  isEdited = true;
                });
              },
            ),
            const SizedBox(height: 24),
            ProfileTextField(
              label: '사용자 이름',
              controller: usernameController,
              onChanged: (_) => onValueChanged(),
            ),
            ProfileTextField(
              label: '이름',
              controller: nameController,
              onChanged: (_) => onValueChanged(),
            ),
            ProfileTextField(
              label: '직업',
              controller: jobController,
              onChanged: (_) => onValueChanged(),
            ),
            ProfileTextField(
              label: '소개',
              controller: bioController,
              onChanged: (_) => onValueChanged(),
              maxLines: 1,
            ),
            const SizedBox(height: 12),
            ProfileLinkTile(link: profileLink),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () {}, // TODO: 로그아웃
              child: const Text('로그아웃'),
            ),
            TextButton(
              onPressed: () {}, // TODO: 계정탈퇴
              child: const Text('계정탈퇴'),
            ),
          ],
        ),
      ),
    );
  }
}