import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../config/app_config.dart';
import 'push_notification_service.dart';
import 'social_login_service.dart';
import 'location_service.dart';

/// JavaScript 채널 핸들러
/// 웹뷰와 네이티브 앱 간의 통신을 처리합니다.
class JsChannelHandler {
  PushNotificationService? _pushService;
  final SocialLoginService _socialLoginService = SocialLoginService();
  final LocationService _locationService = LocationService();
  final Function(String)? onUrlChange;
  final Future<bool> Function()? onRequestLocationPermission;
  final Function(String)? onShowAlert;
  final Function(String, String)? onShowConfirm;
  final Function(String, String, String)? onShowPrompt;
  final VoidCallback? onSearchPostcode;
  final Function(Map<String, dynamic>)? onPostcodeResult;
  final Function(String)? onSaveImage;
  WebViewController? _controller;

  JsChannelHandler({
    this.onUrlChange,
    this.onRequestLocationPermission,
    this.onShowAlert,
    this.onShowConfirm,
    this.onShowPrompt,
    this.onSearchPostcode,
    this.onPostcodeResult,
    this.onSaveImage,
  });
  
  /// PushNotificationService 설정
  void setPushService(PushNotificationService? pushService) {
    _pushService = pushService;
  }

  /// 컨트롤러 설정
  void setController(WebViewController controller) {
    _controller = controller;
  }

  /// JavaScript 채널 이름 반환
  String get channelName => AppConfig.jsChannelName;

  /// JavaScript 메시지 처리 (WebViewScreen에서 호출)
  void handleMessage(String message) {
    try {
      debugPrint('JavaScript 채널 메시지 수신 (원본): $message');
      final Map<String, dynamic> data = jsonDecode(message);
      final String action = data['action'] ?? '';

      debugPrint('JavaScript 채널 메시지 수신: $action');

      switch (action) {
        case 'getFCMToken':
          _handleGetFCMToken();
          break;
        case 'socialLogin':
          _handleSocialLogin(data);
          break;
        case 'openUrl':
          _handleOpenUrl(data);
          break;
        case 'requestLocationPermission':
          debugPrint('위치 권한 요청 액션 감지됨');
          _handleRequestLocationPermission(data);
          break;
        case 'getCurrentLocation':
          debugPrint('현재 위치 정보 요청 액션 감지됨');
          _handleGetCurrentLocation(data);
          break;
        case 'reload':
          debugPrint('새로고침 액션 감지됨');
          _handleReload();
          break;
        case 'showAlert':
          debugPrint('alert 표시 액션 감지됨');
          _handleShowAlert(data);
          break;
        case 'showConfirm':
          debugPrint('confirm 표시 액션 감지됨');
          _handleShowConfirm(data);
          break;
        case 'showPrompt':
          debugPrint('prompt 표시 액션 감지됨');
          _handleShowPrompt(data);
          break;
        case 'searchPostcode':
          debugPrint('우편번호 검색 액션 감지됨');
          _handleSearchPostcode();
          break;
        case 'postcodeResult':
          debugPrint('우편번호 검색 결과 수신 액션 감지됨');
          _handlePostcodeResult(data);
          break;
        case 'saveImage':
          debugPrint('이미지 저장 액션 감지됨');
          _handleSaveImage(data);
          break;
        default:
          debugPrint('알 수 없는 액션: $action');
      }
    } catch (e, stackTrace) {
      debugPrint('메시지 처리 오류: $e');
      debugPrint('스택 트레이스: $stackTrace');
    }
  }

  /// FCM 토큰 가져오기
  void _handleGetFCMToken() {
    if (_pushService == null || _controller == null) {
      debugPrint('푸시 알림 서비스가 초기화되지 않았습니다.');
      return;
    }
    
    final token = _pushService!.fcmToken;
    if (token != null) {
      sendFCMTokenToWebView(_controller!, token);
    } else {
      debugPrint('FCM 토큰을 가져올 수 없습니다');
    }
  }

  /// 소셜 로그인 처리
  Future<void> _handleSocialLogin(Map<String, dynamic> data) async {
    final String provider = data['provider'] ?? '';
    
    Map<String, dynamic>? result;
    
    if (provider == 'google') {
      result = await _socialLoginService.signInWithGoogle();
    } else if (provider == 'kakao') {
      result = await _socialLoginService.signInWithKakao();
    } else {
      if (_controller != null) {
        final errorResult = jsonEncode({
          'success': false,
          'error': '지원하지 않는 로그인 제공자: $provider',
        });
        sendSocialLoginResultToWebView(_controller!, errorResult);
      }
      return;
    }

    if (_controller != null) {
      final jsonResult = _socialLoginService.loginResultToJson(result);
      sendSocialLoginResultToWebView(_controller!, jsonResult);
    }
  }

