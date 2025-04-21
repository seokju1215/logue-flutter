import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/themes/app_colors.dart';
import 'core/themes/text_theme.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'presentation/routes/app_routes.dart';
import 'package:logue/presentation/screens/signup/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
      authFlowType: AuthFlowType.pkce,
  );
  print('🌐 Supabase URL: ${dotenv.env['SUPABASE_URL']}');


  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Logue',
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.white500,
        textTheme: AppTextTheme.textTheme,
        useMaterial3: true,
      ),
      initialRoute: '/',  // ✅ 요거 추가해줘야 해!
      routes: appRoutes,
    );
  }
}