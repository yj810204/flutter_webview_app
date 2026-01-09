import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

/// 푸시 알림 서비스
/// Firebase Cloud Messaging을 사용하여 푸시 알림을 처리합니다.
class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  FirebaseMessaging? _firebaseMessaging;
  String? _fcmToken;
  StreamController<String>? _tokenController;
  StreamController<RemoteMessage>? _messageController;
  
  /// Firebase가 초기화되었는지 확인
  bool get _isFirebaseInitialized {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// FCM 토큰 스트림
  Stream<String>? get tokenStream => _tokenController?.stream;

  /// 알림 메시지 스트림
  Stream<RemoteMessage>? get messageStream => _messageController?.stream;

  /// 현재 FCM 토큰
  String? get fcmToken => _fcmToken;

  /// 푸시 알림 서비스 초기화
  Future<void> initialize() async {
    // Firebase가 초기화되지 않았으면 초기화하지 않음
    if (!_isFirebaseInitialized) {
      debugPrint('Firebase가 초기화되지 않아 푸시 알림 서비스를 초기화하지 않습니다.');
      return;
    }
    
    try {
      _firebaseMessaging = FirebaseMessaging.instance;
      
      // 알림 권한 요청
      NotificationSettings settings = await _firebaseMessaging!.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('사용자가 알림 권한을 허용했습니다');
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        debugPrint('사용자가 임시 알림 권한을 허용했습니다');
      } else {
        debugPrint('사용자가 알림 권한을 거부했습니다');
      }

      // FCM 토큰 가져오기
      _fcmToken = await _firebaseMessaging!.getToken();
      debugPrint('FCM Token: $_fcmToken');
      
      _tokenController = StreamController<String>.broadcast();
      _messageController = StreamController<RemoteMessage>.broadcast();

      if (_fcmToken != null) {
        _tokenController?.add(_fcmToken!);
        // 토큰을 받은 직후 서버로 전송 시도
        sendDeviceTokenToServer(_fcmToken!).then((success) {
          if (success) {
            debugPrint('초기화 시 디바이스 토큰 서버 전송 완료');
          } else {
            debugPrint('초기화 시 디바이스 토큰 서버 전송 실패 (무시)');
          }
        }).catchError((e) {
          debugPrint('초기화 시 디바이스 토큰 서버 전송 오류 (무시): $e');
        });
      }

      // 토큰 갱신 리스너
      _firebaseMessaging!.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        debugPrint('FCM Token 갱신: $newToken');
        _tokenController?.add(newToken);
        // 토큰 갱신 시에도 서버로 전송
        sendDeviceTokenToServer(newToken).then((success) {
          if (success) {
            debugPrint('토큰 갱신 시 디바이스 토큰 서버 전송 완료');
          } else {
            debugPrint('토큰 갱신 시 디바이스 토큰 서버 전송 실패 (무시)');
          }
        }).catchError((e) {
          debugPrint('토큰 갱신 시 디바이스 토큰 서버 전송 오류 (무시): $e');
        });
      });

      // 포그라운드 메시지 핸들러
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('포그라운드 메시지 수신: ${message.messageId}');
        _messageController?.add(message);
        _handleForegroundMessage(message);
      });

      // 백그라운드 메시지 핸들러 (앱이 종료된 상태에서 알림 클릭)
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('백그라운드에서 알림 클릭: ${message.messageId}');
        _messageController?.add(message);
      });

      // 앱이 종료된 상태에서 알림을 클릭하여 앱이 열린 경우
      RemoteMessage? initialMessage = await _firebaseMessaging!.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('앱 시작 시 알림 메시지: ${initialMessage.messageId}');
        _messageController?.add(initialMessage);
      }
    } catch (e) {
      debugPrint('푸시 알림 초기화 오류: $e');
    }
  }

  /// 포그라운드 메시지 처리
  void _handleForegroundMessage(RemoteMessage message) {
    // 포그라운드에서 알림을 표시하려면 flutter_local_notifications 패키지를 사용할 수 있습니다
    // 여기서는 기본적인 처리만 수행합니다
    debugPrint('알림 제목: ${message.notification?.title}');
    debugPrint('알림 본문: ${message.notification?.body}');
    debugPrint('데이터: ${message.data}');
  }

  /// 알림 클릭 시 이동할 URL 가져오기
  String? getUrlFromMessage(RemoteMessage message) {
    // 알림 데이터에서 URL 추출
    return message.data['url'] ?? message.data['link'];
  }

  /// 디바이스 토큰을 서버로 전송
  /// deviceToken.php 엔드포인트로 POST 요청을 보냅니다
  Future<bool> sendDeviceTokenToServer(String token) async {
    try {
      // 웹사이트 URL에서 도메인만 추출 (경로 제외)
      final websiteUri = Uri.parse(AppConfig.websiteUrl);
      final domain = websiteUri.host;
      
      if (domain.isEmpty) {
        debugPrint('웹사이트 도메인을 가져올 수 없습니다.');
        return false;
      }

      // deviceToken.php URL 생성 (도메인만 사용, 경로는 제외)
      // 형식: https://domain/modules/appmgmt/libs/deviceToken.php
      final url = 'https://$domain/${AppConfig.serverApiPathDeviceToken}';
      debugPrint('디바이스 토큰 서버 전송 시작: $url');
      
      // POST 요청 전송
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: 'device_token=$token',
      ).timeout(
        Duration(milliseconds: AppConfig.httpConnectTimeoutMs),
        onTimeout: () {
          debugPrint('디바이스 토큰 서버 전송 타임아웃');
          throw TimeoutException('서버 전송 타임아웃');
        },
      );
      
      if (response.statusCode == 200) {
        debugPrint('디바이스 토큰 서버 전송 성공');
        return true;
      } else {
        debugPrint('디바이스 토큰 서버 전송 실패: ${response.statusCode}');
        debugPrint('응답 본문: ${response.body}');
        return false;
      }
    } catch (e, stackTrace) {
      debugPrint('디바이스 토큰 서버 전송 오류: $e');
      debugPrint('스택 트레이스: $stackTrace');
      return false;
    }
  }

  /// 서비스 정리
  void dispose() {
    _tokenController?.close();
    _messageController?.close();
    _tokenController = null;
    _messageController = null;
  }
}

/// 백그라운드 메시지 핸들러 (최상위 함수로 정의해야 함)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('백그라운드 메시지 처리: ${message.messageId}');
}

