/// Flutter AppConfig를 파싱하여 네이티브 플랫폼용 설정 파일을 생성하는 스크립트
/// 
/// 사용법: dart scripts/generate_native_config.dart
/// 
/// 이 스크립트는 lib/config/app_config.dart를 읽어서
/// Android와 iOS에서 사용할 수 있는 설정 파일을 생성합니다.

import 'dart:io';

void main() async {
  print('Flutter AppConfig에서 네이티브 설정 파일 생성 중...');
  
  // lib/config/app_config.dart 파일 읽기
  final configFile = File('lib/config/app_config.dart');
  if (!await configFile.exists()) {
    print('ERROR: lib/config/app_config.dart 파일을 찾을 수 없습니다.');
    exit(1);
  }
  
  final content = await configFile.readAsString();
  
  // 설정값 추출
  final config = <String, dynamic>{};
  
  // websiteUrl
  final websiteUrlMatch = RegExp(r"static const String websiteUrl = '([^']+)';").firstMatch(content);
  if (websiteUrlMatch != null) {
    config['websiteUrl'] = websiteUrlMatch.group(1);
  }
  
  // serverApiPathAppInfo
  final appInfoMatch = RegExp(r"static const String serverApiPathAppInfo = '([^']+)';").firstMatch(content);
  if (appInfoMatch != null) {
    config['serverApiPathAppInfo'] = appInfoMatch.group(1);
  }
  
  // serverApiPathAppInfoIOS
  final appInfoIOSMatch = RegExp(r"static const String serverApiPathAppInfoIOS = '([^']+)';").firstMatch(content);
  if (appInfoIOSMatch != null) {
    config['serverApiPathAppInfoIOS'] = appInfoIOSMatch.group(1);
  }
  
  // serverApiPathDeviceToken
  final deviceTokenMatch = RegExp(r"static const String serverApiPathDeviceToken = '([^']+)';").firstMatch(content);
  if (deviceTokenMatch != null) {
    config['serverApiPathDeviceToken'] = deviceTokenMatch.group(1);
  }
  
  // androidPackageName
  final androidPackageMatch = RegExp(r"static const String androidPackageName = '([^']+)';").firstMatch(content);
  if (androidPackageMatch != null) {
    config['androidPackageName'] = androidPackageMatch.group(1);
  }
  
  // iosBundleId
  final iosBundleMatch = RegExp(r"static const String iosBundleId = '([^']+)';").firstMatch(content);
  if (iosBundleMatch != null) {
    config['iosBundleId'] = iosBundleMatch.group(1);
  }
  
  // appVersion
  final appVersionMatch = RegExp(r"static const String appVersion = '([^']+)';").firstMatch(content);
  if (appVersionMatch != null) {
    config['appVersion'] = appVersionMatch.group(1);
  }
  
  // defaultSplashDelayMs
  final splashDelayMatch = RegExp(r"static const int defaultSplashDelayMs = (\d+);").firstMatch(content);
  if (splashDelayMatch != null) {
    config['defaultSplashDelayMs'] = int.parse(splashDelayMatch.group(1)!);
  }
  
  // pushNotificationSplashDelayMs
  final pushDelayMatch = RegExp(r"static const int pushNotificationSplashDelayMs = (\d+);").firstMatch(content);
  if (pushDelayMatch != null) {
    config['pushNotificationSplashDelayMs'] = int.parse(pushDelayMatch.group(1)!);
  }
  
  // httpConnectTimeoutMs
  final connectTimeoutMatch = RegExp(r"static const int httpConnectTimeoutMs = (\d+);").firstMatch(content);
  if (connectTimeoutMatch != null) {
    config['httpConnectTimeoutMs'] = int.parse(connectTimeoutMatch.group(1)!);
  }
  
  // httpReadTimeoutMs
  final readTimeoutMatch = RegExp(r"static const int httpReadTimeoutMs = (\d+);").firstMatch(content);
  if (readTimeoutMatch != null) {
    config['httpReadTimeoutMs'] = int.parse(readTimeoutMatch.group(1)!);
  }
  
  // methodChannelGeolocation
  final geolocationMatch = RegExp(r"static const String methodChannelGeolocation = '([^']+)';").firstMatch(content);
  if (geolocationMatch != null) {
    config['methodChannelGeolocation'] = geolocationMatch.group(1);
  }
  
  // methodChannelWebview
  final webviewMatch = RegExp(r"static const String methodChannelWebview = '([^']+)';").firstMatch(content);
  if (webviewMatch != null) {
    config['methodChannelWebview'] = webviewMatch.group(1);
  }
  
  // methodChannelImage
  final imageMatch = RegExp(r"static const String methodChannelImage = '([^']+)';").firstMatch(content);
  if (imageMatch != null) {
    config['methodChannelImage'] = imageMatch.group(1);
  }
  
  // jsChannelName
  final jsChannelMatch = RegExp(r"static const String jsChannelName = '([^']+)';").firstMatch(content);
  if (jsChannelMatch != null) {
    config['jsChannelName'] = jsChannelMatch.group(1);
  }
  
  // jsConfirmTimeoutMs
  final jsConfirmTimeoutMatch = RegExp(r"static const int jsConfirmTimeoutMs = (\d+);").firstMatch(content);
  if (jsConfirmTimeoutMatch != null) {
    config['jsConfirmTimeoutMs'] = int.parse(jsConfirmTimeoutMatch.group(1)!);
  }
  
  // jsLocationTimeoutMs
  final jsLocationTimeoutMatch = RegExp(r"static const int jsLocationTimeoutMs = (\d+);").firstMatch(content);
  if (jsLocationTimeoutMatch != null) {
    config['jsLocationTimeoutMs'] = int.parse(jsLocationTimeoutMatch.group(1)!);
  }
  
  // locationUpdateIntervalMs
  final locationIntervalMatch = RegExp(r"static const int locationUpdateIntervalMs = (\d+);").firstMatch(content);
  if (locationIntervalMatch != null) {
    config['locationUpdateIntervalMs'] = int.parse(locationIntervalMatch.group(1)!);
  }
  
  // pullToRefreshDistanceThreshold
  final pullDistanceMatch = RegExp(r"static const int pullToRefreshDistanceThreshold = (\d+);").firstMatch(content);
  if (pullDistanceMatch != null) {
    config['pullToRefreshDistanceThreshold'] = int.parse(pullDistanceMatch.group(1)!);
  }
  
  // pullToRefreshTimeThreshold
  final pullTimeMatch = RegExp(r"static const int pullToRefreshTimeThreshold = (\d+);").firstMatch(content);
  if (pullTimeMatch != null) {
    config['pullToRefreshTimeThreshold'] = int.parse(pullTimeMatch.group(1)!);
  }
  
  // useFirebase
  final useFirebaseMatch = RegExp(r"static const bool useFirebase = (true|false);").firstMatch(content);
  if (useFirebaseMatch != null) {
    config['useFirebase'] = useFirebaseMatch.group(1) == 'true';
  }
  
  // allowedSocialLoginDomains
  final domainsMatch = RegExp(r"static const List<String> allowedSocialLoginDomains = \[([^\]]+)\];", multiLine: true).firstMatch(content);
  if (domainsMatch != null) {
    final domainsStr = domainsMatch.group(1)!;
    final domains = domainsStr
        .split(',')
        .map((d) => d.trim().replaceAll("'", '').replaceAll('"', ''))
        .where((d) => d.isNotEmpty)
        .toList();
    config['allowedSocialLoginDomains'] = domains;
  }
  
  // Android AppConfig.kt 생성
  await _generateAndroidConfig(config);
  
  // iOS AppConfig.swift 생성
  await _generateIOSConfig(config);
  
  // JSON 설정 파일 생성 (선택적)
  await _generateJsonConfig(config);
  
  print('✅ 네이티브 설정 파일 생성 완료!');
  print('   - android/app/src/main/kotlin/com/example/flutter_webview_app/AppConfig.kt');
  print('   - ios/Runner/AppConfig.swift');
  print('   - android/app/src/main/assets/app_config.json');
}

