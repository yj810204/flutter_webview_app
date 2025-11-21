package com.example.flutter_webview_app

/**
 * 서버에서 받은 앱 설정 데이터 모델
 * appInfo.php에서 반환하는 XML을 파싱한 결과
 */
data class AppConfigData(
    val delayTime: Int = 3000, // 기본 3초 (서버에서 값을 받지 못했을 때 사용)
    val bgImage: String = "-99",
    val bgName: String = "-99",
    val appUse: Int = 1, // -1이면 사용 안함
    val appVersion: String = "-99",
    val updateTitle: String = "-99",
    val updateDesc: String = "-99",
    val appUpdate: Int = -99, // 1: 필수, 0: 선택
    val notiUse: Int = -99,
    val notiTitle: String = "-99",
    val notiDesc: String = "-99",
    val appBtn: String = "-99" // confirm: 계속, close: 종료
) {
    /**
     * 앱 사용 가능 여부
     */
    fun isAppUsable(): Boolean = appUse != -1
    
    /**
     * 배경 이미지가 있는지 확인
     */
    fun hasBackgroundImage(): Boolean = bgImage != "-99" && bgImage.isNotEmpty()
    
    /**
     * 버전 체크가 필요한지 확인
     */
    fun needsVersionCheck(): Boolean = appVersion != "-99" && appUpdate != -99
    
    /**
     * 알림이 필요한지 확인
     */
    fun needsNotification(): Boolean = notiUse == 1 && notiTitle != "-99" && notiDesc != "-99" && appBtn != "-99"
    
    /**
     * 필수 업데이트인지 확인
     */
    fun isRequiredUpdate(): Boolean = appUpdate == 1
    
    /**
     * 설명 텍스트에서 |@|를 줄바꿈으로 변환
     */
    fun getFormattedUpdateDesc(): String = updateDesc.replace("|@|", "\n")
    
    fun getFormattedNotiDesc(): String = notiDesc.replace("|@|", "\n")
}

