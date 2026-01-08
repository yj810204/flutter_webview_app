/// 앱 설정 관리 클래스 - 단일 소스 오브 트루스 (Single Source of Truth)
/// 
/// ⚠️ 중요: 이 파일이 모든 플랫폼(Android, iOS)의 설정 기준입니다.
/// 이 파일을 수정하면 Android와 iOS의 네이티브 설정이 자동으로 동기화됩니다.
/// 
/// 설정 변경 후 빌드하면 자동으로 네이티브 설정 파일이 생성됩니다.
/// 수동으로 생성하려면: dart scripts/generate_native_config.dart
/// 
/// Android: android/app/src/main/kotlin/.../AppConfig.kt (자동 생성)
/// iOS: ios/Runner/AppConfig.swift (자동 생성)
class AppConfig {
  // ==================== 웹사이트 및 서버 설정 ====================
  /// 웹사이트 URL - 여기서 변경하면 다른 웹사이트용 앱으로 변환 가능
  /// Android/iOS 네이티브 코드에 자동 동기화됨
  static const String websiteUrl = 'https://codejaka01.cafe24.com/mb_test/';
  
  /// 서버 API 경로 - Android/iOS에 자동 동기화됨
  static const String serverApiPathAppInfo = 'modules/appmgmt/libs/appInfo.php';
  static const String serverApiPathAppInfoIOS = 'modules/appmgmt/libs/appInfo_ios.php';
  static const String serverApiPathDeviceToken = 'modules/appmgmt/libs/deviceToken.php';
  
  // ==================== 앱 정보 ====================
  /// 앱 이름
  static const String appName = 'Flutter WebView App';
  
  /// Android 패키지명 - Android에 자동 동기화됨
  static const String androidPackageName = 'hello.mobile';
  
  /// iOS 번들 ID - iOS에 자동 동기화됨
  static const String iosBundleId = 'com.hello.mobile';
  
  /// 앱 버전 (User-Agent에 사용) - Android/iOS에 자동 동기화됨
  /// package_info_plus로 가져올 수도 있지만, 여기서 설정 가능
  static const String appVersion = '1.4.1';
  
  // ==================== 스플래시 화면 설정 ====================
  /// 기본 스플래시 딜레이 시간 (밀리초) - Android/iOS에 자동 동기화됨
  static const int defaultSplashDelayMs = 3000;
  
  /// 푸시 알림이 있을 때 스플래시 딜레이 (밀리초) - Android/iOS에 자동 동기화됨
  static const int pushNotificationSplashDelayMs = 500;
  
  // ==================== 네트워크 설정 ====================
  /// HTTP 연결 타임아웃 (밀리초) - Android/iOS에 자동 동기화됨
  static const int httpConnectTimeoutMs = 10000;
  
  /// HTTP 읽기 타임아웃 (밀리초) - Android/iOS에 자동 동기화됨
  static const int httpReadTimeoutMs = 10000;
  
  // ==================== Method Channel 설정 ====================
  /// MethodChannel 이름들 - Android/iOS에 자동 동기화됨
  static const String methodChannelGeolocation = 'hello.mobile/geolocation';
  static const String methodChannelWebview = 'hello.mobile/webview';
  static const String methodChannelImage = 'hello.mobile/image';
  
  // ==================== JavaScript 채널 설정 ====================
  /// JavaScript 채널 이름
  static const String jsChannelName = 'FlutterChannel';
  
  // ==================== WebView 타임아웃 설정 ====================
  /// JavaScript confirm/alert 타임아웃 (밀리초)
  static const int jsConfirmTimeoutMs = 3000;
  
  /// JavaScript 위치 요청 타임아웃 (밀리초)
  static const int jsLocationTimeoutMs = 30000;
  
  /// 위치 업데이트 기본 간격 (밀리초)
  static const int locationUpdateIntervalMs = 10000;
  
  // ==================== Pull to Refresh 설정 ====================
  /// Pull to Refresh 거리 임계값 (픽셀)
  static const int pullToRefreshDistanceThreshold = 300;
  
  /// Pull to Refresh 시간 임계값 (밀리초)
  static const int pullToRefreshTimeThreshold = 3000;
  
  // ==================== Firebase 설정 ====================
  /// Firebase 프로젝트 설정 - Android/iOS에 자동 동기화됨
  /// Firebase Console에서 프로젝트를 생성한 후 google-services.json과 GoogleService-Info.plist를 추가하세요
  /// Firebase 설정 파일이 없으면 false로 설정하세요
  static const bool useFirebase = true;
  
  // ==================== 소셜 로그인 설정 ====================
  /// 소셜 로그인은 웹에서 처리됩니다.
  /// 네이티브 SDK는 사용하지 않습니다.
  static const bool enableGoogleLogin = false;
  static const bool enableKakaoLogin = false;
  
  /// 카카오 네이티브 앱 키 - 웹에서 소셜 로그인 처리하므로 사용하지 않음
  static const String kakaoNativeAppKey = '';
  
  // ==================== 소셜 로그인 허용 도메인 ====================
  /// 소셜 로그인을 허용할 도메인 목록 (웹뷰 내에서 처리)
  /// 웹에서 소셜 로그인을 처리하므로 이 도메인들은 웹뷰 내에서 열립니다
  static const List<String> allowedSocialLoginDomains = [
    'logins.daum.net', // 카카오 SSO 토큰 로그인
    'kauth.kakao.com', // 카카오 OAuth 인증
    'kapi.kakao.com', // 카카오 API
    'accounts.kakao.com', // 카카오 계정
    'accounts.google.com', // 구글 계정
    'oauth2.googleapis.com', // 구글 OAuth2
    'www.googleapis.com', // 구글 API
    'appleid.apple.com', // 애플 ID
    'idmsa.apple.com', // 애플 ID 관리
    'nid.naver.com', // 네이버 로그인
    'openapi.naver.com', // 네이버 API
  ];
}

