package com.example.flutter_webview_app

/**
 * Android 네이티브 앱 설정 관리 클래스
 * 이 파일은 자동 생성됩니다. 수동으로 수정하지 마세요.
 * 
 * 설정을 변경하려면 lib/config/app_config.dart를 수정한 후
 * 다음 명령을 실행하세요:
 *   dart scripts/generate_native_config.dart
 * 
 * 또는 Flutter 빌드 시 자동으로 생성됩니다.
 */
object AppConfig {
    // ==================== 웹사이트 및 서버 설정 ====================
    /**
     * 웹사이트 URL - Flutter AppConfig.websiteUrl에서 자동 생성
     */
    const val WEBSITE_URL = "https://codejaka01.cafe24.com/mb_test/"
    
    const val SERVER_API_PATH_APP_INFO = "modules/appmgmt/libs/appInfo.php"
    const val SERVER_API_PATH_DEVICE_TOKEN = "modules/appmgmt/libs/deviceToken.php"
    
    // ==================== 스플래시 화면 설정 ====================
    const val DEFAULT_SPLASH_DELAY_MS: Long = 3000L
    const val PUSH_NOTIFICATION_SPLASH_DELAY_MS: Long = 500L
    const val SPLASH_BG_IMAGE_NAME = "splash_bg.jpg"
    const val ASSETS_LOADING_IMAGE_NAME = "loading_image.jpg"
    
    // ==================== 앱 버전 설정 ====================
    const val APP_VERSION = "1.4.1"
    const val APP_PACKAGE_NAME = "hello.mobile"
    
    // ==================== 네트워크 설정 ====================
    const val HTTP_CONNECT_TIMEOUT_MS = 10000
    const val HTTP_READ_TIMEOUT_MS = 10000
    const val HTTP_USER_AGENT = "Android-App"
    
    // ==================== Method Channel 설정 ====================
    const val METHOD_CHANNEL_GEOLOCATION = "hello.mobile/geolocation"
    const val METHOD_CHANNEL_WEBVIEW = "hello.mobile/webview"
    const val METHOD_CHANNEL_IMAGE = "hello.mobile/image"
    
    // ==================== WebView 타임아웃 설정 ====================
    const val JS_CONFIRM_TIMEOUT_MS = 3000
    const val JS_LOCATION_TIMEOUT_MS = 30000
    const val LOCATION_UPDATE_INTERVAL_MS = 10000
    
    // ==================== Pull to Refresh 설정 ====================
    const val PULL_TO_REFRESH_DISTANCE_THRESHOLD = 300
    const val PULL_TO_REFRESH_TIME_THRESHOLD = 3000
    
    // ==================== Firebase 설정 ====================
    const val USE_FIREBASE = true
    
    // ==================== 유틸리티 메서드 ====================
    fun getWebsiteDomain(): String {
        return try {
            val uri = android.net.Uri.parse(WEBSITE_URL)
            uri.host ?: ""
        } catch (e: Exception) {
            ""
        }
    }
    
    fun getAppInfoUrl(): String {
        val domain = getWebsiteDomain()
        return if (domain.isNotEmpty()) {
            "https://$domain/$SERVER_API_PATH_APP_INFO"
        } else {
            ""
        }
    }
    
    fun getDeviceTokenUrl(): String {
        val domain = getWebsiteDomain()
        return if (domain.isNotEmpty()) {
            "https://$domain/$SERVER_API_PATH_DEVICE_TOKEN"
        } else {
            ""
        }
    }
    
    fun getBackgroundImageUrl(imagePath: String): String {
        val domain = getWebsiteDomain()
        return if (domain.isNotEmpty() && imagePath.isNotEmpty() && imagePath != "-99") {
            "https://$domain/$imagePath"
        } else {
            ""
        }
    }
}
