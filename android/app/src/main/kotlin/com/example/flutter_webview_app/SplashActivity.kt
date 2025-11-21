package com.example.flutter_webview_app

import android.app.Activity
import android.app.AlertDialog
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.content.res.AssetManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.Gravity
import android.view.KeyEvent
import android.view.View
import android.view.ViewGroup
import android.view.Window
import android.view.WindowManager
import android.widget.ImageView
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.core.app.ActivityCompat
// Firebase는 선택적 의존성 - 런타임에 확인
import java.io.*
import java.net.URL
import java.util.concurrent.Executors

class SplashActivity : AppCompatActivity() {

    private val TAG = SplashActivity::class.java.simpleName
    
    private var imageView: ImageView? = null
    private var pushUrl: String? = null
    private var fcmToken: String? = null
    private var appConfig: AppConfigData? = null
    private var backBtnTime: Long = 0
    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_splash)

        // 전체 화면 설정 (상태바 오버레이)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
            val window: Window = window
            window.setFlags(
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS
            )
        }

        imageView = findViewById(R.id.splashImageView)

        // Intent에서 푸시 URL 등 전달받은 데이터 확인
        val intent = this.intent
        val bundle = intent.extras
        if (bundle != null && bundle.getString("url") != null && !bundle.getString("url").isNullOrEmpty()) {
            pushUrl = bundle.getString("url")
            Log.d(TAG, "푸시 URL 수신: $pushUrl")
        }

        // 첫 실행 시 기본 이미지 복사
        val pref: SharedPreferences = getSharedPreferences("isFirst", Activity.MODE_PRIVATE)
        val isFirst = pref.getBoolean("isFirst", false)
        
        if (!isFirst) {
            val editor = pref.edit()
            editor.putBoolean("isFirst", true)
            editor.apply()
            firstSetLoadingImage()
        }

        // 이미지 표시
        loadSplashImage()

        // 네트워크 연결 확인 및 서버 설정 동기화
        if (isNetworkAvailable()) {
            // FCM 토큰 가져오기 및 서버 설정 동기화
            fetchFCMTokenAndSyncConfig()
        } else {
            // 네트워크 없음 - 종료 다이얼로그 표시
            Log.w(TAG, "네트워크 연결 없음")
            showNoConnectionDialog()
        }
    }

    /**
     * FCM 토큰 가져오기 (Firebase가 있는 경우)
     */
    private fun fetchFCMTokenIfAvailable(targetUrl: String) {
        try {
            // 리플렉션을 사용하여 FirebaseMessaging 클래스 확인
            val firebaseMessagingClass = Class.forName("com.google.firebase.messaging.FirebaseMessaging")
            val getInstanceMethod = firebaseMessagingClass.getMethod("getInstance")
            val firebaseMessaging = getInstanceMethod.invoke(null)
            
            // getToken() 메서드 호출
            val getTokenMethod = firebaseMessagingClass.getMethod("getToken")
            val task = getTokenMethod.invoke(firebaseMessaging)
            
            // Task와 OnCompleteListener 클래스
            val taskClass = Class.forName("com.google.android.gms.tasks.Task")
            val onCompleteListenerClass = Class.forName("com.google.android.gms.tasks.OnCompleteListener")
            val addOnCompleteListenerMethod = taskClass.getMethod("addOnCompleteListener", onCompleteListenerClass)
            
            // OnCompleteListener 구현
            val listener = java.lang.reflect.Proxy.newProxyInstance(
                classLoader,
                arrayOf(onCompleteListenerClass)
            ) { _, method, args ->
                if (method.name == "onComplete" && args != null && args.isNotEmpty()) {
                    try {
                        val taskParam = args[0]
                        val isSuccessfulMethod = taskParam.javaClass.getMethod("isSuccessful")
                        val isSuccessful = isSuccessfulMethod.invoke(taskParam) as? Boolean ?: false
                        
                        if (!isSuccessful) {
                            val exceptionMethod = taskParam.javaClass.getMethod("getException")
                            val exception = exceptionMethod.invoke(taskParam) as? Exception
                            Log.w(TAG, "FCM 토큰 가져오기 실패", exception)
                            // 토큰 실패해도 서버 설정은 가져오기
                            syncServerConfig(targetUrl, null)
                        } else {
                            val resultMethod = taskParam.javaClass.getMethod("getResult")
                            fcmToken = resultMethod.invoke(taskParam) as? String
                            Log.d(TAG, "FCM 토큰: ${fcmToken?.take(20)}...")
                            // 서버 설정 동기화
                            syncServerConfig(targetUrl, fcmToken)
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "FCM 토큰 처리 오류", e)
                        syncServerConfig(targetUrl, null)
                    }
                }
                null
            }
            
            addOnCompleteListenerMethod.invoke(task, listener)
            Log.d(TAG, "FCM 토큰 요청 시작")
        } catch (e: ClassNotFoundException) {
            // Firebase가 없음 - 서버 설정만 가져오기
            if (AppConfig.USE_FIREBASE) {
                Log.w(TAG, "Firebase 설정되어 있으나 클래스를 찾을 수 없음")
            } else {
                Log.d(TAG, "Firebase 미사용 - 서버 설정만 동기화")
            }
            syncServerConfig(targetUrl, null)
        } catch (e: Exception) {
            Log.w(TAG, "FirebaseMessaging 사용 중 오류", e)
            syncServerConfig(targetUrl, null)
        }
    }

    /**
     * 네트워크 연결 확인
     */
    private fun isNetworkAvailable(): Boolean {
        val connectivityManager = getSystemService(CONNECTIVITY_SERVICE) as ConnectivityManager
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val network = connectivityManager.activeNetwork ?: return false
            val capabilities = connectivityManager.getNetworkCapabilities(network) ?: return false
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) ||
                    capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR)
        } else {
            @Suppress("DEPRECATION")
            val networkInfo = connectivityManager.activeNetworkInfo
            networkInfo?.isConnected == true
        }
    }

    /**
     * FCM 토큰 가져오기 및 서버 설정 동기화
     */
    private fun fetchFCMTokenAndSyncConfig() {
        // AppConfig에서 도메인 가져오기
        val targetUrl = AppConfig.getWebsiteDomain()
        
        if (targetUrl.isEmpty()) {
            Log.e(TAG, "웹사이트 도메인을 가져올 수 없음")
            navigateToMainActivityWithDelay(AppConfig.DEFAULT_SPLASH_DELAY_MS)
            return
        }

        // Firebase 사용 여부 확인 및 FCM 토큰 가져오기
        fetchFCMTokenIfAvailable(targetUrl)
    }

    /**
     * 서버 설정 동기화
     */
    private fun syncServerConfig(targetUrl: String, deviceToken: String?) {
        executor.execute {
            try {
                // 서버에서 설정 가져오기
                val config = AppConfigParser.fetchAppConfig(targetUrl, deviceToken)
                
                mainHandler.post {
                    appConfig = config
                    
                    if (config != null) {
                        Log.d(TAG, "서버 설정 수신: delay=${config.delayTime}, appUse=${config.appUse}")
                        
                        // 디바이스 토큰 전송 (백그라운드, 실패해도 무시)
                        if (deviceToken != null) {
                            executor.execute {
                                try {
                                    AppConfigParser.postDeviceToken(targetUrl, deviceToken)
                                } catch (e: Exception) {
                                    Log.w(TAG, "디바이스 토큰 전송 실패 (무시)", e)
                                }
                            }
                        }
                        
                        // 설정에 따른 처리
                        handleAppConfig(config, targetUrl)
                    } else {
                        Log.w(TAG, "서버 설정을 가져올 수 없음 - 기본값으로 진행")
                        // 서버 설정 실패 시 기본 딜레이로 MainActivity 이동
                        navigateToMainActivityWithDelay(AppConfig.DEFAULT_SPLASH_DELAY_MS)
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "서버 설정 동기화 오류", e)
                mainHandler.post {
                    navigateToMainActivityWithDelay(AppConfig.DEFAULT_SPLASH_DELAY_MS)
                }
            }
        }
    }

    /**
     * 앱 설정에 따른 처리
     */
    private fun handleAppConfig(config: AppConfigData, targetUrl: String) {
        // 1. 앱 사용 여부 체크
        if (!config.isAppUsable()) {
            showAppNotUseDialog()
            return
        }

        // 2. 배경 이미지 다운로드 (백그라운드)
        if (config.hasBackgroundImage()) {
            val imageUrl = AppConfig.getBackgroundImageUrl(config.bgImage)
            if (imageUrl.isNotEmpty()) {
                downloadBackgroundImage(imageUrl, config.bgName)
            }
        }

        // 3. 버전 체크
        if (config.needsVersionCheck()) {
            val currentVersion = getCurrentVersionName()
            val serverVersion = config.appVersion.trim()
            
            Log.d(TAG, "버전 비교: 현재=$currentVersion, 서버=$serverVersion")
            
            // 버전 비교 (공백 제거 후 비교)
            if (currentVersion.trim() != serverVersion) {
                // 버전이 다름 - 업데이트 다이얼로그
                Log.d(TAG, "버전 불일치 - 업데이트 다이얼로그 표시")
                showUpdateDialog(config, targetUrl)
                return
            } else {
                // 버전 같음 - 알림 체크
                Log.d(TAG, "버전 일치 - 알림 체크")
                if (config.needsNotification()) {
                    showNotificationDialog(config)
                    return
                }
            }
        } else {
            // 버전 체크 없음 - 알림만 체크
            if (config.needsNotification()) {
                showNotificationDialog(config)
                return
            }
        }

        // 4. 모든 체크 통과 - MainActivity로 이동
        val delay = if (pushUrl != null && !pushUrl.isNullOrEmpty()) {
            AppConfig.PUSH_NOTIFICATION_SPLASH_DELAY_MS // 푸시 알림이 있으면 빠르게 이동
        } else {
            config.delayTime.toLong()
        }
        navigateToMainActivityWithDelay(delay)
    }

    /**
     * 현재 앱 버전 가져오기
     * AppConfig.APP_VERSION을 우선 사용 (app_config.dart와 동기화)
     * packageInfo.versionName은 pubspec.yaml의 version에서 오므로 AppConfig와 다를 수 있음
     */
    private fun getCurrentVersionName(): String {
        // AppConfig.APP_VERSION을 우선 사용 (app_config.dart와 동기화된 값)
        val appConfigVersion = AppConfig.APP_VERSION.trim()
        
        // 디버깅을 위해 packageInfo.versionName도 로그로 확인
        try {
            val packageInfo = packageManager.getPackageInfo(packageName, 0)
            val packageVersion = packageInfo.versionName?.trim() ?: ""
            if (packageVersion.isNotEmpty() && packageVersion != appConfigVersion) {
                Log.d(TAG, "packageInfo.versionName=$packageVersion, AppConfig.APP_VERSION=$appConfigVersion (AppConfig 사용)")
            }
        } catch (e: PackageManager.NameNotFoundException) {
            Log.d(TAG, "패키지 정보를 가져올 수 없음, AppConfig 사용: ${AppConfig.APP_VERSION}")
        }
        
        // AppConfig.APP_VERSION 반환 (app_config.dart와 동기화된 값)
        return appConfigVersion
    }

    /**
     * 앱 사용 안함 다이얼로그
     */
    private fun showAppNotUseDialog() {
        AlertDialog.Builder(this)
            .setTitle("알림")
            .setMessage("앱 사용안함으로 설정되었습니다.\n앱을 종료합니다.")
            .setPositiveButton("종료") { _, _ ->
                finishAndExit()
            }
            .setOnCancelListener {
                finishAndExit()
            }
            .setOnDismissListener {
                finishAndExit()
            }
            .setCancelable(false)
            .show()
    }

    /**
     * 업데이트 다이얼로그
     */
    private fun showUpdateDialog(config: AppConfigData, targetUrl: String) {
        val builder = AlertDialog.Builder(this)
        builder.setTitle(config.updateTitle)
        builder.setMessage(config.getFormattedUpdateDesc())
        
        val appPackageName = AppConfig.APP_PACKAGE_NAME.ifEmpty { packageName }
        val storeIntent = Intent(Intent.ACTION_VIEW, Uri.parse("market://details?id=$appPackageName"))
        
        val mainIntent = Intent(this, MainActivity::class.java).apply {
            fcmToken?.let { putExtra("token", it) }
            pushUrl?.let { putExtra("url", it) }
        }
        
        if (config.isRequiredUpdate()) {
            // 필수 업데이트
            builder.setPositiveButton("업데이트") { _, _ ->
                startActivity(storeIntent)
                finishAndExit()
            }
            builder.setOnCancelListener {
                startActivity(storeIntent)
                finishAndExit()
            }
            builder.setOnDismissListener {
                startActivity(storeIntent)
                finishAndExit()
            }
        } else {
            // 선택 업데이트
            builder.setPositiveButton("업데이트") { _, _ ->
                startActivity(storeIntent)
                finishAndExit()
            }
            builder.setNegativeButton("계속사용") { _, _ ->
                // 알림이 있으면 표시
                if (config.needsNotification()) {
                    showNotificationDialog(config)
                } else {
                    navigateToMainActivityWithDelay(config.delayTime.toLong())
                }
            }
            builder.setOnCancelListener {
                // 알림이 있으면 표시
                if (config.needsNotification()) {
                    showNotificationDialog(config)
                } else {
                    navigateToMainActivityWithDelay(config.delayTime.toLong())
                }
            }
            builder.setOnDismissListener {
                // 알림이 있으면 표시
                if (config.needsNotification()) {
                    showNotificationDialog(config)
                } else {
                    navigateToMainActivityWithDelay(config.delayTime.toLong())
                }
            }
        }
        
        builder.setCancelable(false)
        builder.show()
    }

    /**
     * 알림 다이얼로그
     */
    private fun showNotificationDialog(config: AppConfigData) {
        val builder = AlertDialog.Builder(this)
        builder.setTitle(config.notiTitle)
        builder.setMessage(config.getFormattedNotiDesc())
        
        val mainIntent = Intent(this, MainActivity::class.java).apply {
            fcmToken?.let { putExtra("token", it) }
            pushUrl?.let { putExtra("url", it) }
        }
        
        if (config.appBtn == "confirm") {
            // 계속 버튼
            builder.setPositiveButton("계속") { _, _ ->
                startActivity(mainIntent)
                ActivityCompat.finishAffinity(this)
            }
            builder.setOnCancelListener {
                startActivity(mainIntent)
                ActivityCompat.finishAffinity(this)
            }
            builder.setOnDismissListener {
                startActivity(mainIntent)
                ActivityCompat.finishAffinity(this)
            }
        } else {
            // 종료 버튼
            builder.setPositiveButton("종료") { _, _ ->
                finishAndExit()
            }
            builder.setOnCancelListener {
                finishAndExit()
            }
            builder.setOnDismissListener {
                finishAndExit()
            }
        }
        
        builder.setCancelable(false)
        builder.show()
    }

    /**
     * 네트워크 연결 없음 다이얼로그
     */
    private fun showNoConnectionDialog() {
        AlertDialog.Builder(this)
            .setTitle("알림")
            .setMessage("인터넷에 연결되지 않았습니다.\n설정을 확인하고 다시 해보세요.")
            .setPositiveButton("종료") { _, _ ->
                finishAndExit()
            }
            .setOnCancelListener {
                finishAndExit()
            }
            .setOnDismissListener {
                finishAndExit()
            }
            .setCancelable(false)
            .show()
    }

    /**
     * 배경 이미지 다운로드
     */
    private fun downloadBackgroundImage(imageUrl: String, imageName: String) {
        executor.execute {
            try {
                Log.d(TAG, "배경 이미지 다운로드 시작: $imageUrl")
                
                val url = URL(imageUrl)
                val connection = url.openConnection()
                connection.connectTimeout = AppConfig.HTTP_CONNECT_TIMEOUT_MS
                connection.readTimeout = AppConfig.HTTP_READ_TIMEOUT_MS
                
                val inputStream = connection.getInputStream()
                val bitmap = BitmapFactory.decodeStream(inputStream)
                inputStream.close()
                
                if (bitmap != null) {
                    // 고정 파일명으로 저장
                    val cacheDir = File(cacheDir.absolutePath)
                    val imageFile = File(cacheDir, AppConfig.SPLASH_BG_IMAGE_NAME)
                    
                    val outputStream = FileOutputStream(imageFile)
                    bitmap.compress(Bitmap.CompressFormat.JPEG, 100, outputStream)
                    outputStream.flush()
                    outputStream.close()
                    
                    Log.d(TAG, "배경 이미지 저장 완료: ${imageFile.absolutePath}")
                    
                    // 메인 스레드에서 이미지 업데이트
                    mainHandler.post {
                        loadSplashImage()
                    }
                } else {
                    Log.e(TAG, "이미지 디코딩 실패")
                }
            } catch (e: Exception) {
                Log.e(TAG, "배경 이미지 다운로드 오류", e)
            }
        }
    }

    /**
     * 첫 실행 시 assets의 loading_image.jpg를 캐시 디렉토리에 복사
     */
    private fun firstSetLoadingImage() {
        executor.execute {
            try {
                val assetManager: AssetManager = assets
                val cacheDir = File(cacheDir.absolutePath)
                
                val inputStream: InputStream = assetManager.open(AppConfig.ASSETS_LOADING_IMAGE_NAME)
                val outputFile = File(cacheDir, AppConfig.SPLASH_BG_IMAGE_NAME)
                val outputStream: OutputStream = FileOutputStream(outputFile)

                try {
                    val buffer = ByteArray(1024)
                    var bufferLength: Int
                    while (inputStream.read(buffer).also { bufferLength = it } > 0) {
                        outputStream.write(buffer, 0, bufferLength)
                    }
                } finally {
                    outputStream.close()
                    inputStream.close()
                }

                Log.d(TAG, "첫 실행 이미지 복사 완료: ${outputFile.absolutePath}")
            } catch (e: Exception) {
                Log.e(TAG, "이미지 복사 오류", e)
            }
        }
    }

    /**
     * 캐시에서 이미지를 읽어 ImageView에 표시
     */
    private fun loadSplashImage() {
        try {
            val imageFile = File(cacheDir, AppConfig.SPLASH_BG_IMAGE_NAME)
            if (imageFile.exists()) {
                val bitmap = BitmapFactory.decodeFile(imageFile.absolutePath)
                imageView?.setImageBitmap(bitmap)
                imageView?.scaleType = android.widget.ImageView.ScaleType.CENTER_CROP
                Log.d(TAG, "스플래시 이미지 로드 완료: ${imageFile.absolutePath}")
            } else {
                Log.w(TAG, "이미지 파일이 존재하지 않음")
                // assets에서 직접 로드 시도
                loadImageFromAssets()
            }
        } catch (e: Exception) {
            Log.e(TAG, "스플래시 이미지 로드 오류", e)
            // assets에서 직접 로드 시도
            loadImageFromAssets()
        }
    }

    /**
     * assets에서 직접 이미지 로드 (fallback)
     */
    private fun loadImageFromAssets() {
        try {
            val inputStream: InputStream = assets.open(AppConfig.ASSETS_LOADING_IMAGE_NAME)
            val bitmap = BitmapFactory.decodeStream(inputStream)
            imageView?.setImageBitmap(bitmap)
            imageView?.scaleType = android.widget.ImageView.ScaleType.CENTER_CROP
            inputStream.close()
            Log.d(TAG, "assets에서 이미지 로드 완료")
        } catch (e: Exception) {
            Log.e(TAG, "assets에서 이미지 로드 오류", e)
        }
    }

    /**
     * MainActivity로 이동 (딜레이 적용)
     */
    private fun navigateToMainActivityWithDelay(delay: Long) {
        // MainActivity를 먼저 시작 (백그라운드에서 웹뷰 로드)
        navigateToMainActivity()
        
        // 딜레이 후 SplashActivity 종료 (투명 오버레이 제거)
        Handler(Looper.getMainLooper()).postDelayed({
            finish()
        }, delay)
    }

    /**
     * MainActivity로 이동 (백그라운드에서 시작)
     */
    private fun navigateToMainActivity() {
        val intent = Intent(this, MainActivity::class.java)
        
        // Intent에 전달할 데이터 추가
        fcmToken?.let { intent.putExtra("token", it) }
        pushUrl?.let { intent.putExtra("url", it) }
        
        // MainActivity 시작 (SplashActivity는 백그라운드에 유지되어 오버레이 역할)
        startActivity(intent)
        
        Log.d(TAG, "MainActivity 시작 완료 - SplashActivity는 오버레이로 유지")
    }

    /**
     * 앱 종료
     */
    private fun finishAndExit() {
        ActivityCompat.finishAffinity(this)
        System.exit(0)
    }

    /**
     * 뒤로가기 버튼 처리
     */
    override fun onKeyDown(keyCode: Int, event: KeyEvent): Boolean {
        if (event.action == KeyEvent.ACTION_DOWN) {
            if (keyCode == KeyEvent.KEYCODE_BACK) {
                val curTime = System.currentTimeMillis()
                val gapTime = curTime - backBtnTime

                if (gapTime in 0..2000) {
                    finishAndExit()
                } else {
                    backBtnTime = curTime
                    Toast.makeText(this, "뒤로 버튼을 한번 더 누르시면 종료 됩니다.", Toast.LENGTH_SHORT).show()
                }
                return true
            }
        }
        return super.onKeyDown(keyCode, event)
    }

    override fun onDestroy() {
        super.onDestroy()
        executor.shutdown()
    }
}
