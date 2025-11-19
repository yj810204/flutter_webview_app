import 'dart:async';
import 'dart:convert';
import 'dart:io' show File, Platform;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart' show AndroidWebViewController, FileSelectorMode;
import 'package:daum_postcode_search/daum_postcode_search.dart' show DaumPostcodeLocalServer, DaumPostcodeCallbackParser, DaumPostcodeAssets, DataModel;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../config/app_config.dart';
import '../services/js_channel_handler.dart';
import '../services/push_notification_service.dart';

/// 웹뷰 화면
class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  WebViewController? _controller;
  late final JsChannelHandler _jsHandler;
  PushNotificationService? _pushService;
  bool _isLoading = true;
  double _loadingProgress = 0.0;
  bool _canGoBack = false;
  bool _canGoForward = false;
  StreamSubscription? _pushTokenSubscription;
  StreamSubscription? _pushMessageSubscription;
  DaumPostcodeLocalServer? _postcodeServer;

  // 소셜 로그인 호스트 목록 (웹뷰 내에서 처리해야 함)
  static const List<String> _socialLoginHosts = [
    // 카카오
    'kauth.kakao.com',
    'kapi.kakao.com',
    'accounts.kakao.com',
    // 구글
    'accounts.google.com',
    'oauth2.googleapis.com',
    'www.googleapis.com',
    // 애플
    'appleid.apple.com',
    'idmsa.apple.com',
    // 네이버
    'nid.naver.com',
    'openapi.naver.com',
  ];

  @override
  void initState() {
    super.initState();
    // Firebase가 활성화된 경우에만 푸시 알림 서비스 초기화
    if (AppConfig.useFirebase) {
      _pushService = PushNotificationService();
    }
    // JsChannelHandler 초기화 (위치 권한 요청 콜백 포함)
    _jsHandler = JsChannelHandler(
      onRequestLocationPermission: _checkAndRequestLocationPermission,
      onShowAlert: _showAlertDialog,
      onShowConfirm: _showConfirmDialog,
      onShowPrompt: _showPromptDialog,
      onSearchPostcode: _searchPostcode,
      onSaveImage: _saveImage,
    );
    // 웹뷰 초기화 (비동기)
    _initializeWebView();
    if (AppConfig.useFirebase && _pushService != null) {
      _setupPushNotifications();
    }
  }

  /// 위치 권한 확인 및 요청 (웹뷰에서 geolocation 요청 시 호출)
  /// 허용될 때까지 반복적으로 요청
  Future<bool> _checkAndRequestLocationPermission() async {
    debugPrint('=== 위치 권한 확인 및 요청 시작 ===');
    
    try {
      // 현재 권한 상태 확인
      final currentStatus = await Permission.location.status;
      debugPrint('현재 위치 권한 상태: $currentStatus');
      debugPrint('권한 허용 여부: ${currentStatus.isGranted}');
      debugPrint('권한 거부 여부: ${currentStatus.isDenied}');
      debugPrint('권한 영구 거부 여부: ${currentStatus.isPermanentlyDenied}');
      
      // 이미 권한이 허용되어 있으면 true 반환 (더 이상 요청하지 않음)
      if (currentStatus.isGranted) {
        debugPrint('위치 권한이 이미 허용되어 있습니다. 웹뷰에서 위치 정보를 사용할 수 있습니다.');
        return true;
      }

      // 영구적으로 거부된 경우: Android에서는 시스템 다이얼로그를 다시 표시할 수 없음
      // 설정 화면으로 이동하도록 안내 다이얼로그 표시
      if (currentStatus.isPermanentlyDenied) {
        debugPrint('위치 권한이 영구적으로 거부되었습니다. 설정 화면으로 이동 안내 다이얼로그 표시');
        
        // 설정 화면으로 이동할지 물어보는 다이얼로그 표시
        final shouldOpenSettings = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('위치 권한 필요'),
            content: const Text('위치 기반 서비스를 사용하려면 위치 권한이 필요합니다.\n설정 화면으로 이동하여 권한을 허용해주세요.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('설정으로 이동'),
              ),
            ],
          ),
        );
        
        if (shouldOpenSettings == true) {
          debugPrint('설정 화면으로 이동 중...');
          await openAppSettings();
          debugPrint('설정 화면으로 이동 완료. 사용자가 권한을 변경한 후 앱으로 돌아오면 다시 확인됩니다.');
        } else {
          debugPrint('사용자가 설정 화면으로 이동을 취소했습니다.');
        }
        
        // 다음 geolocation 요청 시 다시 시도하도록 false 반환
        return false;
      }

      // 권한이 거부되었거나 아직 요청하지 않은 경우 시스템 다이얼로그 표시 시도
      debugPrint('위치 권한 요청 다이얼로그 표시 중...');
      final status = await Permission.location.request();
      debugPrint('위치 권한 요청 결과: $status');
      
      if (status.isGranted) {
        debugPrint('✅ 위치 권한이 허용되었습니다!');
        
        // MainActivity에 geolocation 권한 허용 알림
        const platform = MethodChannel('com.example.flutter_webview_app/geolocation');
        try {
          await platform.invokeMethod('setGeolocationEnabled', {'enabled': true});
          debugPrint('MainActivity에 geolocation 권한 허용 알림 전송 완료');
        } catch (e) {
          debugPrint('MainActivity에 geolocation 권한 알림 전송 실패: $e');
        }
        
        return true;
      } else if (status.isDenied) {
        debugPrint('❌ 위치 권한이 거부되었습니다. 다음 geolocation 요청 시 다시 요청합니다.');
        return false;
      } else if (status.isPermanentlyDenied) {
        debugPrint('❌ 위치 권한이 영구적으로 거부되었습니다. 다음 geolocation 요청 시 설정 화면으로 이동합니다.');
        // 영구적으로 거부되어도 다음 요청 시 다시 시도하도록 false 반환
        return false;
      } else if (status.isLimited) {
        debugPrint('⚠️ 위치 권한이 제한적으로 허용되었습니다.');
        return true;
      }
      debugPrint('❓ 알 수 없는 권한 상태: $status');
      return false;
    } catch (e, stackTrace) {
      debugPrint('❌ 위치 권한 요청 오류: $e');
      debugPrint('스택 트레이스: $stackTrace');
      return false;
    }
  }

  /// Android 뒤로가기 버튼 처리
  Future<bool> _onWillPop() async {
    if (_controller == null) return false;
    
    if (await _controller!.canGoBack()) {
      // 웹뷰에 뒤로갈 히스토리가 있으면 뒤로가기
      _controller!.goBack();
      _updateNavigationState();
      return false; // 시스템 기본 동작 방지
    } else {
      // 더 이상 뒤로갈 곳이 없으면 앱 종료 확인
      final shouldExit = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('앱 종료'),
          content: const Text('앱을 종료하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('아니오'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('예'),
            ),
          ],
        ),
      );
      
      if (shouldExit == true) {
        SystemNavigator.pop(); // 앱 종료
      }
      return false; // 시스템 기본 동작 방지
    }
  }

  /// User-Agent 생성 (웹 프론트와 동일한 형식)
  Future<String> _buildUserAgent() async {
    try {
      // 앱 버전 가져오기
      final packageInfo = await PackageInfo.fromPlatform();
      final appVersion = packageInfo.version.replaceAll('.', '_');
      
      // 플랫폼 감지
      final platform = Platform.isIOS ? 'ios' : 'android';
      
      // User-Agent 형식: WpApp_ios WpVer_1_0_0 또는 WpApp_android WpVer_1_0_0
      final userAgent = 'WpApp_$platform WpVer_$appVersion';
      
      debugPrint('User-Agent 설정: $userAgent');
      return userAgent;
    } catch (e) {
      debugPrint('User-Agent 생성 오류: $e');
      // 기본값 사용
      final platform = Platform.isIOS ? 'ios' : 'android';
      return 'WpApp_$platform WpVer_${AppConfig.appVersion.replaceAll('.', '_')}';
    }
  }

  /// 웹뷰 초기화
  Future<void> _initializeWebView() async {
    try {
      // User-Agent 설정
      final customUserAgent = await _buildUserAgent();
      
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..enableZoom(true)
        ..setBackgroundColor(Colors.white);
      
      // User-Agent 설정 (안전하게)
      try {
        controller.setUserAgent(customUserAgent);
      } catch (e) {
        debugPrint('User-Agent 설정 오류: $e');
        // User-Agent 설정 실패해도 계속 진행
      }
      
      controller
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (mounted) {
              setState(() {
                _loadingProgress = progress / 100.0;
              });
            }
          },
          onPageStarted: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = true;
              });
            }
            // 페이지가 시작될 때 JavaScript 브리지 주입 (더 일찍 주입)
            _injectJavaScriptBridge();
          },
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
            _updateNavigationState();
            // 페이지 로드 완료 후에도 다시 주입 (확실하게)
            _injectJavaScriptBridge();
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('웹뷰 오류: ${error.description}');
          },
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url;
            debugPrint('네비게이션 요청: $url');
            
            // tel: 스킴 처리 (전화 앱 실행)
            if (url.startsWith('tel:')) {
              _launchUrl(url);
              return NavigationDecision.prevent;
            }
            
            // sms: 스킴 처리 (문자 메시지 앱 실행)
            if (url.startsWith('sms:')) {
              _launchUrl(url);
              return NavigationDecision.prevent;
            }
            
            // 팝업 URL 감지 (about:blank 또는 빈 URL은 팝업일 수 있음)
            if (url == 'about:blank' || url.isEmpty) {
              debugPrint('팝업 URL 감지: $url - 네비게이션 허용');
              return NavigationDecision.navigate;
            }
            
            // 호스트 비교: websiteUrl과 다른 호스트는 외부 브라우저로 열기
            try {
              final requestUri = Uri.parse(url);
              final websiteUri = Uri.parse(AppConfig.websiteUrl);
              
              // HTTP/HTTPS 스킴만 처리
              if ((requestUri.scheme == 'http' || requestUri.scheme == 'https') &&
                  requestUri.host.isNotEmpty) {
                
                // 소셜 로그인 호스트는 웹뷰 내에서 처리
                if (_socialLoginHosts.contains(requestUri.host)) {
                  debugPrint('소셜 로그인 호스트 감지: ${requestUri.host} - 웹뷰 내에서 처리');
                  return NavigationDecision.navigate;
                }
                
                // 호스트가 다르면 외부 브라우저로 열기
                if (requestUri.host != websiteUri.host) {
                  debugPrint('외부 호스트 감지: ${requestUri.host} (기본: ${websiteUri.host}) - 외부 브라우저로 열기');
                  _launchUrl(url);
                  return NavigationDecision.prevent;
                }
              }
            } catch (e) {
              debugPrint('호스트 비교 오류: $e');
              // 오류 발생 시 기본 웹뷰로 처리
            }
            
            // 모든 네비게이션을 기본 웹뷰로 처리
            return NavigationDecision.navigate;
          },
        ),
      )
      ..addJavaScriptChannel(
        _jsHandler.channelName,
        onMessageReceived: (JavaScriptMessage message) {
          _jsHandler.handleMessage(message.message);
        },
      );
      
      // Android WebView 팝업 지원 및 파일 선택기 설정 (webview_flutter_android 사용)
      if (Platform.isAndroid && controller.platform is AndroidWebViewController) {
        final androidController = controller.platform as AndroidWebViewController;
        await _setupAndroidPopupSupport(androidController);
        await _setupAndroidFileChooser(androidController);
      }
      
      await controller.loadRequest(Uri.parse(AppConfig.websiteUrl));
      
      // 컨트롤러를 상태에 저장
      if (mounted) {
        setState(() {
          _controller = controller;
        });
        
        // JsChannelHandler에 컨트롤러 설정
        _jsHandler.setController(controller);
        
        // PushNotificationService 설정 (Firebase가 활성화된 경우)
        if (_pushService != null) {
          _jsHandler.setPushService(_pushService);
        }
        
        // Android WebView에서 geolocation 권한 설정 (플랫폼 초기화 후)
        _setupGeolocationPermissions();
        
        debugPrint('웹뷰 초기화 완료. 위치 권한 요청 준비됨.');
      }
    } catch (e, stackTrace) {
      debugPrint('웹뷰 초기화 오류: $e');
      debugPrint('스택 트레이스: $stackTrace');
    }
  }

  /// Android WebView에서 geolocation 권한 설정
  /// 플랫폼 채널을 통해 MainActivity의 WebChromeClient를 설정합니다.
  void _setupGeolocationPermissions() {
    // 플랫폼 채널을 통해 MainActivity에 geolocation 권한 처리를 요청
    const platform = MethodChannel('com.example.flutter_webview_app/geolocation');
    
    // 위치 권한이 허용되어 있으면 MainActivity에 알림
    Permission.location.status.then((status) {
      if (status.isGranted) {
        platform.invokeMethod('setGeolocationEnabled', {'enabled': true});
        debugPrint('MainActivity에 geolocation 권한 허용 알림 전송');
      }
    });
    
    debugPrint('geolocation 권한은 JavaScript 채널과 플랫폼 채널을 통해 처리됩니다.');
  }

  /// Android WebView 팝업 지원 설정
  /// webview_flutter_android의 API를 사용하여 팝업 지원을 활성화합니다.
  Future<void> _setupAndroidPopupSupport(AndroidWebViewController androidController) async {
    try {
      // webview_flutter_android의 onCreateWindow 콜백 설정 시도
      // API가 변경되었을 수 있으므로 try-catch로 처리
      debugPrint('Android WebView 팝업 지원 설정 시도');
      
      // 플랫폼 채널을 통해 MainActivity에 팝업 지원 활성화 요청
      const platform = MethodChannel('com.example.flutter_webview_app/webview');
      await platform.invokeMethod('enablePopupSupport');
      debugPrint('Android WebView 팝업 지원 활성화 요청 완료');
    } catch (e) {
      debugPrint('Android WebView 팝업 지원 활성화 오류: $e');
      // 오류가 발생해도 계속 진행 (webview_flutter는 기본적으로 팝업을 지원하지 않을 수 있음)
    }
  }

  /// Android WebView 파일 선택기 설정
  /// webview_flutter_android의 API를 사용하여 파일 선택기를 활성화합니다.
  Future<void> _setupAndroidFileChooser(AndroidWebViewController androidController) async {
    try {
      debugPrint('Android WebView 파일 선택기 설정 시도');
      
      // AndroidWebViewController의 setOnShowFileSelector 메서드 사용
      // 이 메서드는 webview_flutter_android 3.16.9 이상에서 사용 가능
      await androidController.setOnShowFileSelector((fileSelectorParams) async {
        debugPrint('파일 선택기 요청: ${fileSelectorParams.acceptTypes}');
        debugPrint('파일 선택 모드: ${fileSelectorParams.mode}');
        debugPrint('캡처 활성화: ${fileSelectorParams.isCaptureEnabled}');
        
        // 플랫폼 채널을 통해 MainActivity의 파일 선택기 호출
        const platform = MethodChannel('com.example.flutter_webview_app/webview');
        try {
          final result = await platform.invokeMethod('showFileChooser', {
            'acceptTypes': fileSelectorParams.acceptTypes,
            'acceptMultiple': fileSelectorParams.mode == FileSelectorMode.openMultiple,
            'captureEnabled': fileSelectorParams.isCaptureEnabled,
          });
          
          if (result != null && result is List) {
            final paths = result.map((path) => path.toString()).toList();
            debugPrint('파일 선택 완료: ${paths.length}개 파일');
            return paths;
          }
        } catch (e) {
          debugPrint('파일 선택기 호출 오류: $e');
        }
        
        return <String>[];
      });
      
      debugPrint('Android WebView 파일 선택기 설정 완료');
    } catch (e) {
      debugPrint('Android WebView 파일 선택기 설정 오류: $e');
      // 오류가 발생해도 계속 진행 (API가 없을 수 있음)
    }
  }

  /// JavaScript 브리지 주입
  void _injectJavaScriptBridge() {
    if (_controller == null) {
      debugPrint('_injectJavaScriptBridge: 컨트롤러가 null입니다.');
      return;
    }
    
    debugPrint('_injectJavaScriptBridge: JavaScript 브리지 주입 시작');
    
    final script = '''
      (function() {
        // Flutter 채널과 통신하는 헬퍼 함수
        window.flutterChannel = {
          postMessage: function(data) {
            if (typeof data === 'object') {
              data = JSON.stringify(data);
            }
            ${AppConfig.jsChannelName}.postMessage(data);
          },
          
          // FCM 토큰 요청
          getFCMToken: function() {
            window.flutterChannel.postMessage({
              action: 'getFCMToken'
            });
          },
          
          // 소셜 로그인 요청
          socialLogin: function(provider) {
            window.flutterChannel.postMessage({
              action: 'socialLogin',
              provider: provider
            });
          },
          
          // URL 열기
          openUrl: function(url) {
            window.flutterChannel.postMessage({
              action: 'openUrl',
              url: url
            });
          },
          
          // 새 창 열기 (팝업)
          openNewWindow: function(url) {
            window.flutterChannel.postMessage({
              action: 'openNewWindow',
              url: url
            });
          },
          
          // 새로고침
          reload: function() {
            window.flutterChannel.postMessage({
              action: 'reload'
            });
          },
          
          // alert 표시 (제목 없이)
          showAlert: function(message) {
            window.flutterChannel.postMessage({
              action: 'showAlert',
              message: message
            });
          },
          
          // confirm 표시 (제목 없이)
          showConfirm: function(message) {
            // 동기적으로 결과를 반환해야 하므로 Promise를 사용할 수 없음
            // 대신 고유 ID를 생성하고 결과를 기다림
            const confirmId = 'confirm_' + Date.now() + '_' + Math.random();
            window.flutterChannel.postMessage({
              action: 'showConfirm',
              message: message,
              confirmId: confirmId
            });
            
            // 결과를 기다리는 동안 블로킹 (간단한 폴링 방식)
            let result = null;
            const startTime = Date.now();
            const timeout = 30000; // 30초 타임아웃
            
            while (result === null && (Date.now() - startTime) < timeout) {
              if (window.flutterConfirmResults && window.flutterConfirmResults[confirmId] !== undefined) {
                result = window.flutterConfirmResults[confirmId];
                delete window.flutterConfirmResults[confirmId];
                break;
              }
              // 짧은 대기 (동기 블로킹)
              const endTime = Date.now() + 10;
              while (Date.now() < endTime) {
                // 빈 루프로 대기
              }
            }
            
            return result !== null ? result : false;
          },
          
          // prompt 표시 (제목 없이)
          showPrompt: function(message, defaultText) {
            const promptId = 'prompt_' + Date.now() + '_' + Math.random();
            window.flutterChannel.postMessage({
              action: 'showPrompt',
              message: message,
              defaultText: defaultText || '',
              promptId: promptId
            });
            
            // 결과를 기다리는 동안 블로킹
            let result = null;
            const startTime = Date.now();
            const timeout = 30000;
            
            while (result === null && (Date.now() - startTime) < timeout) {
              if (window.flutterPromptResults && window.flutterPromptResults[promptId] !== undefined) {
                result = window.flutterPromptResults[promptId];
                delete window.flutterPromptResults[promptId];
                break;
              }
              const endTime = Date.now() + 10;
              while (Date.now() < endTime) {
                // 빈 루프로 대기
              }
            }
            
            return result !== null ? result : null;
          }
        };
        
        // confirm/prompt 결과 저장소 초기화
        if (!window.flutterConfirmResults) {
          window.flutterConfirmResults = {};
        }
        if (!window.flutterPromptResults) {
          window.flutterPromptResults = {};
        }
        
        // FCM 토큰 수신 콜백
        window.onFCMTokenReceived = function(token) {
          console.log('FCM Token received:', token);
          // 웹사이트에서 필요한 경우 이 토큰을 사용할 수 있습니다
        };
        
        // 소셜 로그인 결과 수신 콜백
        window.onSocialLoginResult = function(result) {
          console.log('Social login result:', result);
          // 웹사이트에서 필요한 경우 이 결과를 사용할 수 있습니다
        };
        
        // Geolocation API 감지 및 Flutter 위치 서비스 연동
        if (navigator.geolocation) {
          console.log('Geolocation API 감지됨 - Flutter 위치 서비스 연동');
          
          // 위치 요청을 추적하기 위한 맵
          const locationRequests = new Map();
          let requestIdCounter = 0;
          
          // Flutter 위치 정보 수신 핸들러
          window.flutterLocationHandler = {
            onLocationReceived: function(position, requestId) {
              console.log('[Flutter] 위치 정보 수신:', position, 'requestId:', requestId);
              
              if (requestId && locationRequests.has(requestId)) {
                const request = locationRequests.get(requestId);
                locationRequests.delete(requestId);
                
                // Position 객체 생성
                const geolocationPosition = {
                  coords: {
                    latitude: position.coords.latitude,
                    longitude: position.coords.longitude,
                    accuracy: position.coords.accuracy || 0,
                    altitude: position.coords.altitude || null,
                    altitudeAccuracy: position.coords.altitudeAccuracy || null,
                    heading: position.coords.heading || null,
                    speed: position.coords.speed || null
                  },
                  timestamp: position.timestamp || Date.now()
                };
                
                if (request.success) {
                  console.log('[Flutter] 성공 콜백 호출');
                  request.success(geolocationPosition);
                }
              } else {
                console.warn('[Flutter] 알 수 없는 requestId:', requestId);
              }
            },
            
            onLocationError: function(error, requestId) {
              console.error('[Flutter] 위치 오류 수신:', error, 'requestId:', requestId);
              
              if (requestId && locationRequests.has(requestId)) {
                const request = locationRequests.get(requestId);
                locationRequests.delete(requestId);
                
                // GeolocationPositionError 객체 생성
                const geolocationError = {
                  code: error.code || 1,
                  message: error.message || 'Unknown error',
                  PERMISSION_DENIED: 1,
                  POSITION_UNAVAILABLE: 2,
                  TIMEOUT: 3
                };
                
                if (request.error) {
                  console.error('[Flutter] 오류 콜백 호출');
                  request.error(geolocationError);
                }
              } else {
                console.warn('[Flutter] 알 수 없는 requestId:', requestId);
              }
            }
          };
          
          // getCurrentPosition 오버라이드
          navigator.geolocation.getCurrentPosition = function(success, error, options) {
            const requestId = 'getCurrentPosition_' + (++requestIdCounter) + '_' + Date.now();
            console.log('[Flutter] getCurrentPosition 호출됨 - requestId:', requestId);
            
            // 요청 정보 저장
            locationRequests.set(requestId, {
              success: success,
              error: error,
              options: options,
              type: 'getCurrentPosition'
            });
            
            // Flutter로 위치 권한 요청 및 위치 정보 요청
            try {
              const message = JSON.stringify({
                action: 'requestLocationPermission',
                requestId: requestId
              });
              console.log('[Flutter] Flutter 채널로 메시지 전송:', message);
              ${AppConfig.jsChannelName}.postMessage(message);
            } catch (e) {
              console.error('[Flutter] 권한 요청 메시지 전송 실패:', e);
              if (error) {
                error({
                  code: 1,
                  message: 'Failed to request location permission',
                  PERMISSION_DENIED: 1,
                  POSITION_UNAVAILABLE: 2,
                  TIMEOUT: 3
                });
              }
            }
          };
          
          // watchPosition 오버라이드
          navigator.geolocation.watchPosition = function(success, error, options) {
            const watchId = 'watchPosition_' + (++requestIdCounter) + '_' + Date.now();
            console.log('[Flutter] watchPosition 호출됨 - watchId:', watchId);
            
            // watchPosition은 watchId를 반환해야 함
            let watchInterval = null;
            let lastPosition = null;
            
            // 주기적으로 위치 정보 요청 (옵션에 따라)
            const updateInterval = (options && options.interval) ? options.interval : 10000; // 기본 10초
            
            const requestLocation = function() {
              const requestId = watchId + '_' + Date.now();
              
              // 요청 정보 저장
              locationRequests.set(requestId, {
                success: function(position) {
                  lastPosition = position;
                  if (success) success(position);
                },
                error: error,
                options: options,
                type: 'watchPosition',
                watchId: watchId
              });
              
              // Flutter로 위치 정보 요청
              try {
                const message = JSON.stringify({
                  action: 'getCurrentLocation',
                  requestId: requestId
                });
                console.log('[Flutter] watchPosition - Flutter 채널로 메시지 전송:', message);
                ${AppConfig.jsChannelName}.postMessage(message);
              } catch (e) {
                console.error('[Flutter] 위치 요청 메시지 전송 실패:', e);
                if (error) {
                  error({
                    code: 1,
                    message: 'Failed to request location',
                    PERMISSION_DENIED: 1,
                    POSITION_UNAVAILABLE: 2,
                    TIMEOUT: 3
                  });
                }
              }
            };
            
            // 즉시 한 번 요청
            requestLocation();
            
            // 주기적으로 요청
            watchInterval = setInterval(requestLocation, updateInterval);
            
            // clearWatch를 위한 저장
            if (!window.flutterWatchPositions) {
              window.flutterWatchPositions = new Map();
            }
            window.flutterWatchPositions.set(watchId, {
              interval: watchInterval,
              success: success,
              error: error
            });
            
            return watchId;
          };
          
          // clearWatch 오버라이드
          const originalClearWatch = navigator.geolocation.clearWatch.bind(navigator.geolocation);
          navigator.geolocation.clearWatch = function(watchId) {
            console.log('[Flutter] clearWatch 호출됨 - watchId:', watchId);
            
            if (window.flutterWatchPositions && window.flutterWatchPositions.has(watchId)) {
              const watch = window.flutterWatchPositions.get(watchId);
              if (watch.interval) {
                clearInterval(watch.interval);
              }
              window.flutterWatchPositions.delete(watchId);
              console.log('[Flutter] watchPosition 중지됨');
            }
            
            // 원래 함수도 호출
            originalClearWatch(watchId);
          };
          
          console.log('Geolocation API 오버라이드 완료 - Flutter 위치 서비스 연동');
        } else {
          console.warn('Geolocation API를 사용할 수 없습니다');
        }
        
        console.log('[Flutter] Flutter JavaScript Bridge initialized');
        console.log('[Flutter] flutterChannel 존재 여부:', typeof window.flutterChannel !== 'undefined');
        console.log('[Flutter] openNewWindow 존재 여부:', window.flutterChannel && typeof window.flutterChannel.openNewWindow !== 'undefined');
        
        // Daum Postcode 결과 수신 리스너
        window.addEventListener('message', function(event) {
          console.log('[Flutter] postMessage 수신:', event.data);
          if (event.data && event.data.type === 'daumPostcodeComplete') {
            console.log('[Flutter] Daum Postcode 결과 수신:', event.data.data);
            const postcodeData = event.data.data;
            
            // Daum Postcode 결과를 웹 페이지에 전달
            // 여러 방법으로 시도하여 웹 페이지가 결과를 받을 수 있도록 함
            
            // 방법 1: 전역 함수 호출
            if (typeof window.handlePostcodeResult === 'function') {
              console.log('[Flutter] window.handlePostcodeResult 호출');
              window.handlePostcodeResult(postcodeData);
            }
            
            // 방법 2: 전역 변수에 저장
            window.postcodeResult = postcodeData;
            
            // 방법 3: CustomEvent 발생
            const postcodeEvent = new CustomEvent('postcodeComplete', { detail: postcodeData });
            window.dispatchEvent(postcodeEvent);
            
            // 방법 4: initDaumPostcode 함수가 있는 경우 (일반적인 패턴)
            if (typeof window.initDaumPostcode === 'function') {
              // 이미 호출되었을 수 있으므로 결과만 전달
              if (window.daumPostcodeCallback) {
                window.daumPostcodeCallback(postcodeData);
              }
            }
            
            // 방법 5: 전역 객체에 저장 (다양한 패턴 지원)
            if (!window.daumPostcodeResults) {
              window.daumPostcodeResults = [];
            }
            window.daumPostcodeResults.push(postcodeData);
            
            // 방법 6: jQuery 이벤트 (jQuery가 있는 경우)
            if (typeof jQuery !== 'undefined') {
              jQuery(window).trigger('postcodeComplete', postcodeData);
            }
            
            console.log('[Flutter] Daum Postcode 결과 처리 완료');
          }
        });
        
        // JavaScript alert, confirm, prompt 오버라이드 (제목 제거)
        (function() {
          // alert 오버라이드
          const originalAlert = window.alert;
          window.alert = function(message) {
            console.log('[Flutter] alert 호출:', message);
            if (window.flutterChannel && window.flutterChannel.showAlert) {
              window.flutterChannel.showAlert(message);
            } else {
              originalAlert.call(window, message);
            }
          };
          
          // confirm 오버라이드
          const originalConfirm = window.confirm;
          window.confirm = function(message) {
            console.log('[Flutter] confirm 호출:', message);
            if (window.flutterChannel && window.flutterChannel.showConfirm) {
              return window.flutterChannel.showConfirm(message);
            } else {
              return originalConfirm.call(window, message);
            }
          };
          
          // prompt 오버라이드
          const originalPrompt = window.prompt;
          window.prompt = function(message, defaultText) {
            console.log('[Flutter] prompt 호출:', message, defaultText);
            if (window.flutterChannel && window.flutterChannel.showPrompt) {
              return window.flutterChannel.showPrompt(message, defaultText);
            } else {
              return originalPrompt.call(window, message, defaultText);
            }
          };
          
        console.log('JavaScript alert/confirm/prompt 오버라이드 완료');
      })();
      
      // initDaumPostcode() 함수 오버라이드 - 네이티브 우편번호 검색 사용
      // WebView 팝업 크래시 문제를 해결하기 위해 네이티브 Flutter 화면을 사용합니다.
      (function() {
        console.log('[Flutter] initDaumPostcode 오버라이드 시작');
        
        // 원래 initDaumPostcode 함수 저장 (있을 경우)
        const originalInitDaumPostcode = window.initDaumPostcode;
        
        // initDaumPostcode() 함수 오버라이드
        window.initDaumPostcode = function() {
          console.log('[Flutter] initDaumPostcode 호출 감지, 네이티브 우편번호 검색 실행');
          
          // Flutter로 메시지 전송하여 네이티브 우편번호 검색 실행
          try {
            const message = JSON.stringify({
              action: 'searchPostcode'
            });
            ${AppConfig.jsChannelName}.postMessage(message);
            console.log('[Flutter] 네이티브 우편번호 검색 요청 전송 완료');
          } catch (e) {
            console.error('[Flutter] 우편번호 검색 요청 실패:', e);
            // 실패 시 원래 함수 호출 (fallback)
            if (originalInitDaumPostcode && typeof originalInitDaumPostcode === 'function') {
              console.log('[Flutter] fallback: 원래 initDaumPostcode 호출');
              originalInitDaumPostcode.call(this);
            } else {
              console.error('[Flutter] 원래 initDaumPostcode 함수를 찾을 수 없습니다');
            }
          }
        };
        
        console.log('[Flutter] initDaumPostcode 오버라이드 완료');
      })();
      
      // 이미지 길게 누르기 이벤트 처리
      (function() {
        console.log('[Flutter] 이미지 길게 누르기 이벤트 리스너 추가');
        
        // 모든 이미지에 길게 누르기 이벤트 리스너 추가
        function addImageLongPressListeners() {
          const images = document.querySelectorAll('img');
          images.forEach(function(img) {
            // 이미 리스너가 추가되었는지 확인
            if (img.dataset.flutterLongPressAdded === 'true') {
              return;
            }
            
            img.dataset.flutterLongPressAdded = 'true';
            
            // touchstart 이벤트로 길게 누르기 감지
            let touchStartTime = 0;
            let touchTimer = null;
            
            img.addEventListener('touchstart', function(e) {
              touchStartTime = Date.now();
              touchTimer = setTimeout(function() {
                // 500ms 이상 누르고 있으면 길게 누르기로 간주
                const imageUrl = img.src || img.getAttribute('data-src') || img.getAttribute('data-original');
                if (imageUrl && imageUrl.startsWith('http')) {
                  console.log('[Flutter] 이미지 길게 누르기 감지:', imageUrl);
                  
                  // Flutter로 이미지 URL 전송
                  try {
                    const message = JSON.stringify({
                      action: 'saveImage',
                      imageUrl: imageUrl
                    });
                    ${AppConfig.jsChannelName}.postMessage(message);
                    console.log('[Flutter] 이미지 저장 요청 전송 완료');
                  } catch (e) {
                    console.error('[Flutter] 이미지 저장 요청 전송 실패:', e);
                  }
                }
              }, 500); // 500ms
            }, { passive: true });
            
            img.addEventListener('touchend', function(e) {
              if (touchTimer) {
                clearTimeout(touchTimer);
                touchTimer = null;
              }
            }, { passive: true });
            
            img.addEventListener('touchcancel', function(e) {
              if (touchTimer) {
                clearTimeout(touchTimer);
                touchTimer = null;
              }
            }, { passive: true });
          });
        }
        
        // 페이지 로드 시 이미지 리스너 추가
        addImageLongPressListeners();
        
        // 동적으로 추가되는 이미지를 위해 MutationObserver 사용
        const observer = new MutationObserver(function(mutations) {
          addImageLongPressListeners();
        });
        
        observer.observe(document.body, {
          childList: true,
          subtree: true
        });
        
        console.log('[Flutter] 이미지 길게 누르기 이벤트 리스너 추가 완료');
      })();
        
        // 위에서 당겨서 새로고침 기능 (300px 또는 3초 이상)
        let pullToRefreshStartY = 0;
        let pullToRefreshDistance = 0;
        let pullToRefreshStartTime = 0;
        let isRefreshing = false;
        const PULL_TO_REFRESH_DISTANCE_THRESHOLD = 300; // 300px 이상 당겨야 함
        const PULL_TO_REFRESH_TIME_THRESHOLD = 3000; // 3초 이상 유지해야 함
        
        // 새로고침 인디케이터 UI 생성 (간단한 텍스트 표시)
        function createPullToRefreshIndicator() {
          if (document.getElementById('flutter-pull-to-refresh-indicator')) {
            return; // 이미 존재하면 생성하지 않음
          }
          
          const indicator = document.createElement('div');
          indicator.id = 'flutter-pull-to-refresh-indicator';
          indicator.style.cssText = 'position: fixed; top: 20px; left: 50%; transform: translateX(-50%); padding: 8px 16px; background-color: rgba(0, 0, 0, 0.7); color: white; border-radius: 20px; font-size: 12px; z-index: 9999; display: none; pointer-events: none; white-space: nowrap;';
          indicator.textContent = '새로고침하려면 더 당기세요';
          document.body.appendChild(indicator);
        }
        
        // 인디케이터 업데이트
        function updatePullToRefreshIndicator(distance, elapsedTime) {
          const indicator = document.getElementById('flutter-pull-to-refresh-indicator');
          if (!indicator) return;
          
          const distanceMet = distance >= PULL_TO_REFRESH_DISTANCE_THRESHOLD;
          const timeMet = elapsedTime >= PULL_TO_REFRESH_TIME_THRESHOLD;
          const canRefresh = distanceMet || timeMet;
          
          if (distance > 0) {
            indicator.style.display = 'block';
            indicator.style.top = (Math.min(distance, 100) + 20) + 'px';
            
            if (canRefresh) {
              indicator.textContent = '손을 떼면 새로고침됩니다';
              indicator.style.backgroundColor = 'rgba(76, 175, 80, 0.9)';
            } else {
              const distancePercent = Math.min(100, (distance / PULL_TO_REFRESH_DISTANCE_THRESHOLD) * 100);
              const timePercent = Math.min(100, (elapsedTime / PULL_TO_REFRESH_TIME_THRESHOLD) * 100);
              const maxPercent = Math.max(distancePercent, timePercent);
              indicator.textContent = '새로고침: ' + Math.round(maxPercent) + '%';
              indicator.style.backgroundColor = 'rgba(0, 0, 0, 0.7)';
            }
          } else {
            indicator.style.display = 'none';
          }
        }
        
        // 인디케이터 숨기기
        function hidePullToRefreshIndicator() {
          const indicator = document.getElementById('flutter-pull-to-refresh-indicator');
          if (indicator) {
            indicator.style.display = 'none';
          }
        }
        
        // 인디케이터 UI 초기화
        createPullToRefreshIndicator();
        
        document.addEventListener('touchstart', function(e) {
          // 페이지 최상단에서만 새로고침 가능 (스크롤 위치 확인)
          const scrollTop = window.pageYOffset || document.documentElement.scrollTop || document.body.scrollTop || 0;
          if (scrollTop <= 5 && !isRefreshing) {
            pullToRefreshStartY = e.touches[0].clientY;
            pullToRefreshDistance = 0;
            pullToRefreshStartTime = Date.now();
          } else {
            pullToRefreshStartY = 0;
            pullToRefreshStartTime = 0;
          }
        }, { passive: true });
        
        document.addEventListener('touchmove', function(e) {
          if (pullToRefreshStartY > 0 && !isRefreshing) {
            const scrollTop = window.pageYOffset || document.documentElement.scrollTop || document.body.scrollTop || 0;
            // 최상단에서만 작동
            if (scrollTop <= 5) {
              pullToRefreshDistance = e.touches[0].clientY - pullToRefreshStartY;
              const elapsedTime = Date.now() - pullToRefreshStartTime;
              
              // 아래로 당기는 경우만 (위로 당기는 경우는 무시)
              if (pullToRefreshDistance > 0) {
                updatePullToRefreshIndicator(pullToRefreshDistance, elapsedTime);
                // 지도 드래그 방지를 위해 일정 거리 이상 당기면 기본 동작 방지
                if (pullToRefreshDistance > 50) {
                  e.preventDefault();
                }
              } else {
                hidePullToRefreshIndicator();
              }
            } else {
              pullToRefreshStartY = 0;
              pullToRefreshStartTime = 0;
              hidePullToRefreshIndicator();
            }
          }
        }, { passive: false });
        
        document.addEventListener('touchend', function(e) {
          if (pullToRefreshStartY > 0 && !isRefreshing) {
            const scrollTop = window.pageYOffset || document.documentElement.scrollTop || document.body.scrollTop || 0;
            const elapsedTime = Date.now() - pullToRefreshStartTime;
            
            // 500px 이상 당기거나 5초 이상 유지했으면 새로고침 트리거
            const distanceMet = pullToRefreshDistance >= PULL_TO_REFRESH_DISTANCE_THRESHOLD;
            const timeMet = elapsedTime >= PULL_TO_REFRESH_TIME_THRESHOLD;
            
            if ((distanceMet || timeMet) && scrollTop <= 5) {
              isRefreshing = true;
              console.log('[Flutter] 위에서 당겨서 새로고침 트리거 (거리: ' + pullToRefreshDistance + 'px, 시간: ' + elapsedTime + 'ms)');
              
              // 새로고침 실행
              if (window.flutterChannel && window.flutterChannel.reload) {
                window.flutterChannel.reload();
              }
              
              // 새로고침 완료 후 플래그 및 UI 리셋
              setTimeout(function() {
                isRefreshing = false;
                hidePullToRefreshIndicator();
              }, 2000);
            } else {
              // 조건 미달이면 인디케이터만 숨김
              hidePullToRefreshIndicator();
            }
          }
          pullToRefreshStartY = 0;
          pullToRefreshDistance = 0;
          pullToRefreshStartTime = 0;
        }, { passive: true });
      })();
    ''';
    try {
      _controller?.runJavaScript(script);
      debugPrint('_injectJavaScriptBridge: JavaScript 브리지 주입 완료');
    } catch (e, stackTrace) {
      debugPrint('_injectJavaScriptBridge: JavaScript 브리지 주입 오류: $e');
      debugPrint('스택 트레이스: $stackTrace');
    }
  }

  /// 다이얼로그 WebView에 JavaScript 브리지 주입 (Daum Postcode 등 팝업 지원)
  Future<void> _injectJavaScriptBridgeToDialog(WebViewController controller) async {
    try {
      debugPrint('_injectJavaScriptBridgeToDialog: JavaScript 브리지 주입 시작');
      
      // 다이얼로그 WebView에서는 window.open()을 원래 동작으로 유지
      // (Daum Postcode가 다이얼로그 내에서도 정상 작동하도록)
      final script = '''
        (function() {
          console.log('[Flutter Dialog] JavaScript 브리지 초기화 시작');
          
          // window.open()이 이미 오버라이드되어 있다면 복원
          if (window.flutterOriginalWindowOpen) {
            console.log('[Flutter Dialog] window.open() 복원');
            window.open = window.flutterOriginalWindowOpen;
          }
          
          console.log('[Flutter Dialog] JavaScript 브리지 초기화 완료');
        })();
      ''';
      
      await controller.runJavaScript(script);
      debugPrint('_injectJavaScriptBridgeToDialog: JavaScript 브리지 주입 완료');
    } catch (e, stackTrace) {
      debugPrint('_injectJavaScriptBridgeToDialog: JavaScript 브리지 주입 오류: $e');
      debugPrint('스택 트레이스: $stackTrace');
    }
  }


  /// 네비게이션 상태 업데이트
  Future<void> _updateNavigationState() async {
    if (_controller == null) return;
    
    final canGoBack = await _controller!.canGoBack();
    final canGoForward = await _controller!.canGoForward();
    
    if (mounted) {
      setState(() {
        _canGoBack = canGoBack;
        _canGoForward = canGoForward;
      });
    }
  }

  /// URL 실행 (전화, 문자 등)
  Future<void> _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        debugPrint('외부 앱 실행 성공: $url');
      } else {
        debugPrint('외부 앱 실행 실패: $url');
      }
    } catch (e) {
      debugPrint('외부 앱 실행 오류: $e');
    }
  }

  /// 네이티브 우편번호 검색 실행
  void _searchPostcode() async {
    debugPrint('네이티브 우편번호 검색 시작');
    
    if (!mounted) {
      debugPrint('위젯이 마운트되지 않았습니다. 우편번호 검색 취소');
      return;
    }
    
    try {
      // 로컬 서버 시작
      _postcodeServer ??= DaumPostcodeLocalServer();
      if (!_postcodeServer!.isRunning) {
        await _postcodeServer!.start();
        debugPrint('우편번호 검색 로컬 서버 시작: ${_postcodeServer!.url}');
      }
      
      // WebView를 사용한 다이얼로그 표시
      final result = await Navigator.of(context).push<DataModel>(
        MaterialPageRoute(
          builder: (context) => _DaumPostcodeDialog(
            serverUrl: _postcodeServer!.url,
            onResult: (data) {
              // DaumPostcodeChannel에서 이미 pop(data)를 호출하므로 여기서는 처리 불필요
              // 하지만 콜백이 필요할 수 있으므로 유지
            },
          ),
        ),
      );
      
      if (result != null) {
        debugPrint('우편번호 검색 결과: $result');
        _handleNativePostcodeResult(result);
      } else {
        debugPrint('우편번호 검색이 취소되었습니다.');
      }
    } catch (e, stackTrace) {
      debugPrint('우편번호 검색 오류: $e');
      debugPrint('스택 트레이스: $stackTrace');
    }
  }

  /// 네이티브 우편번호 검색 결과 처리
  void _handleNativePostcodeResult(DataModel result) {
    debugPrint('네이티브 우편번호 검색 결과 처리: ${result.toString()}');
    
    if (_controller != null && mounted) {
      // 우편번호와 주소를 웹 페이지의 input 필드에 설정
      // postal ID에 zonecode 설정
      // addr ID에 roadAddress 또는 jibunAddress 설정
      
      final zonecode = result.zonecode ?? '';
      final roadAddress = result.roadAddress ?? '';
      final jibunAddress = result.jibunAddress ?? '';
      final address = roadAddress.isNotEmpty ? roadAddress : jibunAddress;
      
      debugPrint('우편번호: $zonecode, 주소: $address');
      
      // JavaScript로 input 필드에 값 설정
      final script = '''
        (function() {
          try {
            console.log('[Flutter] 네이티브 우편번호 검색 결과를 필드에 설정');
            
            // postal 필드에 우편번호 설정
            const postalField = document.getElementById('postal');
            if (postalField) {
              postalField.value = '$zonecode';
              console.log('[Flutter] postal 필드에 우편번호 설정: $zonecode');
              
              // change 이벤트 발생 (웹 페이지의 이벤트 리스너 트리거)
              postalField.dispatchEvent(new Event('change', { bubbles: true }));
              postalField.dispatchEvent(new Event('input', { bubbles: true }));
            } else {
              console.error('[Flutter] postal 필드를 찾을 수 없습니다');
            }
            
            // addr 필드에 주소 설정 (도로명 주소 우선)
            const addrField = document.getElementById('addr');
            if (addrField) {
              const roadAddr = '$roadAddress';
              addrField.value = roadAddr || '$jibunAddress';
              console.log('[Flutter] addr 필드에 주소 설정:', addrField.value);
              
              // change 이벤트 발생 (웹 페이지의 이벤트 리스너 트리거)
              addrField.dispatchEvent(new Event('change', { bubbles: true }));
              addrField.dispatchEvent(new Event('input', { bubbles: true }));
            } else {
              console.error('[Flutter] addr 필드를 찾을 수 없습니다');
            }
            
            // oncomplete 콜백이 있으면 호출 (웹 페이지가 콜백을 등록한 경우)
            if (typeof window.daumPostcodeCallback === 'function') {
              console.log('[Flutter] window.daumPostcodeCallback 호출');
              window.daumPostcodeCallback({
                zonecode: '$zonecode',
                roadAddress: '$roadAddress',
                jibunAddress: '$jibunAddress',
                address: '$address'
              });
            }
            
            console.log('[Flutter] 우편번호 검색 결과 설정 완료');
          } catch (e) {
            console.error('[Flutter] 우편번호 검색 결과 설정 오류:', e);
          }
        })();
      ''';
      
      try {
        _controller!.runJavaScript(script);
        debugPrint('우편번호 검색 결과를 웹 페이지에 설정 완료');
      } catch (e, stackTrace) {
        debugPrint('우편번호 검색 결과 설정 오류: $e');
        debugPrint('스택 트레이스: $stackTrace');
      }
    } else {
      debugPrint('WebViewController가 null이거나 위젯이 마운트되지 않았습니다.');
    }
  }

  /// 이미지 저장 (웹뷰에서 이미지 길게 누르기)
  Future<void> _saveImage(String imageUrl) async {
    debugPrint('이미지 저장 요청: $imageUrl');
    
    if (!mounted) {
      debugPrint('위젯이 마운트되지 않았습니다. 이미지 저장 취소');
      return;
    }

    // 저장 확인 다이얼로그 표시
    final shouldSave = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: const Text('이미지를 저장하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: const Text('저장'),
            ),
          ],
        );
      },
    );

    // 사용자가 취소한 경우
    if (shouldSave != true) {
      debugPrint('사용자가 이미지 저장을 취소했습니다.');
      return;
    }

    try {
      // 저장소 권한 확인
      if (Platform.isAndroid) {
        // Android 13 이상은 photos 권한, 이전 버전은 storage 권한
        // Android 13 (API 33) 이상에서는 photos 권한 사용
        Permission permission = Permission.photos;
        
        final status = await permission.status;
        if (!status.isGranted) {
          final result = await permission.request();
          if (!result.isGranted) {
            // Android 13 미만에서는 storage 권한 시도
            if (await Permission.storage.isDenied) {
              final storageResult = await Permission.storage.request();
              if (!storageResult.isGranted) {
                if (mounted) {
                  _showAlertDialog('이미지를 저장하려면 저장소 권한이 필요합니다.');
                }
                return;
              }
            } else if (!status.isGranted) {
              if (mounted) {
                _showAlertDialog('이미지를 저장하려면 저장소 권한이 필요합니다.');
              }
              return;
            }
          }
        }
      } else if (Platform.isIOS) {
        // iOS는 photoLibrary 권한 확인
        final status = await Permission.photos.status;
        if (!status.isGranted) {
          final result = await Permission.photos.request();
          if (!result.isGranted) {
            if (mounted) {
              _showAlertDialog('이미지를 저장하려면 사진 라이브러리 권한이 필요합니다.');
            }
            return;
          }
        }
      }

      // 이미지 다운로드
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('이미지를 다운로드하는 중...'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        final Uint8List imageBytes = response.bodyBytes;
        
        // 플랫폼 채널을 통해 갤러리에 저장
        const platform = MethodChannel('com.example.flutter_webview_app/image');
        
        try {
          // Uint8List를 List<int>로 변환하여 전달
          final result = await platform.invokeMethod('saveImageToGallery', {
            'imageBytes': imageBytes.toList(),
            'fileName': 'image_${DateTime.now().millisecondsSinceEpoch}.jpg',
          });
          
          if (mounted) {
            if (result == true) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('이미지가 갤러리에 저장되었습니다.'),
                  duration: Duration(seconds: 2),
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('이미지 저장에 실패했습니다.'),
                  duration: Duration(seconds: 2),
                ),
              );
            }
          }
        } catch (e) {
          debugPrint('이미지 저장 플랫폼 채널 오류: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('이미지 저장 중 오류가 발생했습니다.'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      } else {
        debugPrint('이미지 다운로드 실패: ${response.statusCode}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('이미지를 다운로드할 수 없습니다.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      debugPrint('이미지 저장 오류: $e');
      debugPrint('스택 트레이스: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('이미지 저장 중 오류가 발생했습니다: ${e.toString()}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// Alert 다이얼로그 표시 (제목 없이)
  void _showAlertDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }

  /// Confirm 다이얼로그 표시 (제목 없이)
  void _showConfirmDialog(String message, String confirmId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // JavaScript로 false 전송
                if (_controller != null) {
                  _jsHandler.sendConfirmResultToWebView(_controller!, confirmId, false);
                }
              },
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // JavaScript로 true 전송
                if (_controller != null) {
                  _jsHandler.sendConfirmResultToWebView(_controller!, confirmId, true);
                }
              },
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }

  /// Prompt 다이얼로그 표시 (제목 없이)
  void _showPromptDialog(String message, String defaultText, String promptId) {
    final TextEditingController textController = TextEditingController(text: defaultText);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message),
              const SizedBox(height: 16),
              TextField(
                controller: textController,
                autofocus: true,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // JavaScript로 null 전송 (취소)
                if (_controller != null) {
                  _jsHandler.sendPromptResultToWebView(_controller!, promptId, null);
                }
                textController.dispose();
              },
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // JavaScript로 입력값 전송
                if (_controller != null) {
                  _jsHandler.sendPromptResultToWebView(_controller!, promptId, textController.text);
                }
                textController.dispose();
              },
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }

  /// 푸시 알림 설정
  void _setupPushNotifications() {
    if (_pushService == null) return;
    
    try {
      // FCM 토큰이 준비되면 웹뷰로 전송
      _pushTokenSubscription = _pushService!.tokenStream?.listen((token) {
        if (_controller != null) {
          _jsHandler.sendFCMTokenToWebView(_controller!, token);
        }
      });

      // 푸시 알림 메시지 수신 시 처리
      _pushMessageSubscription = _pushService!.messageStream?.listen((message) {
        final url = _pushService!.getUrlFromMessage(message);
        if (url != null && _controller != null) {
          _controller!.loadRequest(Uri.parse(url));
        }
      });
    } catch (e) {
      debugPrint('푸시 알림 설정 오류: $e');
    }
  }

  @override
  void dispose() {
    _pushTokenSubscription?.cancel();
    _pushMessageSubscription?.cancel();
    _postcodeServer?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (!didPop) {
          await _onWillPop();
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            // WebView (SafeArea로 상태바 영역 제외) - 자체 스크롤 활성화
            if (_controller != null)
              SafeArea(
                top: true,
                bottom: true,
                child: WebViewWidget(controller: _controller!),
              )
            else
              const Center(
                child: CircularProgressIndicator(),
              ),
            // 로딩 진행 표시 (웹뷰 최상단에 고정)
            if (_isLoading)
              Positioned(
                top: MediaQuery.of(context).padding.top,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(
                  value: _loadingProgress,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).primaryColor,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Daum 우편번호 검색 다이얼로그
class _DaumPostcodeDialog extends StatefulWidget {
  final String serverUrl;
  final Function(DataModel) onResult;

  const _DaumPostcodeDialog({
    required this.serverUrl,
    required this.onResult,
  });

  @override
  State<_DaumPostcodeDialog> createState() => _DaumPostcodeDialogState();
}

class _DaumPostcodeDialogState extends State<_DaumPostcodeDialog> {
  WebViewController? _dialogController;
  late final JsChannelHandler _dialogJsHandler;
  String _pageTitle = '주소 검색';

  @override
  void initState() {
    super.initState();
    _dialogJsHandler = JsChannelHandler();
    _initializeDialogWebView();
  }

  Future<void> _initializeDialogWebView() async {
    try {
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..enableZoom(true)
        ..setBackgroundColor(Colors.white);

      controller
        ..addJavaScriptChannel(
          'DaumPostcodeChannel',
          onMessageReceived: (JavaScriptMessage message) {
            debugPrint('DaumPostcodeChannel 메시지 수신: ${message.message}');
            // HTML에서 직접 JSON.stringify(data)를 보내므로 바로 파싱
            try {
              final data = jsonDecode(message.message) as Map<String, dynamic>;
              final result = DataModel.fromMap(data);
              debugPrint('우편번호 검색 결과 파싱 완료: zonecode=${result.zonecode}, roadAddress=${result.roadAddress}');
              // 결과를 전달하고 다이얼로그 닫기 (pop(data)로 결과 반환)
              if (mounted && Navigator.of(context).canPop()) {
                Navigator.of(context).pop(result);
              }
            } catch (e) {
              debugPrint('DaumPostcodeChannel 파싱 오류: $e');
            }
          },
        )
        ..addJavaScriptChannel(
          AppConfig.jsChannelName,
          onMessageReceived: (JavaScriptMessage message) {
            _dialogJsHandler.handleMessage(message.message);
          },
        )
        ..setNavigationDelegate(
          NavigationDelegate(
            onNavigationRequest: (NavigationRequest request) {
              // URL Scheme 콜백 처리
              if (DaumPostcodeCallbackParser.isCallbackUrl(request.url)) {
                final result = DaumPostcodeCallbackParser.fromUrlScheme(request.url);
                if (result != null) {
                  widget.onResult(result);
                }
                return NavigationDecision.prevent;
              }
              return NavigationDecision.navigate;
            },
            onPageFinished: (String url) async {
              // HTML 파일이 이미 DaumPostcodeChannel을 사용하므로 추가 설정 불필요
              debugPrint('우편번호 검색 페이지 로드 완료: $url');
              
              // 웹 페이지 제목 가져오기
              try {
                final title = await controller.getTitle();
                if (mounted) {
                  setState(() {
                    _pageTitle = (title != null && title.isNotEmpty) ? title : '주소 검색';
                  });
                }
              } catch (e) {
                debugPrint('페이지 제목 가져오기 오류: $e');
                // 오류 발생 시 기본값 유지
              }
            },
          ),
        );
      
      // 로컬 서버 URL 생성: 전체 경로 사용 (로컬 서버가 rootBundle.load()로 로드)
      final postcodeUrl = '${widget.serverUrl}/${DaumPostcodeAssets.jsChannel}';
      debugPrint('우편번호 검색 URL: $postcodeUrl');
      controller.loadRequest(Uri.parse(postcodeUrl));

      if (mounted) {
        setState(() {
          _dialogController = controller;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('다이얼로그 웹뷰 초기화 오류: $e');
      debugPrint('스택 트레이스: $stackTrace');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: EdgeInsets.zero,
      child: SafeArea(
        child: Container(
          width: MediaQuery.of(context).size.width,
          height: MediaQuery.of(context).size.height,
          child: Column(
            children: [
              // 제목 바 (닫기 버튼 포함)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: const Border(
                    bottom: BorderSide(
                      color: Colors.grey,
                      width: 1.0,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _pageTitle,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        Navigator.of(context).pop();
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Icon(Icons.close, color: Colors.black, size: 24),
                      ),
                    ),
                  ),
                ],
              ),
            ),
              // WebView
              Expanded(
                child: _dialogController != null
                    ? WebViewWidget(controller: _dialogController!)
                    : const Center(
                        child: CircularProgressIndicator(),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
