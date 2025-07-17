import 'dart:async';
import 'dart:io' show Platform;

import 'package:device_preview/device_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_logue/presentation/routes/on_generate_route.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/themes/app_colors.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:my_logue/data/utils/att_permission_util.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
const bool isQA = bool.fromEnvironment('QA_MODE', defaultValue: false);

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    try {
      await dotenv.load(fileName: ".env");

      final supabaseUrl = dotenv.env['SUPABASE_URL'];
      final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

      if (supabaseUrl == null || supabaseAnonKey == null) {
        return;
      }

      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
        debug: true,
      );

      // iOS에서 ATT 권한 요청
      await ATTPermissionUtil.requestTrackingPermission();
    } catch (e, s) {
      return;
    }

    try {
      final fragment = Uri.base.fragment;
      if (fragment.isNotEmpty) {
        final params = Uri.splitQueryString(fragment);
        final refreshToken = params['refresh_token'];
        if (refreshToken != null) {
          try {
            await Supabase.instance.client.auth.setSession(refreshToken);
          } catch (e, s) {}
        }
      }
    } catch (e, s) {}

    try {
      Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
        try {
          final session = data.session;

          if (data.event == AuthChangeEvent.signedIn && session != null) {
            final user = session.user;
            final email = user.email;
            if (email != null) {
              try {
                final response = await Supabase.instance.client.functions.invoke(
                  'check_deleted_user',
                  body: {'email': email},
                );
                final data = response.data as Map<String, dynamic>;
                if (data['blocked'] == true) {
                  await Supabase.instance.client.auth.signOut();
                  navigatorKey.currentState?.pushReplacementNamed('/login_blocked');
                  return;
                }
              } catch (e, s) {}
            }
          }
        } catch (e, s) {}
      });
    } catch (e, s) {}

    try {
      SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ));
    } catch (e) {}

    runApp(
      DevicePreview(
        enabled: isQA,
        builder: (context) => const ProviderScope(child: MyApp()),
      ),
    );
  }, (error, stack) {});
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      useInheritedMediaQuery: isQA,
      locale: isQA ? DevicePreview.locale(context) : null,
      builder: isQA ? DevicePreview.appBuilder : null,
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      title: '로그',
      theme: ThemeData(
        dialogTheme: DialogThemeData(
          backgroundColor: AppColors.white500,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.white500,
          surfaceTintColor: Colors.transparent,
        ),
        scaffoldBackgroundColor: AppColors.white500,
        canvasColor: AppColors.white500,
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppColors.white500,
          elevation: 0,
        ),
        textTheme: GoogleFonts.interTextTheme().apply(
          bodyColor: AppColors.black900,
          displayColor: AppColors.black900,
        ),
        textButtonTheme: TextButtonThemeData(
          style: ButtonStyle(
            overlayColor: MaterialStateProperty.all(Colors.transparent),
            splashFactory: NoSplash.splashFactory,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: ButtonStyle(
            overlayColor: MaterialStateProperty.all(Colors.transparent),
            splashFactory: NoSplash.splashFactory,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ButtonStyle(
            overlayColor: MaterialStateProperty.all(Colors.transparent),
            splashFactory: NoSplash.splashFactory,
          ),
        ),
        useMaterial3: true,
      ),
      initialRoute: '/splash',
      onGenerateRoute: onGenerateRoute,
    );
  }
}