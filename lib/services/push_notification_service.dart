import 'dart:async';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:webview_flutter/webview_flutter.dart';
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
  FlutterLocalNotificationsPlugin? _localNotifications;
  
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
    debugPrint('=== 푸시 알림 서비스 초기화 시작 ===');
    // Firebase가 초기화되지 않았으면 초기화하지 않음
    if (!_isFirebaseInitialized) {
      debugPrint('Firebase가 초기화되지 않아 푸시 알림 서비스를 초기화하지 않습니다.');
      return;
    }
    debugPrint('Firebase 초기화 확인 완료');
    
    try {
      _firebaseMessaging = FirebaseMessaging.instance;
      debugPrint('FirebaseMessaging 인스턴스 생성 완료');
      
      // 알림 권한 요청 (Android 13+ 및 iOS)
      bool permissionGranted = await _requestNotificationPermission();
      
      if (!permissionGranted) {
        debugPrint('알림 권한이 거부되었습니다. 푸시 알림을 받을 수 없습니다.');
        return;
      }
      
      // 로컬 알림 초기화 (권한 요청 후)
      await _initializeLocalNotifications();

      // FCM 토큰 가져오기
      debugPrint('FCM 토큰 가져오기 시작...');
      try {
        _fcmToken = await _firebaseMessaging!.getToken();
        if (_fcmToken != null) {
          debugPrint('FCM Token 생성 성공: $_fcmToken');
        } else {
          debugPrint('FCM Token 생성 실패: null');
        }
      } catch (e) {
        debugPrint('FCM Token 가져오기 오류: $e');
      }
      
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

      // 포그라운드 메시지 핸들러 등록
      debugPrint('포그라운드 메시지 핸들러 등록 시작...');
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('=== 포그라운드 메시지 수신 ===');
        debugPrint('메시지 ID: ${message.messageId}');
        debugPrint('제목: ${message.notification?.title}');
        debugPrint('본문: ${message.notification?.body}');
        debugPrint('데이터: ${message.data}');
        debugPrint('notification이 null인가? ${message.notification == null}');
        // 포그라운드 메시지 수신 시에는 메시지 스트림에 추가하지 않음
        // 알림 클릭 시에만 URL로 이동하도록 함
        // _messageController?.add(message); // 주석 처리
        _handleForegroundMessage(message).catchError((e) {
          debugPrint('포그라운드 메시지 처리 오류: $e');
        });
      });
      debugPrint('포그라운드 메시지 핸들러 등록 완료');

      // 백그라운드 메시지 핸들러 등록 (앱이 백그라운드에 있을 때 알림 클릭)
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('=== 백그라운드에서 알림 클릭 ===');
        debugPrint('메시지 ID: ${message.messageId}');
        debugPrint('제목: ${message.notification?.title}');
        debugPrint('본문: ${message.notification?.body}');
        debugPrint('데이터: ${message.data}');
        _messageController?.add(message);
      });
      debugPrint('백그라운드 메시지 핸들러 등록 완료');

      // 앱이 종료된 상태에서 알림을 클릭하여 앱이 열린 경우
      // getInitialMessage는 앱이 완전히 종료된 상태에서만 값이 있음 (스플래시 화면이 정상적으로 보임)
      RemoteMessage? initialMessage = await _firebaseMessaging!.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('=== 앱 종료 상태에서 알림 클릭하여 앱 시작 ===');
        debugPrint('메시지 ID: ${initialMessage.messageId}');
        debugPrint('제목: ${initialMessage.notification?.title}');
        debugPrint('본문: ${initialMessage.notification?.body}');
        debugPrint('데이터: ${initialMessage.data}');
        // 앱이 종료된 상태에서 시작되므로 정상적으로 스플래시 화면이 보임
        // 웹뷰가 준비된 후 URL로 이동
        _messageController?.add(initialMessage);
      } else {
        debugPrint('앱 시작 시 알림 메시지 없음 (정상 시작)');
      }
      
      debugPrint('푸시 알림 서비스 초기화 완료');
    } catch (e) {
      debugPrint('푸시 알림 초기화 오류: $e');
    }
  }

  /// 알림 권한 요청 (Android 13+ 및 iOS)
  Future<bool> _requestNotificationPermission() async {
    if (Platform.isAndroid) {
      // Android 13 (API 33) 이상에서는 POST_NOTIFICATIONS 권한 필요
      if (await Permission.notification.isDenied) {
        debugPrint('Android 알림 권한 요청 중...');
        final status = await Permission.notification.request();
        if (status.isGranted) {
          debugPrint('Android 알림 권한 허용됨');
          return true;
        } else if (status.isPermanentlyDenied) {
          debugPrint('Android 알림 권한이 영구적으로 거부됨');
          return false;
        } else {
          debugPrint('Android 알림 권한 거부됨');
          return false;
        }
      } else if (await Permission.notification.isGranted) {
        debugPrint('Android 알림 권한 이미 허용됨');
        return true;
      } else {
        debugPrint('Android 알림 권한 상태 확인 불가');
        return false;
      }
    } else if (Platform.isIOS) {
      // iOS에서는 Firebase Messaging의 requestPermission 사용
      debugPrint('iOS 알림 권한 요청 중...');
      NotificationSettings settings = await _firebaseMessaging!.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('iOS 알림 권한 허용됨');
        return true;
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        debugPrint('iOS 임시 알림 권한 허용됨');
        return true;
      } else {
        debugPrint('iOS 알림 권한 거부됨: ${settings.authorizationStatus}');
        return false;
      }
    }
    
    // 기타 플랫폼
    debugPrint('알 수 없는 플랫폼');
    return false;
  }

  /// 로컬 알림 초기화
  Future<void> _initializeLocalNotifications() async {
    _localNotifications = FlutterLocalNotificationsPlugin();
    
    // Android 초기화 설정 (기본 아이콘 사용)
    // Android 시스템 기본 아이콘 사용
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@android:drawable/sym_def_app_icon');
    
    // iOS 초기화 설정
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _localNotifications!.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('로컬 알림 클릭: ${response.payload}');
        // 알림 클릭 시 URL이 있으면 메시지 스트림에 추가하여 웹뷰에서 처리
        if (response.payload != null && response.payload!.isNotEmpty) {
          final url = response.payload!;
          // RemoteMessage를 생성하여 스트림에 추가
          final message = RemoteMessage(
            messageId: 'local_notification_${DateTime.now().millisecondsSinceEpoch}',
            data: {'url': url},
            notification: RemoteNotification(
              title: '알림',
              body: '알림을 클릭했습니다',
            ),
          );
          _messageController?.add(message);
        }
      },
    );
    
    // Android 채널 생성
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      description: 'This channel is used for important notifications.',
      importance: Importance.high,
      playSound: true,
    );
    
    await _localNotifications!
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
    
    debugPrint('로컬 알림 초기화 완료');
  }

  /// 포그라운드 메시지 처리
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('=== _handleForegroundMessage 호출 ===');
    debugPrint('알림 제목: ${message.notification?.title}');
    debugPrint('알림 본문: ${message.notification?.body}');
    debugPrint('데이터: ${message.data}');
    debugPrint('_localNotifications null? ${_localNotifications == null}');
    debugPrint('message.notification null? ${message.notification == null}');
    
    // 포그라운드에서 알림 표시
    if (_localNotifications == null) {
      debugPrint('로컬 알림 플러그인이 초기화되지 않았습니다.');
      return;
    }
    
    if (message.notification == null) {
      debugPrint('메시지에 notification이 없습니다. 데이터만 전송된 메시지일 수 있습니다.');
      return;
    }
    
    if (_localNotifications != null && message.notification != null) {
      final notification = message.notification!;
      final androidDetails = AndroidNotificationDetails(
        'high_importance_channel',
        'High Importance Notifications',
        channelDescription: 'This channel is used for important notifications.',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        playSound: true,
        enableVibration: true,
      );
      
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      
      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );
      
      // 알림 ID 생성 (메시지 ID 또는 타임스탬프 사용)
      final notificationId = message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch.remainder(100000);
      
      // URL을 payload로 전달
      final url = getUrlFromMessage(message);
      final payload = url ?? '';
      
      try {
        await _localNotifications!.show(
          notificationId,
          notification.title,
          notification.body,
          notificationDetails,
          payload: payload,
        );
        
        debugPrint('포그라운드 알림 표시 완료: ${notification.title}');
      } catch (e, stackTrace) {
        debugPrint('포그라운드 알림 표시 오류: $e');
        debugPrint('스택 트레이스: $stackTrace');
      }
    } else {
      debugPrint('포그라운드 알림 표시 조건 불만족');
    }
  }

  /// 알림 클릭 시 이동할 URL 가져오기
  String? getUrlFromMessage(RemoteMessage message) {
    // 알림 데이터에서 URL 추출
    return message.data['url'] ?? message.data['link'];
  }

  /// 디바이스 토큰을 서버로 전송
  /// deviceToken.php 엔드포인트로 POST 요청을 보냅니다
  /// WebViewController가 제공되면 JavaScript를 통해 전송하여 쿠키가 포함되도록 합니다
  Future<bool> sendDeviceTokenToServer(String token, {WebViewController? controller}) async {
    // WebViewController가 제공되면 JavaScript를 통해 전송 (쿠키 포함)
    if (controller != null) {
      try {
        final websiteUri = Uri.parse(AppConfig.websiteUrl);
        final domain = websiteUri.host;
        
        if (domain.isEmpty) {
          debugPrint('웹사이트 도메인을 가져올 수 없습니다.');
          return false;
        }

        final url = 'https://$domain/${AppConfig.serverApiPathDeviceToken}';
        debugPrint('디바이스 토큰 서버 전송 시작 (JavaScript): $url');
        
        // JavaScript를 통해 전송 (쿠키 자동 포함)
        final script = '''
          (function() {
            try {
              const xhttp = new XMLHttpRequest();
              xhttp.onload = function() {
                if (this.status === 200) {
                  console.log('[Flutter] 디바이스 토큰 서버 전송 성공');
                  if (window.onDeviceTokenRegistered) {
                    window.onDeviceTokenRegistered(true);
                  }
                } else {
                  console.error('[Flutter] 디바이스 토큰 서버 전송 실패:', this.status);
                  if (window.onDeviceTokenRegistered) {
                    window.onDeviceTokenRegistered(false);
                  }
                }
              };
              xhttp.onerror = function() {
                console.error('[Flutter] 디바이스 토큰 서버 전송 오류');
                if (window.onDeviceTokenRegistered) {
                  window.onDeviceTokenRegistered(false);
                }
              };
              xhttp.open('POST', '$url', true);
              xhttp.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');
              xhttp.send('device_token=$token');
            } catch (e) {
              console.error('[Flutter] 디바이스 토큰 전송 스크립트 오류:', e);
            }
          })();
        ''';
        
        await controller.runJavaScript(script);
        debugPrint('디바이스 토큰 서버 전송 요청 완료 (JavaScript)');
        // JavaScript 실행은 비동기이므로 성공 여부를 정확히 알 수 없음
        // 하지만 쿠키가 포함되어 전송되므로 더 정확함
        return true;
      } catch (e, stackTrace) {
        debugPrint('디바이스 토큰 서버 전송 오류 (JavaScript): $e');
        debugPrint('스택 트레이스: $stackTrace');
        // JavaScript 실패 시 직접 HTTP 요청으로 폴백
        return await sendDeviceTokenToServerDirect(token);
      }
    } else {
      // WebViewController가 없으면 직접 HTTP 요청 (초기화 시 등)
      return await sendDeviceTokenToServerDirect(token);
    }
  }

  /// 디바이스 토큰을 서버로 직접 전송 (HTTP 요청)
  Future<bool> sendDeviceTokenToServerDirect(String token) async {
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
      debugPrint('디바이스 토큰 서버 전송 시작 (직접): $url');
      
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

