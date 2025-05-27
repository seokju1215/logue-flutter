import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:logue/core/themes/app_colors.dart';
import 'package:logue/core/widgets/profile_edit/edit_avatar_button.dart';
import 'package:logue/core/widgets/profile_edit/profile_link_tile.dart';
import 'package:logue/core/widgets/profile_edit/save_button.dart';
import 'package:logue/core/widgets/profile_edit/profile_edit_button.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logue/core/widgets/dialogs/logout_or_delete_dialog.dart';

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

  void onSave() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    final oldJob = widget.initialProfile['job'] ?? '';

    try {
      // 프로필 업데이트
      await client.from('profiles').update({
        'username': username,
        'name': name,
        'job': job,
        'bio': bio,
        'avatar_url': avatarUrl,
      }).eq('id', userId);

      // job이 변경되었을 경우 job_tags 업데이트
      if (oldJob != job) {
        final res = await client.functions.invoke(
          'quick-endpoint',
          body: {
            'oldJob': oldJob,
            'newJob': job,
          },
        );
        debugPrint('📡 Supabase 함수 호출 결과 status: ${res.status}');
        debugPrint('📡 Supabase 함수 호출 결과 data: ${res.data}');
        if (res.status != 200) {
          throw Exception('직업 태그 업데이트 실패');
        }
      }

      if (mounted) {

        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('프로필 저장 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('프로필 저장에 실패했어요. 다시 시도해주세요.')),
        );
      }
    }
  }
  void _deleteAccount() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;

    if (userId == null) return;

    final res = await client.functions.invoke('delete_account', body: {
      'userId': userId,
    });

    debugPrint('📡 계정 삭제 결과: ${res.status}, ${res.data}');

    if (res.status == 200 && res.data['success'] == true) {
      try {
        await client.auth.signOut();
      } catch (e) {
        debugPrint('🔴 로그아웃 실패 (이미 계정 삭제된 상태일 수 있음): $e');
      }

      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('계정 삭제에 실패했습니다.')),
      );
    }
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
              onTap: () async {
                final result = await Navigator.pushNamed(
                  context,
                  '/username_edit',
                  arguments: {'username': username},
                );

                if (result != null && result is Map<String, dynamic>) {
                  setState(() {
                    username = result['username'] ?? username;
                    isEdited = true;
                  });
                }
              },
            ),
            const SizedBox(height: 25),
            ProfileEditButton(
              label: '이름',
              username: name,
              onTap: () async {
                final result = await Navigator.pushNamed(
                  context,
                  '/name_edit',
                  arguments: {'currentName': name}, // ✅ 올바른 키
                );

                if (result != null && result is Map<String, dynamic>) {
                  setState(() {
                    name = result['name'] ?? name;
                    isEdited = true;
                  });
                }
              },
            ),
            const SizedBox(height: 25),
            ProfileEditButton(
              label: '직업',
              username: job,
              onTap: () async {
                final result = await Navigator.pushNamed(
                  context,
                  '/job_edit',
                  arguments: {'username': job},
                );

                if (result != null && result is Map<String, dynamic>) {
                  setState(() {
                    job = result['job'] ?? job;
                    isEdited = true;
                  });
                }
              },
            ),
            const SizedBox(height: 25),
            ProfileEditButton(
              label: '소개',
              username: bio,
              onTap: () async {
                final result = await Navigator.pushNamed(
                  context,
                  '/bio_edit',
                  arguments: {'currentBio': bio},
                );

                if (result != null && result is Map<String, dynamic>) {
                  setState(() {
                    bio = result['bio'] ?? bio;
                    isEdited = true;
                  });
                }
              },
            ),
            const SizedBox(height: 27),
            ProfileLinkTile(link: profileLink),
            const SizedBox(height: 30),
            Center(
              child: Text("링크를 공유하여 당신의 책장을 보여주세요.", style: TextStyle(fontSize: 14, color: AppColors.black500),),
            ),
            const SizedBox(height: 45),
            TextButton(
              onPressed: () => showLogoutOrDeleteDialog(context),
              child: const Text('로그아웃 | 계정탈퇴'),
            )
          ],
        ),
      ),
    );
  }
}