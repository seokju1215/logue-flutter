import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/themes/app_colors.dart';
import 'core/themes/text_theme.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'presentation/routes/app_routes.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
    authFlowType: AuthFlowType.pkce,
  );

  // ✅ onAuthStateChange: 앱 전체에서 단 한 번만 등록
  Supabase.instance.client.auth.onAuthStateChange.listen((data) {
    final event = data.event;
    final session = data.session;

    if (event == AuthChangeEvent.signedIn && session != null) {
      navigatorKey.currentState?.pushReplacementNamed('/splash');
    }
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Logue',
      theme: ThemeData(
        appBarTheme: const AppBarTheme(backgroundColor: AppColors.white500),
        scaffoldBackgroundColor: AppColors.white500,
        textTheme: AppTextTheme.textTheme,
        useMaterial3: true,
      ),
      initialRoute: '/splash',
      routes: appRoutes,
    );
  }
}