/// 앱 설정 관리 클래스
/// 이 파일에서 웹사이트 URL과 앱 설정을 변경할 수 있습니다.
class AppConfig {
  // 웹사이트 URL - 여기서 변경하면 다른 웹사이트용 앱으로 변환 가능
  static const String websiteUrl = 'https://howtattoo.co.kr/';
  
  // 앱 이름
  static const String appName = 'Flutter WebView App';
  
  // Android 패키지명 (필요시 변경)
  static const String androidPackageName = 'com.example.flutter_webview_app';
  
  // iOS 번들 ID (필요시 변경)
  static const String iosBundleId = 'com.example.flutterWebviewApp';
  
  // Firebase 프로젝트 설정
  // Firebase Console에서 프로젝트를 생성한 후 google-services.json과 GoogleService-Info.plist를 추가하세요
  // Firebase 설정 파일이 없으면 false로 설정하세요
  static const bool useFirebase = false;
  
  // 소셜 로그인 설정
  // Google Sign-In: Android의 경우 google-services.json에 설정이 포함됩니다
  // iOS의 경우 Info.plist에 REVERSED_CLIENT_ID를 추가해야 합니다
  static const bool enableGoogleLogin = true;
  static const bool enableKakaoLogin = true;
  
  // 카카오 네이티브 앱 키 (카카오 개발자 콘솔에서 발급)
  // 실제 사용 시 이 값을 변경하세요
  static const String kakaoNativeAppKey = 'YOUR_KAKAO_NATIVE_APP_KEY';
  
  // JavaScript 채널 이름
  static const String jsChannelName = 'FlutterChannel';
  
  // 앱 버전 (User-Agent에 사용)
  // package_info_plus로 가져올 수도 있지만, 여기서 설정 가능
  static const String appVersion = '1.0.0';
}

