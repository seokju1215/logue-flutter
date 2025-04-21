import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logue/data/repositories/agreement_repository.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    final client = Supabase.instance.client;

    client.auth.onAuthStateChange.listen((data) async {
      if (data.event == AuthChangeEvent.signedIn) {
        await _checkSession();
      }
    });

    // ✅ 기존 세션이 있다면 바로 확인
    final session = client.auth.currentSession;
    if (session != null) {
      _checkSession();
    }
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

    final profile = await client
        .from('profiles')
        .select('id')
        .eq('id', user.id)
        .maybeSingle();

    if (profile == null) {
      // ➕ 프로필이 없다면 작성 유도 (여기선 select-3books부터 시작한다고 가정)
      if (context.mounted) {
        Navigator.pushReplacementNamed(context, '/select-3books');
      }
      return;
    }

    final hasAgreed = await AgreementRepository().hasAgreedTerms(user.id);
    if (!hasAgreed) {
      if (context.mounted) {
        Navigator.pushReplacementNamed(context, '/terms');
      }
      return;
    }

    final books = await client
        .from('user_books')
        .select('id')
        .eq('user_id', user.id);

    if (context.mounted) {
      if (books.length < 3) {
        Navigator.pushReplacementNamed(context, '/select-3books');
      } else {
        Navigator.pushReplacementNamed(context, '/profile');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}