
import 'dart:io' show Platform;
import 'package:device_preview/device_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logue/presentation/routes/on_generate_route.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/observers/screen_tracking_observer.dart';
import 'core/themes/app_colors.dart';
import 'core/themes/text_theme.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'data/utils/fcm_token_util.dart';
import 'package:amplitude_flutter/amplitude.dart';
import 'package:flutter/services.dart';
import 'presentation/routes/on_generate_route.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final Amplitude amplitude = Amplitude.getInstance(instanceName: "default");
const bool isQA = bool.fromEnvironment('QA_MODE', defaultValue: false);
// ✅ 백그라운드 메시지 핸들러
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('📩 백그라운드 메시지 수신: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await dotenv.load(fileName: ".env");

  // ✅ Supabase 초기화
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
    authFlowType: AuthFlowType.pkce,
  );

  amplitude.init(dotenv.env['AMPLITUDE_API_KEY']!);
  final currentUserId = Supabase.instance.client.auth.currentUser?.id ?? 'anonymous';
  amplitude.setUserId(currentUserId);
  FcmTokenUtil.listenTokenRefresh();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  final messaging = FirebaseMessaging.instance;

  // ✅ Auth 상태 변경 처리
  bool _isRequestingPermission = false; // 전역 변수

  Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
    final event = data.event;
    final session = data.session;

    if (event == AuthChangeEvent.signedIn && session != null) {
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
    }
  });

  // ✅ Firebase Messaging 설정
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // ✅ 포그라운드 수신
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('📲 포그라운드 메시지 수신: ${message.notification?.title}');
    // 알림 UI 표시하거나 snackbar 등으로 노출 가능
  });

  // ✅ 알림 클릭 시 라우팅
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
    statusBarColor: Colors.white, // 상단 상태바 배경
    statusBarIconBrightness: Brightness.dark, // 상태바 아이콘(시계, 배터리 등) 색상

    systemNavigationBarColor: Colors.white, // 하단 네비게이션 바 배경
    systemNavigationBarIconBrightness: Brightness.dark, // 하단 아이콘 색상
  ));
  amplitude.logEvent('app_opened');
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
    amplitude.logEvent('session_started');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      amplitude.logEvent('session_ended');
    }
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
        dialogTheme: DialogTheme(
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