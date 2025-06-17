import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:logue/core/themes/app_colors.dart';
import 'package:logue/core/widgets/profile_edit/edit_avatar_button.dart';
import 'package:logue/core/widgets/profile_edit/profile_link_tile.dart';
import 'package:logue/core/widgets/profile_edit/save_button.dart';
import 'package:logue/core/widgets/profile_edit/profile_edit_button.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logue/core/widgets/dialogs/logout_or_delete_dialog.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/widgets/dialogs/delete_account_dialog.dart';
import '../../../../core/widgets/dialogs/logout_dialog.dart';
import '../../../../data/utils/amplitude_util.dart';
import 'bio_edit.dart';

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

  void _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      debugPrint('❌ $url 열기 실패');
    }
  }

  void onSave() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    final oldProfile = widget.initialProfile;

    final oldUsername = oldProfile['username'] ?? '';
    final oldName = oldProfile['name'] ?? '';
    final oldJob = oldProfile['job'] ?? '';
    final oldBio = oldProfile['bio'] ?? '';
    final oldAvatarUrl = oldProfile['avatar_url'] ?? 'basic';

    try {
      await client.from('profiles').update({
        'username': username,
        'name': name,
        'job': job,
        'bio': bio,
        'avatar_url': avatarUrl,
      }).eq('id', userId);

      // ✅ 변경된 필드만 Amplitude 로그
      if (username != oldUsername) {
        AmplitudeUtil.log('profile_edited', props: {'field': 'username'});
      }
      if (name != oldName) {
        AmplitudeUtil.log('profile_edited', props: {'field': 'name'});
      }
      if (job != oldJob) {
        AmplitudeUtil.log('profile_edited', props: {'field': 'job'});
      }
      if (bio != oldBio) {
        AmplitudeUtil.log('profile_edited', props: {'field': 'bio'});
      }
      if (avatarUrl != oldAvatarUrl) {
        AmplitudeUtil.log('profile_edited', props: {'field': 'avatar'});
      }

      // 직업 태그 업데이트
      if (oldJob != job) {
        final res = await client.functions.invoke(
          'quick-endpoint',
          body: {
            'oldJob': oldJob,
            'newJob': job,
          },
        );
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

  @override
  Widget build(BuildContext context) {
    final profileLink = 'https://www.logue.it.kr/u/${username}';
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('프로필 편집', style: TextStyle(fontSize: 16, color: AppColors.black900),),
        centerTitle: true,
        actions: [SaveButton(enabled: isEdited, onPressed: onSave)],
        leading: IconButton(
          icon: SvgPicture.asset('assets/back_arrow.svg'),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
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
                  const SizedBox(height: 14),
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
                  const SizedBox(height: 14),
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
                  const SizedBox(height: 14),
                  ProfileEditButton(
                    label: '소개',
                    username: bio,
                    onTap: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BioEdit(currentBio: bio),
                        ),
                      );

                      if (result != null && result is Map<String, dynamic>) {
                        setState(() {
                          bio = result['bio'] ?? bio;
                          isEdited = true;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  ProfileLinkTile(link: profileLink),
                  const SizedBox(height: 38),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF9F9F9),
              ),
              child: Column(
                children: [
                  _buildMenuItem(context, '고객센터', () {
                    AmplitudeUtil.log('link_clicked', props: {
                      'type': 'customer_support',
                      'screen': 'profile_edit',
                    });
                    _launchUrl('https://general-spatula-561.notion.site/LOGUE-2024e6fb980480dfb0e8d5908dec40bb');
                  }),
                  _buildMenuItem(context, '법적 고지사항', () {
                    AmplitudeUtil.log('link_clicked', props: {
                      'type': 'legal_notice',
                      'screen': 'profile_edit',
                    });
                    _launchUrl('https://general-spatula-561.notion.site/2024e6fb980481589b15c74214c83718');
                  }),
                  _buildMenuItem(context, '로그아웃', () {
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

                  }),
                  _buildMenuItem(context, '계정 탈퇴', () {
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
                  }),
                  const SizedBox(height: 16),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 22),
                    child: Text(
                      '(주)로그퍼블릭은 개인정보 처리방침, 이용약관, 환불정책,\n사업자정보 등을 법적 고지사항 링크에서 통합하여 안내합니다.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: AppColors.black500),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildMenuItem(BuildContext context, String title, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title,
                style: const TextStyle(fontSize: 14, color: AppColors.black500)),
            const Icon(Icons.chevron_right, color: AppColors.black300),
          ],
        ),
      ),
    );
  }
}