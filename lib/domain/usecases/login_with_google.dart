import 'dart:io';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logue/data/utils/amplitude_util.dart'; // ✅ 너가 만든 유틸
import 'package:logue/data/utils/update_check_util.dart'; // 앱 버전도 유저 속성에 넣기 위해

class LoginWithGoogle {
  final SupabaseClient client;

  LoginWithGoogle(this.client);

  Future<void> call(BuildContext context) async {
    try {
      await client.auth.signOut(); // 혹시 이전 세션 꼬였을 경우를 대비

      await client.auth.signInWithOAuth(
        Provider.google,
        redirectTo: 'dev.seokju.logue://login-callback',
      );

      final session = client.auth.currentSession;
      final user = session?.user;
      final email = user?.email;

      if (email != null) {
        // ✅ 차단된 유저 검사
        final response = await client.functions.invoke(
          'check_deleted_user',
          body: {'email': email},
        );

        final data = response.data as Map<String, dynamic>;
        if (data['blocked'] == true) {
          await client.auth.signOut();
          if (context.mounted) {
            Navigator.pushReplacementNamed(context, '/login_blocked');
          }
          return;
        }

        // ✅ 유저 속성 세팅
        final profile = await client
            .from('profiles')
            .select('username, full_name, job, created_at')
            .eq('id', user!.id)
            .maybeSingle();

        final appVersion = await UpdateCheckUtil.getCurrentAppVersion();

        AmplitudeUtil.setUserId(user.id);
        AmplitudeUtil.setUserProperties({
          'email': email,
          'platform': Platform.isIOS ? 'iOS' : 'Android',
          'app_version': appVersion,
          if (profile != null) ...{
            'username': profile['username'],
            'full_name': profile['full_name'],
            'job': profile['job'],
            'joined_at': profile['created_at'],
          },
        });

        // ✅ 로그인 or 회원가입 구분
        if (profile == null || profile.isEmpty) {
          AmplitudeUtil.log('sign_up', props: {
            'method': 'google',
            'user_id': user.id,
            'email': email,
          });
        } else {
          AmplitudeUtil.log('login', props: {
            'method': 'google',
            'user_id': user.id,
            'email': email,
          });
        }
      }

      // ✅ 통과한 사용자만 splash로 이동
      if (context.mounted) {
        Navigator.pushReplacementNamed(context, '/splash');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('로그인 중 오류 발생: $e')),
        );
      }
    }
  }
}