import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:logue/core/themes/app_colors.dart';
import 'package:logue/core/widgets/profile_edit/edit_avatar_button.dart';
import 'package:logue/core/widgets/profile_edit/profile_link_tile.dart';
import 'package:logue/core/widgets/profile_edit/save_button.dart';
import 'package:logue/core/widgets/profile_edit/profile_edit_button.dart';

class ProfileEditScreen extends StatefulWidget {
  final Map<String, dynamic> initialProfile;
  const ProfileEditScreen({
    super.key,
    required this.initialProfile,
  });

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  late String username;
  late String avatarUrl;
  late String name;
  late String job;
  late String bio;
  bool isEdited = false;

  @override
  void initState() {
    super.initState();
    final profile = widget.initialProfile;

    username = profile['username'] ?? '';
    avatarUrl = profile['avatar_url'] ?? 'basic';
    name = profile['name'] ?? '';
    job = profile['job'] ?? '';
    bio = profile['bio'] ?? '';
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
    final profileLink = 'https://www.logue.it.kr_${username}';
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
            ProfileEditButton(
              label: '사용자 이름',
              username: username,
              onTap: () {
                Navigator.pushNamed(
                  context,
                  '/username_edit',
                  arguments: {
                    'username': username,
                  },
                );
              },
            ),
            ProfileEditButton(
              label: '이름',
              username: name,
              onTap: () {
                Navigator.pushNamed(
                  context,
                  '/name_edit',
                  arguments: {
                    'username': name,
                  },
                );
              },
            ),
            ProfileEditButton(
              label: '직업',
              username: job,
              onTap: () {
                Navigator.pushNamed(
                  context,
                  '/job_edit',
                  arguments: {
                    'username': job,
                  },
                );
              },
            ),
            ProfileEditButton(
              label: '소개',
              username: bio,
              onTap: () {
                Navigator.pushNamed(
                  context,
                  '/bio_edit',
                  arguments: {
                    'username': bio,
                  },
                );
              },
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