  /// URL 열기
  void _handleOpenUrl(Map<String, dynamic> data) {
    final String? url = data['url'];
    if (url != null && _controller != null) {
      _controller!.loadRequest(Uri.parse(url));
    }
  }

  /// 위치 권한 요청 처리
  Future<void> _handleRequestLocationPermission(Map<String, dynamic> data) async {
    debugPrint('_handleRequestLocationPermission 호출됨');
    if (onRequestLocationPermission != null) {
      debugPrint('위치 권한 요청 콜백 실행 중...');
      final granted = await onRequestLocationPermission!();
      debugPrint('위치 권한 요청 결과: $granted');
      
      // 권한이 허용되면 자동으로 위치 정보를 가져와서 전달
      if (granted && _controller != null) {
        final requestId = data['requestId'] as String?;
        await _getAndSendLocation(requestId);
      }
    } else {
      debugPrint('위치 권한 요청 콜백이 설정되지 않았습니다.');
    }
  }

  /// 현재 위치 정보 가져오기 및 전달
  Future<void> _handleGetCurrentLocation(Map<String, dynamic> data) async {
    debugPrint('_handleGetCurrentLocation 호출됨');
    if (_controller == null) {
      debugPrint('WebViewController가 설정되지 않았습니다.');
      return;
    }
    
    final requestId = data['requestId'] as String?;
    await _getAndSendLocation(requestId);
  }

  /// 위치 정보를 가져와서 JavaScript로 전달
  Future<void> _getAndSendLocation(String? requestId) async {
    try {
      debugPrint('위치 정보 가져오기 시작 (requestId: $requestId)');
      
      final position = await _locationService.getCurrentPosition();
      
      if (position != null && _controller != null) {
        final jsPosition = _locationService.positionToJsFormat(position);
        sendLocationToWebView(_controller!, jsPosition, requestId);
        debugPrint('✅ 위치 정보를 JavaScript로 전달 완료');
      } else {
        debugPrint('❌ 위치 정보를 가져올 수 없습니다.');
        sendLocationErrorToWebView(_controller!, '위치 정보를 가져올 수 없습니다.', requestId);
      }
    } catch (e, stackTrace) {
      debugPrint('❌ 위치 정보 가져오기 오류: $e');
      debugPrint('스택 트레이스: $stackTrace');
      if (_controller != null) {
        sendLocationErrorToWebView(_controller!, e.toString(), requestId);
      }
    }
  }

  /// FCM 토큰을 웹뷰로 전송하는 헬퍼 메서드
  void sendFCMTokenToWebView(WebViewController controller, String token) {
    final script = '''
      if (window.onFCMTokenReceived) {
        window.onFCMTokenReceived('$token');
      }
    ''';
    controller.runJavaScript(script);
  }

  /// 소셜 로그인 결과를 웹뷰로 전송하는 헬퍼 메서드
  void sendSocialLoginResultToWebView(WebViewController controller, String result) {
    final script = '''
      if (window.onSocialLoginResult) {
        window.onSocialLoginResult($result);
      }
    ''';
    controller.runJavaScript(script);
  }

  /// 위치 정보를 웹뷰로 전송하는 헬퍼 메서드
  void sendLocationToWebView(WebViewController controller, Map<String, dynamic> position, String? requestId) {
    final positionJson = jsonEncode(position);
    final script = '''
      (function() {
        try {
          const position = $positionJson;
          const requestId = ${requestId != null ? "'$requestId'" : 'null'};
          
          // Flutter 위치 정보 수신 핸들러 호출
          if (window.flutterLocationHandler && window.flutterLocationHandler.onLocationReceived) {
            window.flutterLocationHandler.onLocationReceived(position, requestId);
          } else {
            console.warn('[Flutter] flutterLocationHandler.onLocationReceived가 정의되지 않았습니다.');
          }
        } catch (e) {
          console.error('[Flutter] 위치 정보 전달 오류:', e);
        }
      })();
    ''';
    controller.runJavaScript(script);
  }