Future<void> _generateAndroidConfig(Map<String, dynamic> config) async {
  final androidConfigPath = 'android/app/src/main/kotlin/com/example/flutter_webview_app/AppConfig.kt';
  final androidConfigFile = File(androidConfigPath);
  
  // 디렉토리 생성
  await androidConfigFile.parent.create(recursive: true);
  
  final buffer = StringBuffer();
  buffer.writeln('package com.example.flutter_webview_app');
  buffer.writeln();
  buffer.writeln('/**');
  buffer.writeln(' * Android 네이티브 앱 설정 관리 클래스');
  buffer.writeln(' * 이 파일은 자동 생성됩니다. 수동으로 수정하지 마세요.');
  buffer.writeln(' * ');
  buffer.writeln(' * 설정을 변경하려면 lib/config/app_config.dart를 수정한 후');
  buffer.writeln(' * 다음 명령을 실행하세요:');
  buffer.writeln(' *   dart scripts/generate_native_config.dart');
  buffer.writeln(' * ');
  buffer.writeln(' * 또는 Flutter 빌드 시 자동으로 생성됩니다.');
  buffer.writeln(' */');
  buffer.writeln('object AppConfig {');
  buffer.writeln('    // ==================== 웹사이트 및 서버 설정 ====================');
  buffer.writeln('    /**');
  buffer.writeln('     * 웹사이트 URL - Flutter AppConfig.websiteUrl에서 자동 생성');
  buffer.writeln('     */');
  buffer.writeln('    const val WEBSITE_URL = "${config['websiteUrl']}"');
  buffer.writeln('    ');
  buffer.writeln('    const val SERVER_API_PATH_APP_INFO = "${config['serverApiPathAppInfo']}"');
  buffer.writeln('    const val SERVER_API_PATH_DEVICE_TOKEN = "${config['serverApiPathDeviceToken']}"');
  buffer.writeln('    ');
  buffer.writeln('    // ==================== 스플래시 화면 설정 ====================');
  buffer.writeln('    const val DEFAULT_SPLASH_DELAY_MS: Long = ${config['defaultSplashDelayMs']}L');
  buffer.writeln('    const val PUSH_NOTIFICATION_SPLASH_DELAY_MS: Long = ${config['pushNotificationSplashDelayMs']}L');
  buffer.writeln('    const val SPLASH_BG_IMAGE_NAME = "splash_bg.jpg"');
  buffer.writeln('    const val ASSETS_LOADING_IMAGE_NAME = "loading_image.jpg"');
  buffer.writeln('    ');
  buffer.writeln('    // ==================== 앱 버전 설정 ====================');
  buffer.writeln('    const val APP_VERSION = "${config['appVersion']}"');
  buffer.writeln('    const val APP_PACKAGE_NAME = "${config['androidPackageName']}"');
  buffer.writeln('    ');
  buffer.writeln('    // ==================== 네트워크 설정 ====================');
  buffer.writeln('    const val HTTP_CONNECT_TIMEOUT_MS = ${config['httpConnectTimeoutMs']}');
  buffer.writeln('    const val HTTP_READ_TIMEOUT_MS = ${config['httpReadTimeoutMs']}');
  buffer.writeln('    const val HTTP_USER_AGENT = "Android-App"');
  buffer.writeln('    ');
  buffer.writeln('    // ==================== Method Channel 설정 ====================');
  buffer.writeln('    const val METHOD_CHANNEL_GEOLOCATION = "${config['methodChannelGeolocation']}"');
  buffer.writeln('    const val METHOD_CHANNEL_WEBVIEW = "${config['methodChannelWebview']}"');
  buffer.writeln('    const val METHOD_CHANNEL_IMAGE = "${config['methodChannelImage']}"');
  buffer.writeln('    ');
  buffer.writeln('    // ==================== WebView 타임아웃 설정 ====================');
  buffer.writeln('    const val JS_CONFIRM_TIMEOUT_MS = ${config['jsConfirmTimeoutMs']}');
  buffer.writeln('    const val JS_LOCATION_TIMEOUT_MS = ${config['jsLocationTimeoutMs']}');
  buffer.writeln('    const val LOCATION_UPDATE_INTERVAL_MS = ${config['locationUpdateIntervalMs']}');
  buffer.writeln('    ');
  buffer.writeln('    // ==================== Pull to Refresh 설정 ====================');
  buffer.writeln('    const val PULL_TO_REFRESH_DISTANCE_THRESHOLD = ${config['pullToRefreshDistanceThreshold']}');
  buffer.writeln('    const val PULL_TO_REFRESH_TIME_THRESHOLD = ${config['pullToRefreshTimeThreshold']}');
  buffer.writeln('    ');
  buffer.writeln('    // ==================== Firebase 설정 ====================');
  buffer.writeln('    const val USE_FIREBASE = ${config['useFirebase']}');
  buffer.writeln('    ');
  buffer.writeln('    // ==================== 유틸리티 메서드 ====================');
  buffer.writeln('    fun getWebsiteDomain(): String {');
  buffer.writeln('        return try {');
  buffer.writeln('            val uri = android.net.Uri.parse(WEBSITE_URL)');
  buffer.writeln('            uri.host ?: ""');
  buffer.writeln('        } catch (e: Exception) {');
  buffer.writeln('            ""');
  buffer.writeln('        }');
  buffer.writeln('    }');
  buffer.writeln('    ');
  buffer.writeln('    fun getAppInfoUrl(): String {');
  buffer.writeln('        val domain = getWebsiteDomain()');
  buffer.writeln('        return if (domain.isNotEmpty()) {');
  buffer.writeln('            "https://\$domain/\$SERVER_API_PATH_APP_INFO"');
  buffer.writeln('        } else {');
  buffer.writeln('            ""');
  buffer.writeln('        }');
  buffer.writeln('    }');
  buffer.writeln('    ');
  buffer.writeln('    fun getDeviceTokenUrl(): String {');
  buffer.writeln('        val domain = getWebsiteDomain()');
  buffer.writeln('        return if (domain.isNotEmpty()) {');
  buffer.writeln('            "https://\$domain/\$SERVER_API_PATH_DEVICE_TOKEN"');
  buffer.writeln('        } else {');
  buffer.writeln('            ""');
  buffer.writeln('        }');
  buffer.writeln('    }');
  buffer.writeln('    ');
  buffer.writeln('    fun getBackgroundImageUrl(imagePath: String): String {');
  buffer.writeln('        val domain = getWebsiteDomain()');
  buffer.writeln('        return if (domain.isNotEmpty() && imagePath.isNotEmpty() && imagePath != "-99") {');
  buffer.writeln('            "https://\$domain/\$imagePath"');
  buffer.writeln('        } else {');
  buffer.writeln('            ""');
  buffer.writeln('        }');
  buffer.writeln('    }');
  buffer.writeln('}');
  
  await androidConfigFile.writeAsString(buffer.toString());
  print('✅ Android AppConfig.kt 생성 완료');
}

