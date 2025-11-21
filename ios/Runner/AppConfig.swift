/// iOS 네이티브 앱 설정 관리 구조체
/// 이 파일은 자동 생성됩니다. 수동으로 수정하지 마세요.
/// 
/// 설정을 변경하려면 lib/config/app_config.dart를 수정한 후
/// 다음 명령을 실행하세요:
///   dart scripts/generate_native_config.dart
/// 
/// 또는 Flutter 빌드 시 자동으로 생성됩니다.
import Foundation

struct AppConfig {
    // ==================== 웹사이트 및 서버 설정 ====================
    /// 웹사이트 URL - Flutter AppConfig.websiteUrl에서 자동 생성
    static let websiteUrl = "https://howtattoo.co.kr/"
    
    static let serverApiPathAppInfo = "modules/appmgmt/libs/appInfo.php"
    static let serverApiPathAppInfoIOS = "modules/appmgmt/libs/appInfo_ios.php"
    static let serverApiPathDeviceToken = "modules/appmgmt/libs/deviceToken.php"
    
    // ==================== 스플래시 화면 설정 ====================
    static let defaultSplashDelayMs: TimeInterval = 3000 / 1000.0
    static let pushNotificationSplashDelayMs: TimeInterval = 500 / 1000.0
    static let splashBgImageName = "splash_bg.jpg"
    static let assetsLoadingImageName = "loading_image.jpg"
    
    // ==================== 앱 버전 설정 ====================
    static let appVersion = "1.4.1"
    static let iosBundleId = "com.example.flutterWebviewApp"
    
    // ==================== 네트워크 설정 ====================
    static let httpConnectTimeoutMs: TimeInterval = 10000 / 1000.0
    static let httpReadTimeoutMs: TimeInterval = 10000 / 1000.0
    static let httpUserAgent = "iOS-App"
    
    // ==================== Method Channel 설정 ====================
    static let methodChannelGeolocation = "com.example.flutter_webview_app/geolocation"
    static let methodChannelWebview = "com.example.flutter_webview_app/webview"
    static let methodChannelImage = "com.example.flutter_webview_app/image"
    
    // ==================== WebView 타임아웃 설정 ====================
    static let jsConfirmTimeoutMs: TimeInterval = 3000 / 1000.0
    static let jsLocationTimeoutMs: TimeInterval = 30000 / 1000.0
    static let locationUpdateIntervalMs: TimeInterval = 10000 / 1000.0
    
    // ==================== Pull to Refresh 설정 ====================
    static let pullToRefreshDistanceThreshold = 300
    static let pullToRefreshTimeThreshold: TimeInterval = 3000 / 1000.0
    
    // ==================== Firebase 설정 ====================
    static let useFirebase = false
    
    // ==================== 유틸리티 메서드 ====================
    static func getWebsiteDomain() -> String {
        guard let url = URL(string: websiteUrl),
              let host = url.host else {
            return ""
        }
        return host
    }
    
    static func getAppInfoUrl() -> String {
        let domain = getWebsiteDomain()
        guard !domain.isEmpty else { return "" }
        return "https://\(domain)/\(serverApiPathAppInfo)"
    }
    
    static func getAppInfoIOSUrl() -> String {
        let domain = getWebsiteDomain()
        guard !domain.isEmpty else { return "" }
        return "https://\(domain)/\(serverApiPathAppInfoIOS)"
    }
    
    static func getDeviceTokenUrl() -> String {
        let domain = getWebsiteDomain()
        guard !domain.isEmpty else { return "" }
        return "https://\(domain)/\(serverApiPathDeviceToken)"
    }
    
    static func getBackgroundImageUrl(imagePath: String) -> String {
        let domain = getWebsiteDomain()
        guard !domain.isEmpty,
              !imagePath.isEmpty,
              imagePath != "-99" else {
            return ""
        }
        return "https://\(domain)/\(imagePath)"
    }
}
