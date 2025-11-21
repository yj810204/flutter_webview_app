import Foundation

/// 서버에서 받은 앱 설정 데이터 모델
/// appInfo_ios.php에서 반환하는 JSON을 파싱한 결과
struct AppConfigData {
    let delayTime: Int // 기본 3초 (서버에서 값을 받지 못했을 때 사용)
    let bgImage: String
    let bgName: String
    let appUse: Int // -1이면 사용 안함
    let appVersion: String
    let updateTitle: String
    let updateDesc: String
    let appUpdate: Int // 1: 필수, 0: 선택
    let notiUse: Int
    let notiTitle: String
    let notiDesc: String
    let appBtn: String // confirm: 계속, close: 종료
    let appId: String // iOS 전용: App Store 링크용
    
    /// 기본 초기화
    init(
        delayTime: Int = 3000,
        bgImage: String = "-99",
        bgName: String = "-99",
        appUse: Int = 1,
        appVersion: String = "-99",
        updateTitle: String = "-99",
        updateDesc: String = "-99",
        appUpdate: Int = -99,
        notiUse: Int = -99,
        notiTitle: String = "-99",
        notiDesc: String = "-99",
        appBtn: String = "-99",
        appId: String = "-99"
    ) {
        self.delayTime = delayTime
        self.bgImage = bgImage
        self.bgName = bgName
        self.appUse = appUse
        self.appVersion = appVersion
        self.updateTitle = updateTitle
        self.updateDesc = updateDesc
        self.appUpdate = appUpdate
        self.notiUse = notiUse
        self.notiTitle = notiTitle
        self.notiDesc = notiDesc
        self.appBtn = appBtn
        self.appId = appId
    }
    
    /// 앱 사용 가능 여부
    func isAppUsable() -> Bool {
        return appUse != -1
    }
    
    /// 배경 이미지가 있는지 확인
    func hasBackgroundImage() -> Bool {
        return bgImage != "-99" && !bgImage.isEmpty
    }
    
    /// 버전 체크가 필요한지 확인
    func needsVersionCheck() -> Bool {
        return appVersion != "-99" && appUpdate != -99
    }
    
    /// 알림이 필요한지 확인
    func needsNotification() -> Bool {
        return notiUse == 1 && notiTitle != "-99" && notiDesc != "-99" && appBtn != "-99"
    }
    
    /// 필수 업데이트인지 확인
    func isRequiredUpdate() -> Bool {
        return appUpdate == 1
    }
    
    /// 설명 텍스트에서 |@|를 줄바꿈으로 변환
    func getFormattedUpdateDesc() -> String {
        return updateDesc.replacingOccurrences(of: "|@|", with: "\n")
    }
    
    func getFormattedNotiDesc() -> String {
        return notiDesc.replacingOccurrences(of: "|@|", with: "\n")
    }
}

// Codable을 위한 확장 (JSON 파싱용)
extension AppConfigData: Codable {
    enum CodingKeys: String, CodingKey {
        case delayTime = "delay_time"
        case bgImage = "bg_image"
        case bgName = "bg_name"
        case appUse = "app_use"
        case appVersion = "app_version"
        case updateTitle = "update_title"
        case updateDesc = "update_desc"
        case appUpdate = "app_update"
        case notiUse = "noti_use"
        case notiTitle = "noti_title"
        case notiDesc = "noti_desc"
        case appBtn = "app_btn"
        case appId = "app_id"
    }
}