Future<void> _generateJsonConfig(Map<String, dynamic> config) async {
  final jsonConfigPath = 'android/app/src/main/assets/app_config.json';
  final jsonConfigFile = File(jsonConfigPath);
  
  // 디렉토리 생성
  await jsonConfigFile.parent.create(recursive: true);
  
  // JSON 생성 (간단한 형태)
  final json = StringBuffer();
  json.writeln('{');
  final entries = config.entries.toList();
  for (int i = 0; i < entries.length; i++) {
    final entry = entries[i];
    final isLast = i == entries.length - 1;
    final comma = isLast ? '' : ',';
    
    if (entry.value is List) {
      json.writeln('  "${entry.key}": [${(entry.value as List).map((v) => '"$v"').join(', ')}]$comma');
    } else if (entry.value is String) {
      json.writeln('  "${entry.key}": "${entry.value}"$comma');
    } else if (entry.value is bool) {
      json.writeln('  "${entry.key}": ${entry.value}$comma');
    } else {
      json.writeln('  "${entry.key}": ${entry.value}$comma');
    }
  }
  json.writeln('}');
  
  await jsonConfigFile.writeAsString(json.toString());
  print('✅ app_config.json 생성 완료');
}

Future<void> _generateIOSConfig(Map<String, dynamic> config) async {
  final iosConfigPath = 'ios/Runner/AppConfig.swift';
  final iosConfigFile = File(iosConfigPath);
  
  // 디렉토리 생성
  await iosConfigFile.parent.create(recursive: true);
  
  final buffer = StringBuffer();
  buffer.writeln('/// iOS 네이티브 앱 설정 관리 구조체');
  buffer.writeln('/// 이 파일은 자동 생성됩니다. 수동으로 수정하지 마세요.');
  buffer.writeln('/// ');
  buffer.writeln('/// 설정을 변경하려면 lib/config/app_config.dart를 수정한 후');
  buffer.writeln('/// 다음 명령을 실행하세요:');
  buffer.writeln('///   dart scripts/generate_native_config.dart');
  buffer.writeln('/// ');
  buffer.writeln('/// 또는 Flutter 빌드 시 자동으로 생성됩니다.');
  buffer.writeln('import Foundation');
  buffer.writeln();
  buffer.writeln('struct AppConfig {');
  buffer.writeln('    // ==================== 웹사이트 및 서버 설정 ====================');
  buffer.writeln('    /// 웹사이트 URL - Flutter AppConfig.websiteUrl에서 자동 생성');
  buffer.writeln('    static let websiteUrl = "${config['websiteUrl']}"');
  buffer.writeln('    ');
  buffer.writeln('    static let serverApiPathAppInfo = "${config['serverApiPathAppInfo']}"');
  buffer.writeln('    static let serverApiPathAppInfoIOS = "${config['serverApiPathAppInfoIOS'] ?? 'modules/appmgmt/libs/appInfo_ios.php'}"');
  buffer.writeln('    static let serverApiPathDeviceToken = "${config['serverApiPathDeviceToken']}"');
  buffer.writeln('    ');
  buffer.writeln('    // ==================== 스플래시 화면 설정 ====================');
  buffer.writeln('    static let defaultSplashDelayMs: TimeInterval = ${config['defaultSplashDelayMs']} / 1000.0');
  buffer.writeln('    static let pushNotificationSplashDelayMs: TimeInterval = ${config['pushNotificationSplashDelayMs']} / 1000.0');
  buffer.writeln('    static let splashBgImageName = "splash_bg.jpg"');
  buffer.writeln('    static let assetsLoadingImageName = "loading_image.jpg"');
  buffer.writeln('    ');
  buffer.writeln('    // ==================== 앱 버전 설정 ====================');
  buffer.writeln('    static let appVersion = "${config['appVersion']}"');
  buffer.writeln('    static let iosBundleId = "${config['iosBundleId']}"');
  buffer.writeln('    ');
  buffer.writeln('    // ==================== 네트워크 설정 ====================');
  buffer.writeln('    static let httpConnectTimeoutMs: TimeInterval = ${config['httpConnectTimeoutMs']} / 1000.0');
  buffer.writeln('    static let httpReadTimeoutMs: TimeInterval = ${config['httpReadTimeoutMs']} / 1000.0');
  buffer.writeln('    static let httpUserAgent = "iOS-App"');
  buffer.writeln('    ');
  buffer.writeln('    // ==================== Method Channel 설정 ====================');
  buffer.writeln('    static let methodChannelGeolocation = "${config['methodChannelGeolocation']}"');
  buffer.writeln('    static let methodChannelWebview = "${config['methodChannelWebview']}"');
  buffer.writeln('    static let methodChannelImage = "${config['methodChannelImage']}"');
  buffer.writeln('    ');
  buffer.writeln('    // ==================== WebView 타임아웃 설정 ====================');
  buffer.writeln('    static let jsConfirmTimeoutMs: TimeInterval = ${config['jsConfirmTimeoutMs']} / 1000.0');
  buffer.writeln('    static let jsLocationTimeoutMs: TimeInterval = ${config['jsLocationTimeoutMs']} / 1000.0');
  buffer.writeln('    static let locationUpdateIntervalMs: TimeInterval = ${config['locationUpdateIntervalMs']} / 1000.0');
  buffer.writeln('    ');
  buffer.writeln('    // ==================== Pull to Refresh 설정 ====================');
  buffer.writeln('    static let pullToRefreshDistanceThreshold = ${config['pullToRefreshDistanceThreshold']}');
  buffer.writeln('    static let pullToRefreshTimeThreshold: TimeInterval = ${config['pullToRefreshTimeThreshold']} / 1000.0');
  buffer.writeln('    ');
  buffer.writeln('    // ==================== Firebase 설정 ====================');
  buffer.writeln('    static let useFirebase = ${config['useFirebase']}');
  buffer.writeln('    ');
  buffer.writeln('    // ==================== 유틸리티 메서드 ====================');
  buffer.writeln('    static func getWebsiteDomain() -> String {');
  buffer.writeln('        guard let url = URL(string: websiteUrl),');
  buffer.writeln('              let host = url.host else {');
  buffer.writeln('            return ""');
  buffer.writeln('        }');
  buffer.writeln('        return host');
  buffer.writeln('    }');
  buffer.writeln('    ');
  buffer.writeln('    static func getAppInfoUrl() -> String {');
  buffer.writeln('        let domain = getWebsiteDomain()');
  buffer.writeln('        guard !domain.isEmpty else { return "" }');
  buffer.writeln('        return "https://\\(domain)/\\(serverApiPathAppInfo)"');
  buffer.writeln('    }');
  buffer.writeln('    ');
  buffer.writeln('    static func getAppInfoIOSUrl() -> String {');
  buffer.writeln('        let domain = getWebsiteDomain()');
  buffer.writeln('        guard !domain.isEmpty else { return "" }');
  buffer.writeln('        return "https://\\(domain)/\\(serverApiPathAppInfoIOS)"');
  buffer.writeln('    }');
  buffer.writeln('    ');
  buffer.writeln('    static func getDeviceTokenUrl() -> String {');
  buffer.writeln('        let domain = getWebsiteDomain()');
  buffer.writeln('        guard !domain.isEmpty else { return "" }');
  buffer.writeln('        return "https://\\(domain)/\\(serverApiPathDeviceToken)"');
  buffer.writeln('    }');
  buffer.writeln('    ');
  buffer.writeln('    static func getBackgroundImageUrl(imagePath: String) -> String {');
  buffer.writeln('        let domain = getWebsiteDomain()');
  buffer.writeln('        guard !domain.isEmpty,');
  buffer.writeln('              !imagePath.isEmpty,');
  buffer.writeln('              imagePath != "-99" else {');
  buffer.writeln('            return ""');
  buffer.writeln('        }');
  buffer.writeln('        return "https://\\(domain)/\\(imagePath)"');
  buffer.writeln('    }');
  buffer.writeln('}');
  
  await iosConfigFile.writeAsString(buffer.toString());
  print('✅ iOS AppConfig.swift 생성 완료');
}

