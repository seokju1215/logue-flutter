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
    Future.delayed(const Duration(milliseconds: 1500), () {
      _checkSession();
    });
  }

  Future<void> _checkSession() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentSession?.user;

    if (user == null) {
      if (context.mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.pushReplacementNamed(context, '/login');
        });
      }
      return;
    }

    final profile = await client
        .from('profiles')
        .select('id')
        .eq('id', user.id)
        .maybeSingle();



    final hasAgreed = await AgreementRepository().hasAgreedTerms(user.id);
    if (!hasAgreed) {
      if (context.mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.pushReplacementNamed(context, '/terms');
        });
      }
      return;
    }
    final deletedUser = await client
        .from('deleted_users')
        .select('deleted_at')
        .eq('email', user.email)
        .maybeSingle();

    if (deletedUser != null) {
      final deletedAt = DateTime.parse(deletedUser['deleted_at']);
      final now = DateTime.now();

      if (now.difference(deletedAt).inDays < 30) {
        if (context.mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => const LoginScreen(blocked: true),
              ),
            );
          });
        }
        return;
      }
    }
    final books = await client
        .from('user_books')
        .select('id')
        .eq('user_id', user.id);

    if (context.mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (books.length < 3) {
          Navigator.pushReplacementNamed(context, '/select-3books');
        } else {
          Navigator.pushReplacementNamed(context, '/main');
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: SvgPicture.asset('assets/logue_logo_with_title.svg')),
    );
  }
}