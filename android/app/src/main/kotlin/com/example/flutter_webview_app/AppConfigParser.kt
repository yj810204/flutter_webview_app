package com.example.flutter_webview_app

import android.util.Log
import org.xmlpull.v1.XmlPullParser
import org.xmlpull.v1.XmlPullParserFactory
import java.io.StringReader

/**
 * 서버에서 받은 XML 설정을 파싱하는 유틸리티
 */
object AppConfigParser {
    private const val TAG = "AppConfigParser"
    
    /**
     * XML 문자열을 AppConfigData로 파싱
     */
    fun parseXml(xmlString: String): AppConfigData? {
        return try {
            val factory = XmlPullParserFactory.newInstance()
            factory.isNamespaceAware = false
            val parser = factory.newPullParser()
            parser.setInput(StringReader(xmlString))
            
            var delayTime = AppConfig.DEFAULT_SPLASH_DELAY_MS.toInt()
            var bgImage = "-99"
            var bgName = "-99"
            var appUse = 1
            var appVersion = "-99"
            var updateTitle = "-99"
            var updateDesc = "-99"
            var appUpdate = -99
            var notiUse = -99
            var notiTitle = "-99"
            var notiDesc = "-99"
            var appBtn = "-99"
            
            var eventType = parser.eventType
            var currentTag: String? = null
            
            while (eventType != XmlPullParser.END_DOCUMENT) {
                when (eventType) {
                    XmlPullParser.START_TAG -> {
                        currentTag = parser.name
                    }
                    XmlPullParser.TEXT -> {
                        val text = parser.text?.trim() ?: ""
                            when (currentTag) {
                                "delay_time" -> delayTime = text.toIntOrNull() ?: AppConfig.DEFAULT_SPLASH_DELAY_MS.toInt()
                            "bg_image" -> bgImage = if (text.isEmpty()) "-99" else text
                            "bg_name" -> bgName = if (text.isEmpty()) "-99" else text
                            "app_use" -> appUse = text.toIntOrNull() ?: 1
                            "app_version" -> appVersion = if (text.isEmpty()) "-99" else text
                            "update_title" -> updateTitle = if (text.isEmpty()) "-99" else text
                            "update_desc" -> updateDesc = if (text.isEmpty()) "-99" else text
                            "app_update" -> appUpdate = text.toIntOrNull() ?: -99
                            "noti_use" -> notiUse = text.toIntOrNull() ?: -99
                            "noti_title" -> notiTitle = if (text.isEmpty()) "-99" else text
                            "noti_desc" -> notiDesc = if (text.isEmpty()) "-99" else text
                            "app_btn" -> appBtn = if (text.isEmpty()) "-99" else text
                        }
                    }
                    XmlPullParser.END_TAG -> {
                        currentTag = null
                    }
                }
                eventType = parser.next()
            }
            
            AppConfigData(
                delayTime = delayTime,
                bgImage = bgImage,
                bgName = bgName,
                appUse = appUse,
                appVersion = appVersion,
                updateTitle = updateTitle,
                updateDesc = updateDesc,
                appUpdate = appUpdate,
                notiUse = notiUse,
                notiTitle = notiTitle,
                notiDesc = notiDesc,
                appBtn = appBtn
            )
        } catch (e: Exception) {
            Log.e(TAG, "XML 파싱 오류", e)
            null
        }
    }
    
    /**
     * 서버에서 앱 설정을 가져오기
     * @param targetUrl 웹사이트 도메인 (예: howtattoo.co.kr)
     * @param deviceToken FCM 토큰 (선택)
     * @return AppConfigData 또는 null
     */
    fun fetchAppConfig(targetUrl: String, deviceToken: String? = null): AppConfigData? {
        var connection: java.net.HttpURLConnection? = null
        return try {
            val url = AppConfig.getAppInfoUrl().takeIf { it.isNotEmpty() } 
                ?: "https://$targetUrl/${AppConfig.SERVER_API_PATH_APP_INFO}"
            Log.d(TAG, "서버 설정 요청: $url")
            
            connection = java.net.URL(url).openConnection() as java.net.HttpURLConnection
            connection.requestMethod = "GET"
            connection.connectTimeout = AppConfig.HTTP_CONNECT_TIMEOUT_MS
            connection.readTimeout = AppConfig.HTTP_READ_TIMEOUT_MS
            connection.setRequestProperty("User-Agent", AppConfig.HTTP_USER_AGENT)
            
            val responseCode = connection.responseCode
            if (responseCode == java.net.HttpURLConnection.HTTP_OK) {
                val inputStream = connection.inputStream
                val reader = inputStream.bufferedReader()
                val xmlString = reader.use { it.readText() }
                reader.close()
                inputStream.close()
                
                Log.d(TAG, "서버 응답 수신: ${xmlString.take(200)}...")
                parseXml(xmlString)
            } else {
                Log.e(TAG, "서버 응답 오류: $responseCode")
                null
            }
        } catch (e: Exception) {
            Log.e(TAG, "서버 설정 가져오기 오류", e)
            null
        } finally {
            connection?.disconnect()
        }
    }
    
    /**
     * FCM 토큰을 서버로 전송
     */
    fun postDeviceToken(targetUrl: String, deviceToken: String): Boolean {
        var connection: java.net.HttpURLConnection? = null
        return try {
            val url = AppConfig.getDeviceTokenUrl().takeIf { it.isNotEmpty() }
                ?: "https://$targetUrl/${AppConfig.SERVER_API_PATH_DEVICE_TOKEN}"
            Log.d(TAG, "디바이스 토큰 전송: $url")
            
            connection = java.net.URL(url).openConnection() as java.net.HttpURLConnection
            connection.requestMethod = "POST"
            connection.doOutput = true
            connection.connectTimeout = AppConfig.HTTP_CONNECT_TIMEOUT_MS
            connection.readTimeout = AppConfig.HTTP_READ_TIMEOUT_MS
            connection.setRequestProperty("Content-Type", "application/x-www-form-urlencoded")
            connection.setRequestProperty("User-Agent", AppConfig.HTTP_USER_AGENT)
            
            val params = "device_token=$deviceToken"
            val outputStream = connection.outputStream
            outputStream.write(params.toByteArray())
            outputStream.flush()
            outputStream.close()
            
            val responseCode = connection.responseCode
            val success = responseCode == java.net.HttpURLConnection.HTTP_OK
            
            if (success) {
                Log.d(TAG, "디바이스 토큰 전송 성공")
            } else {
                Log.e(TAG, "디바이스 토큰 전송 실패: $responseCode")
            }
            
            success
        } catch (e: Exception) {
            Log.e(TAG, "디바이스 토큰 전송 오류", e)
            false
        } finally {
            connection?.disconnect()
        }
    }
}

