import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:my_logue/core/themes/app_colors.dart';
import 'package:my_logue/core/widgets/profile_edit/edit_avatar_button.dart';
import 'package:my_logue/core/widgets/profile_edit/profile_link_tile.dart';
import 'package:my_logue/core/widgets/profile_edit/save_button.dart';
import 'package:my_logue/core/widgets/profile_edit/profile_edit_button.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_logue/core/widgets/dialogs/logout_or_delete_dialog.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../data/utils/firebase_analytics_util.dart';

import '../../../../core/widgets/dialogs/delete_account_dialog.dart';
import '../../../../core/widgets/dialogs/logout_dialog.dart';
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
  bool _isSaving = false; // 저장 중 중복 실행 방지
  File? tempAvatarFile; // 임시 아바타 파일

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
    // 이미 저장 중이면 중복 실행 방지
    if (_isSaving) {
      debugPrint('⚠️ 저장 중입니다. 중복 실행 방지');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      setState(() {
        _isSaving = false;
      });
      return;
    }

    final oldProfile = widget.initialProfile;

    final oldUsername = oldProfile['username'] ?? '';
    final oldName = oldProfile['name'] ?? '';
    final oldJob = oldProfile['job'] ?? '';
    final oldBio = oldProfile['bio'] ?? '';
    final oldAvatarUrl = oldProfile['avatar_url'] ?? 'basic';

    try {
      String finalAvatarUrl = avatarUrl;
      
      // 임시 아바타 파일이 있으면 Storage에 업로드
      if (tempAvatarFile != null) {
        try {
          final fileBytes = await tempAvatarFile!.readAsBytes();
          final fileName = tempAvatarFile!.path.split('/').last;
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final extension = fileName.split('.').last.toLowerCase();
          final uniqueFileName = 'avatar_$timestamp.$extension';
          final storagePath = 'avatars/$userId/$uniqueFileName';
          
          debugPrint('📸 Storage 업로드 시작: $storagePath');
          await client.storage.from('avatars').uploadBinary(
            storagePath,
            fileBytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: 'image/$extension',
            ),
          );
          
          final publicUrl = client.storage.from('avatars').getPublicUrl(storagePath);
          finalAvatarUrl = publicUrl;
          debugPrint('📸 Storage 업로드 완료: $publicUrl');
        } catch (e) {
          debugPrint('❌ 아바타 Storage 업로드 실패: $e');
          // Storage 업로드 실패 시 기존 아바타 유지
          finalAvatarUrl = oldAvatarUrl;
        }
      }
      
      // 프로필 업데이트
      await client.from('profiles').update({
        'username': username,
        'name': name,
        'job': job,
        'bio': bio,
        'avatar_url': finalAvatarUrl,
      }).eq('id', userId);

      // Firebase Analytics: 사용자 이름 변경 추적
      if (oldUsername != username) {
        try {
          debugPrint('🚀🚀🚀 사용자 이름 변경 이벤트 전송 시도');
          await FirebaseAnalyticsUtil.logUsernameChange(
            oldUsername: oldUsername,
            newUsername: username,
            userId: userId,
          );
          debugPrint('🎯🎯🎯 사용자 이름 변경 이벤트 전송 완료');
        } catch (analyticsError) {
          debugPrint('❌ 사용자 이름 변경 이벤트 전송 실패: $analyticsError');
        }
      }

      // Firebase Analytics: 프로필 사진 변경 추적
      if (oldAvatarUrl != finalAvatarUrl) {
        try {
          String changeType = 'unknown';
          if (finalAvatarUrl == 'basic') {
            changeType = 'remove';
          } else if (tempAvatarFile != null) {
            changeType = 'upload';
          } else {
            changeType = 'select_preset';
          }
          
          debugPrint('🚀🚀🚀 프로필 사진 변경 이벤트 전송 시도');
          await FirebaseAnalyticsUtil.logProfilePhotoChange(
            userId: userId,
            oldAvatarUrl: oldAvatarUrl,
            newAvatarUrl: finalAvatarUrl,
            changeType: changeType,
          );
          debugPrint('🎯🎯🎯 프로필 사진 변경 이벤트 전송 완료');
        } catch (analyticsError) {
          debugPrint('❌ 프로필 사진 변경 이벤트 전송 실패: $analyticsError');
        }
      }

      // 직업 태그 업데이트 (직업이 변경된 경우에만)
      if (oldJob != job && job.isNotEmpty) {
        try {
          final res = await client.functions.invoke(
            'quick-endpoint',
            body: {
              'oldJob': oldJob,
              'newJob': job,
            },
          );
          if (res.status != 200) {
            debugPrint('⚠️ 직업 태그 업데이트 실패: ${res.status}');
          }
        } catch (e) {
          debugPrint('⚠️ 직업 태그 업데이트 중 에러: $e');
          // 직업 태그 업데이트 실패는 전체 프로필 저장을 막지 않음
        }
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('❌ 프로필 저장 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('프로필 저장에 실패했어요. 다시 시도해주세요.'),
            backgroundColor: AppColors.red500,
          ),
        );
      }
    } finally {
      // 저장 완료 또는 실패 후 상태 초기화
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileLink = 'https://www.logue.it.kr/u/${username}';
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('프로필 편집', style: TextStyle(fontSize: 16, color: AppColors.black900, fontWeight: FontWeight.w500,),),
        centerTitle: true,
        actions: [SaveButton(enabled: isEdited && !_isSaving, onPressed: _isSaving ? null : onSave)],
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
                    tempImageFile: tempAvatarFile,
                    onAvatarChanged: (url, tempFile) {
                      setState(() {
                        avatarUrl = url;
                        tempAvatarFile = tempFile;
                        isEdited = true;
                      });
                    },
                  ),
                  const SizedBox(height: 24),
                  ProfileEditButton(
                    label: '사용자 이름',
                    username: username,
                    onTap: () async {
                      try {
                        final result = await Navigator.pushNamed(
                          context,
                          '/username_edit',
                          arguments: {'username': username},
                        );

                        if (result != null && result is Map<String, dynamic>) {
                          if (mounted) {
                            setState(() {
                              username = result['username'] ?? username;
                              isEdited = true;
                            });
                          }
                        }
                      } catch (e) {
                        debugPrint('❌ 사용자 이름 편집 오류: $e');
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  ProfileEditButton(
                    label: '이름',
                    username: name,
                    onTap: () async {
                      try {
                        final result = await Navigator.pushNamed(
                          context,
                          '/name_edit',
                          arguments: {'currentName': name},
                        );

                        if (result != null && result is Map<String, dynamic>) {
                          if (mounted) {
                            setState(() {
                              name = result['name'] ?? name;
                              isEdited = true;
                            });
                          }
                        }
                      } catch (e) {
                        debugPrint('❌ 이름 편집 오류: $e');
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  ProfileEditButton(
                    label: '직업',
                    username: job,
                    onTap: () async {
                      try {
                        final result = await Navigator.pushNamed(
                          context,
                          '/job_edit',
                          arguments: {'currentJob': job},
                        );

                        if (result != null && result is Map<String, dynamic>) {
                          if (mounted) {
                            setState(() {
                              job = result['job'] ?? job;
                              isEdited = true;
                            });
                          }
                        }
                      } catch (e) {
                        debugPrint('❌ 직업 편집 오류: $e');
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  ProfileEditButton(
                    label: '소개',
                    username: bio,
                    onTap: () async {
                      try {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BioEdit(currentBio: bio),
                          ),
                        );

                        if (result != null && result is Map<String, dynamic>) {
                          if (mounted) {
                            setState(() {
                              bio = result['bio'] ?? bio;
                              isEdited = true;
                            });
                          }
                        }
                      } catch (e) {
                        debugPrint('❌ 소개 편집 오류: $e');
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  ProfileLinkTile(link: profileLink),
                  const SizedBox(height: 33),
                ],
              ),
            ),
            Container(
              height: 1,
              width: double.infinity,
              color: AppColors.black300,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(35, 0, 26, 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '내 프로필에 전체 책장 표시',
                    style: TextStyle(fontSize: 14, color: AppColors.black900),
                  ),
                  Transform.scale(
                    scale: 0.8,
                    child: Switch(
                      value: true,
                      onChanged: (_) {
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