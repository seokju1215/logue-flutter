import 'dart:io' show Platform;
import 'package:device_preview/device_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logue/presentation/routes/on_generate_route.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/themes/app_colors.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'data/utils/fcm_token_util.dart';
import 'data/utils/mixpanel_util.dart';
import 'package:flutter/services.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
const bool isQA = bool.fromEnvironment('QA_MODE', defaultValue: false);

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('📩 백그라운드 메시지 수신: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await dotenv.load(fileName: ".env");

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  // Mixpanel 초기화
  await MixpanelUtil.initialize();


  final fragment = Uri.base.fragment;
  if (fragment.isNotEmpty) {
    final params = Uri.splitQueryString(fragment);
    final refreshToken = params['refresh_token'];
    if (refreshToken != null) {
      final session = await Supabase.instance.client.auth.setSession(refreshToken);
      print('[로그인] setSession 결과: $session');
      print('[로그인] setSession 후 currentSession: \\${Supabase.instance.client.auth.currentSession}');
    }
  }

  final currentUserId = Supabase.instance.client.auth.currentUser?.id ?? 'anonymous';

  FcmTokenUtil.listenTokenRefresh();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  final messaging = FirebaseMessaging.instance;
  bool _isRequestingPermission = false;

  Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
    final event = data.event;
    final session = data.session;

        if (event == AuthChangeEvent.signedIn && session != null) {
      final user = session.user;
      final email = user.email;
      
      // Mixpanel 사용자 식별
      MixpanelUtil.identify(user.id);
      MixpanelUtil.trackLogin('google');

      if (email != null) {
        // 차단된 유저 검사
        try {
          final response = await Supabase.instance.client.functions.invoke(
            'check_deleted_user',
            body: {'email': email},
          );

          final responseData = response.data as Map<String, dynamic>;
          if (responseData['blocked'] == true) {
            await Supabase.instance.client.auth.signOut();
            navigatorKey.currentState?.pushReplacementNamed('/login_blocked');
            return;
          }
        } catch (e) {
          print('❌ 차단된 유저 검사 중 오류: $e');
        }
      }

      if (!_isRequestingPermission) {
        _isRequestingPermission = true;

        try {
          final settings = await FirebaseMessaging.instance.requestPermission();
          print('🔧 알림 권한 상태: ${settings.authorizationStatus}');

          if (Platform.isIOS) {
            String? apnsToken;
            int retryCount = 0;
            const maxRetries = 10;

            while (apnsToken == null && retryCount < maxRetries) {
              await Future.delayed(const Duration(milliseconds: 500));
              apnsToken = await FirebaseMessaging.instance.getAPNSToken();
              retryCount++;
            }

            if (apnsToken == null) {
              print('⚠️ APNs 토큰을 가져오지 못했습니다.');
            } else {
              print('📲 APNs 토큰: $apnsToken');
            }
          }

          final fcmToken = await FirebaseMessaging.instance.getToken();
          print('📱 FCM 토큰: $fcmToken');
          await FcmTokenUtil.updateFcmToken();
        } catch (e) {
          print('❌ 알림 권한 요청 중 에러: $e');
        } finally {
          _isRequestingPermission = false;
        }

        navigatorKey.currentState?.pushReplacementNamed('/splash');
      }
    } else if (event == AuthChangeEvent.signedOut) {
      // Mixpanel 로그아웃 트래킹
      MixpanelUtil.trackLogout();
    }
  });

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('📲 포그라운드 메시지 수신: ${message.notification?.title}');
  });

  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    print('🚀 알림 클릭됨: ${message.data}');
    final type = message.data['type'];
    final targetId = message.data['targetId'];

    if (type == 'profile') {
      navigatorKey.currentState?.pushNamed('/other_profile', arguments: targetId);
    } else if (type == 'post') {
      navigatorKey.currentState?.pushNamed('/post_detail', arguments: targetId);
    }
  });

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.white,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  runApp(
    DevicePreview(
      enabled: isQA,
      builder: (context) => const ProviderScope(child: MyApp()),
    ),
  );
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
      title: 'Logue',
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