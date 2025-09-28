import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:my_logue/data/repositories/agreement_repository.dart';
import 'package:my_logue/presentation/screens/signup/login_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io' show Platform;
import '../../data/utils/update_check_util.dart';
import '../../data/utils/firebase_analytics_util.dart';
import '../../data/services/analytics_session_service.dart';

class SplashScreen extends StatefulWidget {
  final String? refreshToken;
  const SplashScreen({super.key, this.refreshToken});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // 앱 시작 트래킹
        FirebaseAnalyticsUtil.logAppOpen();
    _startSplashFlow();
  }

  Future<void> _startSplashFlow() async {
    await Future.delayed(const Duration(milliseconds: 1500));
    if (widget.refreshToken != null) {
      debugPrint('[SplashScreen] refreshToken으로 세션 복구 시도: ${widget.refreshToken}');
      await Supabase.instance.client.auth.setSession(widget.refreshToken!);
    }
    await _checkSession(); // ✅ 세션 복구 후 체크 수행
  }

  Future<void> _checkSession() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentSession?.user;
    debugPrint('[SplashScreen] currentSession: \\${client.auth.currentSession}');
    debugPrint('[SplashScreen] user: \\${user}');

    if (user == null) {
      debugPrint('[SplashScreen] 세션 없음 → 로그인 화면으로 이동');
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    // 탈퇴 확인
    final deletedUser = await client
        .from('deleted_users')
        .select('deleted_at')
        .eq('email', user.email!)
        .maybeSingle();
    debugPrint('🧪 삭제된 유저 검사: email = ${user.email}, deletedUser = $deletedUser');

    if (!mounted) return;

    if (deletedUser != null && deletedUser.isNotEmpty) {
      final deletedAt = DateTime.parse(deletedUser['deleted_at']);
      final now = DateTime.now();

      if (now.difference(deletedAt).inDays < 14) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const LoginScreen(blocked: true),
          ),
        );
        return;
      }
    }

    // 프로필 존재 확인
    final profile = await client
        .from('profiles')
        .select('id, username, job, created_at')
        .eq('id', user.id)
        .maybeSingle();

    if (!mounted) return;

    // 약관 동의 여부 확인
    debugPrint('🔍 약관 동의 여부 확인 시작 - userId: ${user.id}');
    final hasAgreed = await AgreementRepository().hasAgreedTerms(user.id);
    debugPrint('🔍 약관 동의 여부 확인 결과: $hasAgreed');

    if (!mounted) {
      debugPrint('❌ context가 mounted 상태가 아닙니다');
      return;
    }

    if (!hasAgreed) {
      debugPrint('🔍 약관 동의하지 않음 - /terms 화면으로 이동');
      Navigator.pushReplacementNamed(context, '/terms');
      return;
    } else {
      debugPrint('🔍 약관 동의 완료 - 다음 단계로 진행');
      
      // last_seen_at 업데이트
      try {
        await client
            .from('profiles')
            .update({'last_seen_at': DateTime.now().toUtc().toIso8601String()})
            .eq('id', user.id);
        debugPrint('✅ last_seen_at 업데이트 완료: ${user.id}');
      } catch (e) {
        debugPrint('❌ last_seen_at 업데이트 실패: $e');
      }
    }

    // 책 3권 선택 여부 확인
    final books = await client
        .from('user_books')
        .select('id')
        .eq('user_id', user.id);

    if (!mounted) return;

    if (profile == null || profile.isEmpty) {
      Navigator.pushReplacementNamed(context, '/select-3books');
    } else {
      if (profile != null) {
        // 사용자 속성은 FirebaseAnalyticsUtil에서 자동으로 처리됨
        
        // AnalyticsSessionService 시작 (DAU, WAU, MAU 수집)
        try {
          final analyticsService = AnalyticsSessionService();
          await analyticsService.startSession(userId: user.id);
          
          // 사용자 정보 설정 (직업만 설정, 나이/성별은 제외)
          await analyticsService.setUserProperties(
            job: profile['job']?.toString(),
            userId: user.id,
          );
          
          debugPrint('✅ SplashScreen에서 AnalyticsSessionService 시작 및 사용자 정보 설정 완료');
        } catch (e) {
          debugPrint('❌ SplashScreen에서 AnalyticsSessionService 시작 실패: $e');
        }
      }

      Navigator.pushNamedAndRemoveUntil(context, '/main', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: SvgPicture.asset('assets/logue_logo_splash.svg')),
    );
  }
}