  /// 위치 정보 오류를 웹뷰로 전송하는 헬퍼 메서드
  void sendLocationErrorToWebView(WebViewController controller, String errorMessage, String? requestId) {
    final script = '''
      (function() {
        try {
          const error = {
            code: 1,
            message: ${jsonEncode(errorMessage)},
            PERMISSION_DENIED: 1,
            POSITION_UNAVAILABLE: 2,
            TIMEOUT: 3
          };
          const requestId = ${requestId != null ? "'$requestId'" : 'null'};
          
          // Flutter 위치 오류 수신 핸들러 호출
          if (window.flutterLocationHandler && window.flutterLocationHandler.onLocationError) {
            window.flutterLocationHandler.onLocationError(error, requestId);
          } else {
            console.warn('[Flutter] flutterLocationHandler.onLocationError가 정의되지 않았습니다.');
          }
        } catch (e) {
          console.error('[Flutter] 위치 오류 전달 오류:', e);
        }
      })();
    ''';
    controller.runJavaScript(script);
  }

  /// 새로고침 처리
  void _handleReload() {
    if (_controller != null) {
      _controller!.reload();
      debugPrint('웹뷰 새로고침 실행');
    } else {
      debugPrint('WebViewController가 설정되지 않았습니다.');
    }
  }

  /// Alert 표시 처리
  void _handleShowAlert(Map<String, dynamic> data) {
    final String? message = data['message'];
    if (message != null && onShowAlert != null) {
      onShowAlert!(message);
    } else {
      debugPrint('Alert 메시지가 없거나 콜백이 설정되지 않았습니다.');
    }
  }

  /// Confirm 표시 처리
  void _handleShowConfirm(Map<String, dynamic> data) {
    final String? message = data['message'];
    final String? confirmId = data['confirmId'];
    if (message != null && confirmId != null && onShowConfirm != null) {
      onShowConfirm!(message, confirmId);
    } else {
      debugPrint('Confirm 메시지나 ID가 없거나 콜백이 설정되지 않았습니다.');
    }
  }

  /// 우편번호 검색 처리 (네이티브)
  void _handleSearchPostcode() {
    debugPrint('네이티브 우편번호 검색 요청');
    
    if (onSearchPostcode != null) {
      onSearchPostcode!();
    } else {
      debugPrint('onSearchPostcode 콜백이 설정되지 않았습니다.');
    }
  }

  /// 우편번호 검색 결과 처리
  void _handlePostcodeResult(Map<String, dynamic> data) {
    debugPrint('우편번호 검색 결과 수신: $data');
    
    final postcodeData = data['data'];
    
    if (postcodeData != null && postcodeData is Map) {
      final Map<String, dynamic> typedPostcodeData = Map<String, dynamic>.from(postcodeData);
      
      if (onPostcodeResult != null) {
        onPostcodeResult!(typedPostcodeData);
      } else {
        debugPrint('onPostcodeResult 콜백이 설정되지 않았습니다.');
      }
    } else {
      debugPrint('우편번호 검색 데이터가 올바르지 않습니다.');
    }
  }

  /// Prompt 표시 처리
  void _handleShowPrompt(Map<String, dynamic> data) {
    final String? message = data['message'];
    final String? defaultText = data['defaultText'];
    final String? promptId = data['promptId'];
    if (message != null && promptId != null && onShowPrompt != null) {
      onShowPrompt!(message, defaultText ?? '', promptId);
    } else {
      debugPrint('Prompt 메시지나 ID가 없거나 콜백이 설정되지 않았습니다.');
    }
  }

  /// Confirm 결과를 JavaScript로 전송
  void sendConfirmResultToWebView(WebViewController controller, String confirmId, bool result) {
    final script = '''
      (function() {
        if (window.flutterConfirmResults) {
          window.flutterConfirmResults['$confirmId'] = $result;
        }
      })();
    ''';
    controller.runJavaScript(script);
  }

  /// Prompt 결과를 JavaScript로 전송
  void sendPromptResultToWebView(WebViewController controller, String promptId, String? result) {
    final resultJson = result != null ? jsonEncode(result) : 'null';
    final script = '''
      (function() {
        if (window.flutterPromptResults) {
          window.flutterPromptResults['$promptId'] = $resultJson;
        }
      })();
    ''';
    controller.runJavaScript(script);
  }

  /// 이미지 저장 처리
  void _handleSaveImage(Map<String, dynamic> data) {
    final String? imageUrl = data['imageUrl'];
    if (imageUrl != null && onSaveImage != null) {
      onSaveImage!(imageUrl);
    } else {
      debugPrint('이미지 URL이 없거나 콜백이 설정되지 않았습니다.');
    }
  }
}

