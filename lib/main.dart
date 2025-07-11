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

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
const bool isQA = bool.fromEnvironment('QA_MODE', defaultValue: false);

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    print('🔥 앱 시작');

    // 에러 핸들링 세팅
    FlutterError.onError = (FlutterErrorDetails details) {
      print('❌ Flutter 프레임워크 에러: ${details.exception}');
      print(details.stack);
    };

    try {
      await dotenv.load(fileName: ".env");
      print('✅ .env 로딩 완료');

      final supabaseUrl = dotenv.env['SUPABASE_URL'];
      final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

      print('🔍 SUPABASE_URL: $supabaseUrl');
      print('🔍 SUPABASE_ANON_KEY: ${supabaseAnonKey?.substring(0, 10)}...');

      if (supabaseUrl == null || supabaseAnonKey == null) {
        print('❌ .env 로딩 실패: 환경변수 없음');
        return;
      }

      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
        debug: true, // 👈 디버깅을 위해 추가
      );
      print('✅ Supabase 초기화 완료');
    } catch (e, s) {
      print('❌ Supabase 초기화 오류: $e');
      print(s);
      return;
    }

    try {
      final fragment = Uri.base.fragment;
      if (fragment.isNotEmpty) {
        final params = Uri.splitQueryString(fragment);
        final refreshToken = params['refresh_token'];
        if (refreshToken != null) {
          try {
            print('🔐 setSession 시작');
            final session = await Supabase.instance.client.auth.setSession(refreshToken);
            print('🔐 setSession 성공: ${session.user?.id}');
          } catch (e, s) {
            print('❌ setSession 실패: $e');
            print(s);
          }
        }
      }
    } catch (e, s) {
      print('❌ URI 파싱 실패: $e');
      print(s);
    }

    try {
      Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
        try {
          print('👤 AuthState 이벤트: ${data.event}');
          final session = data.session;

          if (data.event == AuthChangeEvent.signedIn && session != null) {
            final user = session.user;
            print('✅ 로그인된 유저: ${user.id}');

            final email = user.email;
            if (email != null) {
              print('🛡️ 차단 유저 검사 시작');
              try {
                final response = await Supabase.instance.client.functions.invoke(
                  'check_deleted_user',
                  body: {'email': email},
                );
                print('🛡️ 응답: ${response.data}');

                final data = response.data as Map<String, dynamic>;
                if (data['blocked'] == true) {
                  await Supabase.instance.client.auth.signOut();
                  navigatorKey.currentState?.pushReplacementNamed('/login_blocked');
                  print('🚫 차단 유저: 로그인 차단');
                  return;
                }
              } catch (e, s) {
                print('❌ 차단 유저 검사 오류: $e');
                print(s);
              }
            }
          }
        } catch (e, s) {
          print('❌ auth.onAuthStateChange 핸들러 내부 오류: $e');
          print(s);
        }
      });
    } catch (e, s) {
      print('❌ auth.onAuthStateChange listen 등록 실패: $e');
      print(s);
    }

    try {
      SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ));
      print('🎨 시스템 UI 설정 완료');
    } catch (e) {
      print('❌ System UI 설정 실패: $e');
    }

    print('🚀 runApp 시작');
    runApp(
      DevicePreview(
        enabled: isQA,
        builder: (context) => const ProviderScope(child: MyApp()),
      ),
    );
  }, (error, stack) {
    print('❌ Uncaught Zone Error: $error');
    print(stack);
  });
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
    print('🧩 MyApp initState 호출');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    print('🧹 MyApp dispose 호출');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print('🧱 MyApp build 호출');

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