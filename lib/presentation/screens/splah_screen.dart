import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logue/data/repositories/agreement_repository.dart';
import 'package:logue/presentation/screens/signup/login_screen.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _startSplashFlow();
  }

  Future<void> _startSplashFlow() async {
    await Future.delayed(const Duration(milliseconds: 1500));
    await _checkSession(); // ✅ 지연 후 체크 수행
  }

  Future<void> _checkSession() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentSession?.user;

    if (user == null) {
      if (context.mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
      return;
    }

    // 프로필 존재 확인
    final profile = await client
        .from('profiles')
        .select('id')
        .eq('id', user.id)
        .maybeSingle();

    if (profile == null || profile.isEmpty) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
    }

    // 약관 동의 여부 확인
    final hasAgreed = await AgreementRepository().hasAgreedTerms(user.id);
    if (!hasAgreed) {
      if (context.mounted) {
        Navigator.pushReplacementNamed(context, '/terms');
      }
      return;
    }

    // 탈퇴 유저 확인
    final deletedUser = await client
        .from('deleted_users')
        .select('deleted_at')
        .eq('email', user.email)
        .maybeSingle();

    if (deletedUser != null && deletedUser.isNotEmpty) {
      final deletedAt = DateTime.parse(deletedUser['deleted_at']);
      final now = DateTime.now();

      if (now.difference(deletedAt).inDays < 30) {
        if (context.mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => const LoginScreen(blocked: true),
            ),
          );
        }
        return;
      }
    }

    Navigator.pushReplacementNamed(context, '/main');

    // 책 3권 선택 여부 확인
    // final books = await client
    //     .from('user_books')
    //     .select('id')
    //     .eq('user_id', user.id);
    //
    // if (context.mounted) {
    //   if (books.length < 3) {
    //     Navigator.pushReplacementNamed(context, '/select-3books');
    //   } else {
    //     Navigator.pushReplacementNamed(context, '/main');
    //   }
    // }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: SvgPicture.asset('assets/logue_logo_with_title.svg')),
    );
  }
}