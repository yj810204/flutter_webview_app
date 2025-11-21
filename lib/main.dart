import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'config/app_config.dart';
import 'screens/webview_screen.dart';
import 'services/push_notification_service.dart';
import 'services/push_notification_service.dart' as push_service;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 상태바 스타일 설정 (상태바가 콘텐츠 위에 오버레이되지 않도록)
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark, // Android
      statusBarBrightness: Brightness.light, // iOS
      systemNavigationBarColor: Colors.transparent,
    ),
  );

  // Firebase 초기화 (설정 파일이 없어도 앱이 실행되도록 안전하게 처리)
  bool firebaseInitialized = false;
  if (AppConfig.useFirebase) {
    try {
      await Firebase.initializeApp();
      firebaseInitialized = true;
      debugPrint('Firebase 초기화 완료');
      
      // 백그라운드 메시지 핸들러 등록
      FirebaseMessaging.onBackgroundMessage(
        push_service.firebaseMessagingBackgroundHandler,
      );
      
      // 푸시 알림 서비스 초기화
      try {
        final pushService = PushNotificationService();
        await pushService.initialize();
      } catch (e) {
        debugPrint('푸시 알림 서비스 초기화 오류: $e');
      }
    } catch (e) {
      debugPrint('Firebase 초기화 오류: $e');
      debugPrint('Firebase 설정 파일(google-services.json, GoogleService-Info.plist)이 없어도 앱은 계속 실행됩니다.');
      // Firebase 초기화 실패해도 앱은 계속 실행
    }
  }

  // 소셜 로그인은 웹에서 처리됨
  debugPrint('소셜 로그인은 웹에서 처리됩니다.');

  // 앱 실행 (초기화 오류와 관계없이 항상 실행)
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const WebViewScreen(),
    );
  }
}

