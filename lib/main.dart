import 'dart:async';
import 'dart:io' show Platform;

import 'package:device_preview/device_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:my_logue/presentation/routes/on_generate_route.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'core/themes/app_colors.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:my_logue/data/utils/mixpanel_util.dart';
import 'package:my_logue/data/services/analytics_session_service.dart';
import 'package:my_logue/data/services/book_activity_analytics_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:my_logue/data/utils/firebase_analytics_util.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
const bool isQA = bool.fromEnvironment('QA_MODE', defaultValue: true);

// AnalyticsSessionService 전역 인스턴스
final AnalyticsSessionService analyticsSessionService = AnalyticsSessionService();

void main() async {
  runZonedGuarded(() async {
  WidgetsFlutterBinding.ensureInitialized();

    // Firebase 초기화
    try {
      await Firebase.initializeApp();
      print('✅ Firebase 초기화 성공');
      
      // Firebase Analytics 설정
      try {
        final analytics = FirebaseAnalytics.instance;
        await analytics.setAnalyticsCollectionEnabled(true);
        print('✅ Firebase Analytics 설정 완료');
      } catch (e) {
        print('❌ Firebase Analytics 설정 실패: $e');
      }
    } catch (e) {
      print('❌ Firebase 초기화 실패: $e');
    }

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

      // 앱 시작 시 버전 정보 전송 (초기화 완료 후)
      try {
        final packageInfo = await PackageInfo.fromPlatform();
        final platform = Platform.isAndroid ? 'android' : Platform.isIOS ? 'ios' : 'unknown';
        final currentUser = Supabase.instance.client.auth.currentUser;
        
        await FirebaseAnalyticsUtil.logAppStart(
          appVersion: packageInfo.version,
          buildNumber: packageInfo.buildNumber,
          userId: currentUser?.id,
          platform: platform,
        );
        
        // 현재 사용자가 있으면 사용자 속성도 설정
        if (currentUser != null) {
          await FirebaseAnalyticsUtil.setUserProperties(
            appVersion: packageInfo.version,
            userId: currentUser.id,
          );
        }
        
        print('✅ 앱 시작 시 버전 정보 전송 완료: ${packageInfo.version} (${packageInfo.buildNumber})');
      } catch (e) {
        print('❌ 앱 시작 시 버전 정보 전송 실패: $e');
      }


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
            
            // Firebase Analytics 로그인 이벤트
            try {
              await FirebaseAnalytics.instance.logLogin(loginMethod: 'email');
              await FirebaseAnalytics.instance.setUserId(id: user.id);
              print('✅ Firebase Analytics 로그인 이벤트 전송 완료');
            } catch (e) {
              print('❌ Firebase Analytics 로그인 이벤트 전송 실패: $e');
            }
            
            // AnalyticsSessionService 시작 (DAU, WAU, MAU 수집)
            try {
              await analyticsSessionService.startSession(userId: user.id);
              
              // 사용자 정보 가져오기 및 설정 (직업만)
              try {
                final profileResponse = await Supabase.instance.client
                    .from('profiles')
                    .select('job')
                    .eq('id', user.id)
                    .single();
                
                await analyticsSessionService.setUserProperties(
                  job: profileResponse['job']?.toString(),
                  userId: user.id,
                );
                
                print('✅ 사용자 정보 설정 완료');
              } catch (e) {
                print('⚠️ 사용자 정보 설정 실패: $e');
              }
              
              // 앱 시작 이벤트 전송 (버전 정보 포함)
              try {
                final packageInfo = await PackageInfo.fromPlatform();
                final platform = Platform.isAndroid ? 'android' : Platform.isIOS ? 'ios' : 'unknown';
                
                await FirebaseAnalyticsUtil.logAppStart(
                  appVersion: packageInfo.version,
                  buildNumber: packageInfo.buildNumber,
                  userId: user.id,
                  platform: platform,
                );
                
                // 사용자 속성에도 앱 버전 설정
                await FirebaseAnalyticsUtil.setUserProperties(
                  appVersion: packageInfo.version,
                  userId: user.id,
                );
                
                print('✅ 앱 시작 이벤트 전송 완료');
              } catch (e) {
                print('❌ 앱 시작 이벤트 전송 실패: $e');
              }
              
              print('✅ AnalyticsSessionService 시작 완료');
            } catch (e) {
              print('❌ AnalyticsSessionService 시작 실패: $e');
            }
            

            
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
          } else if (data.event == AuthChangeEvent.signedOut) {
            // Firebase Analytics 로그아웃 이벤트
            try {
              await FirebaseAnalytics.instance.logEvent(name: 'user_logout');
              await FirebaseAnalytics.instance.setUserId(id: null);
              print('✅ Firebase Analytics 로그아웃 이벤트 전송 완료');
            } catch (e) {
              print('❌ Firebase Analytics 로그아웃 이벤트 전송 실패: $e');
            }
            
            // AnalyticsSessionService 종료
            try {
              await analyticsSessionService.endSession();
              print('✅ AnalyticsSessionService 종료 완료');
            } catch (e) {
              print('❌ AnalyticsSessionService 종료 실패: $e');
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
  
  // Firebase Analytics 앱 시작 이벤트
  try {
    await FirebaseAnalytics.instance.logAppOpen();
    print('✅ Firebase Analytics 앱 시작 이벤트 전송 완료');
    
    // 테스트 이벤트 전송
    await FirebaseAnalytics.instance.logEvent(
      name: 'app_initialized',
      parameters: {
        'timestamp': DateTime.now().toIso8601String(),
        'version': '1.1.7',
        'platform': Platform.isAndroid ? 'android' : 'ios',
      },
    );
    print('✅ Firebase Analytics 테스트 이벤트 전송 완료');
  } catch (e) {
    print('❌ Firebase Analytics 앱 시작 이벤트 전송 실패: $e');
  }
  
  Future.microtask(() async {
    await MixpanelUtil.initialize();
    // 책 활동 통계 서비스 초기화 및 미처리 통계 전송
    await BookActivityAnalyticsService.initializeAndSendPendingStatistics();
  });
}, (error, stack) {});

}

// last_seen_at 업데이트 함수
Future<void> updateLastSeenAt() async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return;

  try {
    await Supabase.instance.client
        .from('profiles')
        .update({'last_seen_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', user.id);
    print('✅ last_seen_at 업데이트 완료: ${user.id}');
  } catch (e) {
    print('❌ last_seen_at 업데이트 실패: $e');
  }
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
    // 앱 시작 시 한 번 업데이트
    _updateLastSeenAt();
  }
  Future<void> _updateLastSeenAt() async {
    await updateLastSeenAt();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _updateLastSeenAt();
      
      // 앱 포그라운드 진입 시 AnalyticsSessionService 시작
      try {
        final userId = Supabase.instance.client.auth.currentUser?.id;
        if (userId != null) {
          await analyticsSessionService.startSession(userId: userId);
          print('✅ 앱 포그라운드 진입 시 AnalyticsSessionService 시작');
        }
      } catch (e) {
        print('❌ 앱 포그라운드 진입 시 AnalyticsSessionService 시작 실패: $e');
      }
    } else if (state == AppLifecycleState.paused) {
      // 앱 백그라운드 진입 시 AnalyticsSessionService 종료
      try {
        await analyticsSessionService.endSession();
        print('✅ 앱 백그라운드 진입 시 AnalyticsSessionService 종료');
      } catch (e) {
        print('❌ 앱 백그라운드 진입 시 AnalyticsSessionService 종료 실패: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      useInheritedMediaQuery: isQA,
      locale: isQA ? DevicePreview.locale(context) : const Locale('ko', 'KR'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ko', 'KR'),
        Locale('en', 'US'),
      ],
      builder: (context, child) {
        // 시스템 글자 크기 설정을 무시하고 고정된 스케일 사용
        final mediaQuery = MediaQuery.of(context);
        final fixedMediaQuery = mediaQuery.copyWith(
          textScaleFactor: 1.0, // 고정된 텍스트 스케일
        );
        
        Widget result = MediaQuery(
          data: fixedMediaQuery,
          child: child!,
        );
        
        // QA 모드일 때만 DevicePreview 적용
        if (isQA) {
          result = DevicePreview.appBuilder(context, result);
        }
        
        return result;
      },
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      title: 'Logue',
      theme: ThemeData(
        dialogTheme: DialogThemeData(
          backgroundColor: AppColors.white500,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.white500,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: AppColors.black900,
          ),
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