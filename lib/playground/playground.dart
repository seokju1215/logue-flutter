import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logue/presentation/screens/main_navigation_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ .env 로드
  await dotenv.load(fileName: ".env");

  // ✅ Supabase 초기화
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
    authFlowType: AuthFlowType.pkce,
  );

  // ✅ 앱 실행
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: MainNavigationScreen(),
  ));
}