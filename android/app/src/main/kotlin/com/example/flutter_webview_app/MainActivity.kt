package com.example.flutter_webview_app

import android.Manifest
import android.app.AlertDialog
import android.app.Dialog
import android.content.ContentValues
import android.content.DialogInterface
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.os.Message
import android.provider.MediaStore
import android.util.Log
import android.view.KeyEvent
import android.view.View
import android.webkit.GeolocationPermissions
import android.webkit.JsResult
import android.webkit.ValueCallback
import android.webkit.WebChromeClient
import android.webkit.WebResourceRequest
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.Button
import android.widget.ProgressBar
import android.widget.TextView
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.graphics.BitmapFactory
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class MainActivity: FlutterActivity() {
    private val LOCATION_PERMISSION_REQUEST_CODE = 1001
    private val CAMERA_PERMISSION_REQUEST_CODE = 1002
    private val FILE_CHOOSER_REQUEST_CODE = 1003
    private val GEOLOCATION_CHANNEL = AppConfig.METHOD_CHANNEL_GEOLOCATION
    private val WEBVIEW_CHANNEL = AppConfig.METHOD_CHANNEL_WEBVIEW
    private val IMAGE_CHANNEL = AppConfig.METHOD_CHANNEL_IMAGE
    private var geolocationEnabled = false
    private var popupSupportEnabled = false
    private var fileChooserCallback: ValueCallback<Array<Uri>>? = null
    private var cameraImageUri: Uri? = null
    private var flutterFileChooserResult: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // FrameEvents 에러 로그 필터링 (시스템 로그이므로 완전히 제거는 어렵지만 시도)
        try {
            // 로그 필터 설정 (시스템 레벨 로그는 제어가 제한적)
            // 이 에러는 무해한 경고이므로 무시해도 됩니다
        } catch (e: Exception) {
            // 무시
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // 플랫폼 채널 설정 (geolocation)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, GEOLOCATION_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "setGeolocationEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    geolocationEnabled = enabled
                    Log.d("MainActivity", "Geolocation enabled: $enabled")
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        
        // 플랫폼 채널 설정 (이미지 저장)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, IMAGE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "saveImageToGallery" -> {
                    @Suppress("UNCHECKED_CAST")
                    val imageBytes = call.argument<List<Int>>("imageBytes")
                    val fileName = call.argument<String>("fileName") ?: "image_${System.currentTimeMillis()}.jpg"
                    
                    if (imageBytes != null) {
                        saveImageToGallery(imageBytes, fileName, result)
                    } else {
                        result.error("INVALID_ARGUMENT", "Image bytes are null", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        
        // 플랫폼 채널 설정 (webview - 팝업 지원 및 파일 선택기)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WEBVIEW_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "enablePopupSupport" -> {
                    popupSupportEnabled = true
                    Log.d("MainActivity", "Popup support enabled")
                    result.success(null)
                }
                "showFileChooser" -> {
                    Log.d("MainActivity", "showFileChooser called")
                    val acceptTypes = call.argument<List<String>>("acceptTypes")
                    val captureEnabled = call.argument<Boolean>("captureEnabled") ?: false
                    
                    // 파일 선택 옵션 다이얼로그 표시
                    val options = arrayOf("카메라", "갤러리", "취소")
                    AlertDialog.Builder(this@MainActivity)
                        .setTitle("파일 선택")
                        .setItems(options) { _, which ->
                            when (which) {
                                0 -> {
                                    // 카메라 선택
                                    if (checkCameraPermission()) {
                                        openCameraForFlutter(result)
                                    } else {
                                        requestCameraPermissionForFlutter(result)
                                    }
                                }
                                1 -> {
                                    // 갤러리 선택
                                    openGalleryForFlutter(result)
                                }
                                2 -> {
                                    // 취소
                                    result.success(null)
                                }
                            }
                        }
                        .setOnCancelListener {
                            result.success(null)
                        }
                        .show()
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        
        Log.d("MainActivity", "Flutter Engine configured with geolocation and popup support")
    }
    
    // WebChromeClient를 생성하여 geolocation 권한 및 팝업 처리
    // 원래 Java 앱의 onCreateWindow 구현을 참고하여 Dialog로 팝업 처리
    fun createGeolocationWebChromeClient(): WebChromeClient {
        return object : WebChromeClient() {
            override fun onGeolocationPermissionsShowPrompt(
                origin: String,
                callback: GeolocationPermissions.Callback
            ) {
                Log.d("MainActivity", "Geolocation permission requested for origin: $origin")
                Log.d("MainActivity", "Geolocation enabled: $geolocationEnabled, hasPermission: ${hasLocationPermission()}")
                
                // 위치 권한이 이미 허용되어 있고 geolocationEnabled가 true이면 자동으로 허용
                if (hasLocationPermission() && geolocationEnabled) {
                    Log.d("MainActivity", "Location permission already granted, allowing geolocation for WebView")
                    callback.invoke(origin, true, false)
                } else {
                    Log.d("MainActivity", "Location permission not granted or geolocation disabled, denying geolocation for WebView")
                    callback.invoke(origin, false, false)
                }
            }
            
            // 팝업 창 생성 처리 (Daum Postcode 등) - 원래 Java 앱의 onCreateWindow 구현 참고
            override fun onCreateWindow(
                view: WebView?,
                isDialog: Boolean,
                isUserGesture: Boolean,
                resultMsg: Message?
            ): Boolean {
                Log.d("MainActivity", "onCreateWindow called - isDialog: $isDialog, isUserGesture: $isUserGesture")
                
                // Dialog 생성 (전체화면)
                val dialog = Dialog(this@MainActivity, android.R.style.Theme_Material_Light_NoActionBar_Fullscreen)
                
                // Dialog에 WebView 추가
                val webViewDialog = WebView(this@MainActivity)
                dialog.setContentView(webViewDialog)
                
                // WebView 설정
                val webSettings = webViewDialog.settings
                webSettings.javaScriptEnabled = true
                webSettings.allowFileAccess = true
                webSettings.domStorageEnabled = true
                webSettings.setAllowFileAccessFromFileURLs(true)
                webSettings.setAllowUniversalAccessFromFileURLs(true)
                webSettings.javaScriptCanOpenWindowsAutomatically = true
                webSettings.setSupportMultipleWindows(true)
                
                // User-Agent 설정
                val userAgent = webSettings.userAgentString
                webSettings.userAgentString = "$userAgent WpApp WpPop"
                
                // WebViewClient 설정
                webViewDialog.webViewClient = object : WebViewClient() {
                    override fun shouldOverrideUrlLoading(view: WebView?, request: WebResourceRequest?): Boolean {
                        return super.shouldOverrideUrlLoading(view, request)
                    }
                }
                
                // WebChromeClient 설정 (alert, confirm 등 처리)
                webViewDialog.webChromeClient = object : WebChromeClient() {
                    override fun onJsAlert(view: WebView?, url: String?, message: String?, result: JsResult?): Boolean {
                        AlertDialog.Builder(this@MainActivity)
                            .setTitle("")
                            .setMessage(message)
                            .setPositiveButton(android.R.string.ok) { _: DialogInterface, _: Int ->
                                result?.confirm()
                            }
                            .setCancelable(false)
                            .create()
                            .show()
                        return true
                    }
                    
                    override fun onJsConfirm(view: WebView?, url: String?, message: String?, result: JsResult?): Boolean {
                        AlertDialog.Builder(this@MainActivity)
                            .setTitle("")
                            .setMessage(message)
                            .setPositiveButton(android.R.string.ok) { _: DialogInterface, _: Int ->
                                result?.confirm()
                            }
                            .setNegativeButton(android.R.string.cancel) { _: DialogInterface, _: Int ->
                                result?.cancel()
                            }
                            .setCancelable(false)
                            .create()
                            .show()
                        return true
                    }
                    
                    override fun onCloseWindow(window: WebView?) {
                        dialog.dismiss()
                        webViewDialog.destroy()
                    }
                }
                
                // 뒤로가기 키 처리
                dialog.setOnKeyListener { _, keyCode, event ->
                    if (keyCode == KeyEvent.KEYCODE_BACK && event.action == KeyEvent.ACTION_DOWN) {
                        if (webViewDialog.canGoBack()) {
                            webViewDialog.goBack()
                            true
                        } else {
                            dialog.dismiss()
                            webViewDialog.destroy()
                            true
                        }
                    } else {
                        false
                    }
                }
                
                // WebViewTransport 설정하여 팝업 WebView 연결
                val transport = resultMsg?.obj as? WebView.WebViewTransport
                transport?.setWebView(webViewDialog)
                resultMsg?.sendToTarget()
                
                // Dialog 표시
                dialog.show()
                
                return true
            }
            
            // JavaScript alert 처리 (제목 없이)
            override fun onJsAlert(
                view: WebView?,
                url: String?,
                message: String?,
                result: JsResult?
            ): Boolean {
                AlertDialog.Builder(this@MainActivity)
                    .setTitle("")
                    .setMessage(message)
                    .setPositiveButton(android.R.string.ok) { _: DialogInterface, _: Int ->
                        result?.confirm()
                    }
                    .setCancelable(false)
                    .create()
                    .show()
                return true
            }
            
            // JavaScript confirm 처리 (제목 없이)
            override fun onJsConfirm(
                view: WebView?,
                url: String?,
                message: String?,
                result: JsResult?
            ): Boolean {
                AlertDialog.Builder(this@MainActivity)
                    .setTitle("")
                    .setMessage(message)
                    .setPositiveButton(android.R.string.ok) { _: DialogInterface, _: Int ->
                        result?.confirm()
                    }
                    .setNegativeButton(android.R.string.cancel) { _: DialogInterface, _: Int ->
                        result?.cancel()
                    }
                    .setCancelable(false)
                    .create()
                    .show()
                return true
            }
            
            // 파일 선택 처리 (input type=file)
            override fun onShowFileChooser(
                webView: WebView?,
                filePathCallback: ValueCallback<Array<Uri>>?,
                fileChooserParams: WebChromeClient.FileChooserParams?
            ): Boolean {
                Log.d("MainActivity", "onShowFileChooser called")
                
                // 이전 콜백이 있으면 취소
                fileChooserCallback?.onReceiveValue(null)
                fileChooserCallback = filePathCallback
                
                // 파일 선택 옵션 다이얼로그 표시
                val options = arrayOf("카메라", "갤러리", "취소")
                AlertDialog.Builder(this@MainActivity)
                    .setTitle("파일 선택")
                    .setItems(options) { _, which ->
                        when (which) {
                            0 -> {
                                // 카메라 선택
                                if (checkCameraPermission()) {
                                    openCamera()
                                } else {
                                    requestCameraPermission()
                                }
                            }
                            1 -> {
                                // 갤러리 선택
                                openGallery()
                            }
                            2 -> {
                                // 취소
                                fileChooserCallback?.onReceiveValue(null)
                                fileChooserCallback = null
                            }
                        }
                    }
                    .setOnCancelListener {
                        fileChooserCallback?.onReceiveValue(null)
                        fileChooserCallback = null
                    }
                    .show()
                
                return true
            }
        }
    }
    
    // 카메라 권한 확인
    private fun checkCameraPermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.CAMERA
        ) == PackageManager.PERMISSION_GRANTED
    }
    
    // 카메라 권한 요청
    private fun requestCameraPermission() {
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.CAMERA),
            CAMERA_PERMISSION_REQUEST_CODE
        )
    }
    
    // 카메라 열기
    private fun openCamera() {
        try {
            val imageFile = createImageFile()
            val imageUri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                FileProvider.getUriForFile(
                    this,
                    "${packageName}.fileprovider",
                    imageFile
                )
            } else {
                Uri.fromFile(imageFile)
            }
            cameraImageUri = imageUri
            
            val cameraIntent = Intent(MediaStore.ACTION_IMAGE_CAPTURE)
            cameraIntent.putExtra(MediaStore.EXTRA_OUTPUT, imageUri)
            startActivityForResult(cameraIntent, FILE_CHOOSER_REQUEST_CODE)
        } catch (e: IOException) {
            Log.e("MainActivity", "카메라 열기 오류: ${e.message}")
            fileChooserCallback?.onReceiveValue(null)
            fileChooserCallback = null
        }
    }
    
    // Flutter용 카메라 열기
    private fun openCameraForFlutter(result: MethodChannel.Result) {
        flutterFileChooserResult = result
        try {
            val imageFile = createImageFile()
            val imageUri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                FileProvider.getUriForFile(
                    this,
                    "${packageName}.fileprovider",
                    imageFile
                )
            } else {
                Uri.fromFile(imageFile)
            }
            cameraImageUri = imageUri
            
            val cameraIntent = Intent(MediaStore.ACTION_IMAGE_CAPTURE)
            cameraIntent.putExtra(MediaStore.EXTRA_OUTPUT, imageUri)
            startActivityForResult(cameraIntent, FILE_CHOOSER_REQUEST_CODE)
        } catch (e: IOException) {
            Log.e("MainActivity", "카메라 열기 오류: ${e.message}")
            result.success(null)
            flutterFileChooserResult = null
        }
    }
    
    // Flutter용 카메라 권한 요청
    private fun requestCameraPermissionForFlutter(result: MethodChannel.Result) {
        flutterFileChooserResult = result
        requestCameraPermission()
    }
    
    // 갤러리 열기
    private fun openGallery() {
        val galleryIntent = Intent(Intent.ACTION_GET_CONTENT).apply {
            type = "image/*"
            addCategory(Intent.CATEGORY_OPENABLE)
            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, false)
        }
        
        val chooserIntent = Intent.createChooser(galleryIntent, "이미지 선택")
        startActivityForResult(chooserIntent, FILE_CHOOSER_REQUEST_CODE)
    }
    
    // Flutter용 갤러리 열기
    private fun openGalleryForFlutter(result: MethodChannel.Result) {
        flutterFileChooserResult = result
        val galleryIntent = Intent(Intent.ACTION_GET_CONTENT).apply {
            type = "image/*"
            addCategory(Intent.CATEGORY_OPENABLE)
            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, false)
        }
        
        val chooserIntent = Intent.createChooser(galleryIntent, "이미지 선택")
        startActivityForResult(chooserIntent, FILE_CHOOSER_REQUEST_CODE)
    }
    
    // 이미지 파일 생성
    @Throws(IOException::class)
    private fun createImageFile(): File {
        val timeStamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.getDefault()).format(Date())
        val imageFileName = "JPEG_${timeStamp}_"
        val storageDir = getExternalFilesDir(Environment.DIRECTORY_PICTURES)
        return File.createTempFile(imageFileName, ".jpg", storageDir)
    }
    
    // Activity 결과 처리
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        
        if (requestCode == FILE_CHOOSER_REQUEST_CODE) {
            if (resultCode == RESULT_OK) {
                val results = when {
                    cameraImageUri != null -> {
                        // 카메라에서 촬영한 이미지
                        arrayOf(cameraImageUri!!)
                    }
                    data?.data != null -> {
                        // 갤러리에서 선택한 이미지
                        arrayOf(data.data!!)
                    }
                    data?.clipData != null -> {
                        // 여러 이미지 선택 (현재는 단일 선택만 지원)
                        val uris = mutableListOf<Uri>()
                        for (i in 0 until data.clipData!!.itemCount) {
                            uris.add(data.clipData!!.getItemAt(i).uri)
                        }
                        uris.toTypedArray()
                    }
                    else -> null
                }
                
                // Flutter 채널 결과 처리
                if (flutterFileChooserResult != null) {
                    val uriStrings = results?.map { it.toString() } ?: emptyList()
                    flutterFileChooserResult?.success(uriStrings)
                    flutterFileChooserResult = null
                } else {
                    // 기존 WebView 콜백 처리
                    fileChooserCallback?.onReceiveValue(results)
                }
                cameraImageUri = null
            } else {
                // Flutter 채널 결과 처리
                if (flutterFileChooserResult != null) {
                    flutterFileChooserResult?.success(null)
                    flutterFileChooserResult = null
                } else {
                    // 기존 WebView 콜백 처리
                    fileChooserCallback?.onReceiveValue(null)
                }
                cameraImageUri = null
            }
            fileChooserCallback = null
        }
    }

    // 위치 권한 확인
    private fun hasLocationPermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED ||
        ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.ACCESS_COARSE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED
    }

    // 위치 권한 요청
    private fun requestLocationPermission() {
        ActivityCompat.requestPermissions(
            this,
            arrayOf(
                Manifest.permission.ACCESS_FINE_LOCATION,
                Manifest.permission.ACCESS_COARSE_LOCATION
            ),
            LOCATION_PERMISSION_REQUEST_CODE
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        
        when (requestCode) {
            LOCATION_PERMISSION_REQUEST_CODE -> {
                if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                    Log.d("MainActivity", "Location permission granted")
                } else {
                    Log.d("MainActivity", "Location permission denied")
                }
            }
            CAMERA_PERMISSION_REQUEST_CODE -> {
                if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                    Log.d("MainActivity", "Camera permission granted")
                    if (flutterFileChooserResult != null) {
                        openCameraForFlutter(flutterFileChooserResult!!)
                    } else {
                        openCamera()
                    }
                } else {
                    Log.d("MainActivity", "Camera permission denied")
                    if (flutterFileChooserResult != null) {
                        flutterFileChooserResult?.success(null)
                        flutterFileChooserResult = null
                    } else {
                        fileChooserCallback?.onReceiveValue(null)
                        fileChooserCallback = null
                    }
                }
            }
        }
    }
    
    // 이미지를 갤러리에 저장
    private fun saveImageToGallery(imageBytes: List<Int>, fileName: String, result: MethodChannel.Result) {
        try {
            // List<Int>를 ByteArray로 변환
            val byteArray = ByteArray(imageBytes.size)
            for (i in imageBytes.indices) {
                byteArray[i] = imageBytes[i].toByte()
            }
            
            val bitmap = BitmapFactory.decodeByteArray(byteArray, 0, byteArray.size)
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                // Android 10 이상: MediaStore 사용
                val contentValues = ContentValues().apply {
                    put(MediaStore.Images.Media.DISPLAY_NAME, fileName)
                    put(MediaStore.Images.Media.MIME_TYPE, "image/jpeg")
                    put(MediaStore.Images.Media.RELATIVE_PATH, Environment.DIRECTORY_PICTURES)
                }
                
                val uri = contentResolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, contentValues)
                uri?.let {
                    contentResolver.openOutputStream(it)?.use { outputStream ->
                        bitmap.compress(android.graphics.Bitmap.CompressFormat.JPEG, 100, outputStream)
                    }
                    result.success(true)
                } ?: run {
                    result.error("SAVE_FAILED", "Failed to create image file", null)
                }
            } else {
                // Android 9 이하: 파일 시스템 사용
                val imagesDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES)
                val imageFile = File(imagesDir, fileName)
                
                FileOutputStream(imageFile).use { outputStream ->
                    bitmap.compress(android.graphics.Bitmap.CompressFormat.JPEG, 100, outputStream)
                }
                
                // MediaStore에 스캔 요청
                val mediaScanIntent = Intent(Intent.ACTION_MEDIA_SCANNER_SCAN_FILE)
                mediaScanIntent.data = Uri.fromFile(imageFile)
                sendBroadcast(mediaScanIntent)
                
                result.success(true)
            }
        } catch (e: Exception) {
            Log.e("MainActivity", "이미지 저장 오류: ${e.message}")
            result.error("SAVE_FAILED", e.message, null)
        }
    }
}

