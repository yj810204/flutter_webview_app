import Foundation

/// 서버에서 받은 JSON 설정을 파싱하는 유틸리티
/// appInfo_ios.php는 JSON 형식으로 응답
class AppConfigParser {
    private static let TAG = "AppConfigParser"
    
    /// JSON 문자열을 AppConfigData로 파싱
    static func parseJson(_ jsonString: String) -> AppConfigData? {
        guard let jsonData = jsonString.data(using: .utf8) else {
            print("\(TAG): JSON 데이터 변환 실패")
            return nil
        }
        
        do {
            let decoder = JSONDecoder()
            // 서버에서 문자열로 오는 숫자 필드 처리
            let jsonObject = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
            
            guard let json = jsonObject else {
                print("\(TAG): JSON 파싱 실패")
                return nil
            }
            
            // 각 필드 파싱 (서버에서 문자열로 올 수 있으므로 안전하게 처리)
            // delay_time은 서버에서 문자열 "3000"으로 올 수 있으므로 parseInt 사용
            let delayTime = parseInt(from: json["delay_time"], defaultValue: 3000)
            let bgImage = parseString(from: json["bg_image"], defaultValue: "-99")
            let bgName = parseString(from: json["bg_name"], defaultValue: "-99")
            let appUse = parseInt(from: json["app_use"], defaultValue: 1)
            let appVersion = parseString(from: json["app_version"], defaultValue: "-99")
            let updateTitle = parseString(from: json["update_title"], defaultValue: "-99")
            let updateDesc = parseString(from: json["update_desc"], defaultValue: "-99")
            let appUpdate = parseInt(from: json["app_update"], defaultValue: -99)
            let notiUse = parseInt(from: json["noti_use"], defaultValue: -99)
            let notiTitle = parseString(from: json["noti_title"], defaultValue: "-99")
            let notiDesc = parseString(from: json["noti_desc"], defaultValue: "-99")
            let appBtn = parseString(from: json["app_btn"], defaultValue: "-99")
            let appId = parseString(from: json["app_id"], defaultValue: "-99")
            
            return AppConfigData(
                delayTime: delayTime,
                bgImage: bgImage,
                bgName: bgName,
                appUse: appUse,
                appVersion: appVersion,
                updateTitle: updateTitle,
                updateDesc: updateDesc,
                appUpdate: appUpdate,
                notiUse: notiUse,
                notiTitle: notiTitle,
                notiDesc: notiDesc,
                appBtn: appBtn,
                appId: appId
            )
        } catch {
            print("\(TAG): JSON 파싱 오류: \(error)")
            return nil
        }
    }
    
    /// 서버에서 앱 설정을 가져오기
    /// - Parameters:
    ///   - targetUrl: 웹사이트 도메인 (예: howtattoo.co.kr)
    ///   - deviceToken: FCM 토큰 (선택)
    /// - Returns: AppConfigData 또는 nil
    static func fetchAppConfig(targetUrl: String, deviceToken: String? = nil) -> AppConfigData? {
        let urlString = AppConfig.getAppInfoIOSUrl().isEmpty 
            ? "https://\(targetUrl)/\(AppConfig.serverApiPathAppInfoIOS)"
            : AppConfig.getAppInfoIOSUrl()
        
        guard let url = URL(string: urlString) else {
            print("\(TAG): 잘못된 URL: \(urlString)")
            return nil
        }
        
        print("\(TAG): 서버 설정 요청: \(urlString)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = AppConfig.httpConnectTimeoutMs
        request.setValue(AppConfig.httpUserAgent, forHTTPHeaderField: "User-Agent")
        
        let semaphore = DispatchSemaphore(value: 0)
        var result: AppConfigData?
        var responseError: Error?
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            defer { semaphore.signal() }
            
            if let error = error {
                print("\(TAG): 서버 설정 가져오기 오류: \(error)")
                responseError = error
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let data = data else {
                print("\(TAG): 서버 응답 오류: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
                return
            }
            
            guard let jsonString = String(data: data, encoding: .utf8) else {
                print("\(TAG): 응답 데이터 변환 실패")
                return
            }
            
            let preview = String(jsonString.prefix(200))
            print("\(TAG): 서버 응답 수신: \(preview)...")
            
            result = parseJson(jsonString)
        }
        
        task.resume()
        _ = semaphore.wait(timeout: .now() + AppConfig.httpReadTimeoutMs)
        
        if responseError != nil {
            return nil
        }
        
        return result
    }
    
    /// FCM 토큰을 서버로 전송
    /// - Parameters:
    ///   - targetUrl: 웹사이트 도메인
    ///   - deviceToken: FCM 토큰
    /// - Returns: 성공 여부
    static func postDeviceToken(targetUrl: String, deviceToken: String) -> Bool {
        let urlString = AppConfig.getDeviceTokenUrl().isEmpty
            ? "https://\(targetUrl)/\(AppConfig.serverApiPathDeviceToken)"
            : AppConfig.getDeviceTokenUrl()
        
        guard let url = URL(string: urlString) else {
            print("\(TAG): 잘못된 URL: \(urlString)")
            return false
        }
        
        print("\(TAG): 디바이스 토큰 전송: \(urlString)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = AppConfig.httpConnectTimeoutMs
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue(AppConfig.httpUserAgent, forHTTPHeaderField: "User-Agent")
        
        let postData = "device_token=\(deviceToken)".data(using: .utf8)
        request.httpBody = postData
        
        let semaphore = DispatchSemaphore(value: 0)
        var success = false
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            defer { semaphore.signal() }
            
            if let error = error {
                print("\(TAG): 디바이스 토큰 전송 오류: \(error)")
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                success = httpResponse.statusCode == 200
                if success {
                    print("\(TAG): 디바이스 토큰 전송 성공")
                } else {
                    print("\(TAG): 디바이스 토큰 전송 실패: \(httpResponse.statusCode)")
                }
            }
        }
        
        task.resume()
        _ = semaphore.wait(timeout: .now() + AppConfig.httpReadTimeoutMs)
        
        return success
    }
    
    // MARK: - Helper Methods
    
    private static func parseInt(from value: Any?, defaultValue: Int) -> Int {
        if let intValue = value as? Int {
            return intValue
        }
        if let stringValue = value as? String, let intValue = Int(stringValue) {
            return intValue
        }
        return defaultValue
    }
    
    private static func parseString(from value: Any?, defaultValue: String) -> String {
        if let stringValue = value as? String {
            return stringValue.isEmpty ? defaultValue : stringValue
        }
        return defaultValue
    }
}
