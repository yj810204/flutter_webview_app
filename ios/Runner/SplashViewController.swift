import UIKit
import Flutter
import SystemConfiguration

/// 스플래시 화면 ViewController
/// Android의 SplashActivity와 동일한 기능을 제공
class SplashViewController: UIViewController {
    private let TAG = "SplashViewController"
    
    private var splashImageView: UIImageView?
    private var pushUrl: String?
    private var fcmToken: String?
    private var appConfig: AppConfigData?
    private var backBtnTime: TimeInterval = 0
    
    private let queue = DispatchQueue(label: "com.example.flutter_webview_app.splash", qos: .utility)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 전체 화면 설정
        if #available(iOS 11.0, *) {
            view.insetsLayoutMarginsFromSafeArea = false
        }
        
        setupUI()
        
        // LaunchOptions에서 푸시 URL 확인
        if let appDelegate = UIApplication.shared.delegate as? AppDelegate,
           let launchOptions = appDelegate.launchOptions {
            if let url = launchOptions[.url] as? URL {
                pushUrl = url.absoluteString
                print("\(TAG): 푸시 URL 수신: \(pushUrl ?? "")")
            }
        }
        
        // 첫 실행 시 기본 이미지 복사
        let isFirst = !UserDefaults.standard.bool(forKey: "isFirst")
        if isFirst {
            UserDefaults.standard.set(true, forKey: "isFirst")
            firstSetLoadingImage()
        }
        
        // 이미지 표시
        loadSplashImage()
        
        // 네트워크 연결 확인 및 서버 설정 동기화
        if isNetworkAvailable() {
            fetchFCMTokenAndSyncConfig()
        } else {
            print("\(TAG): 네트워크 연결 없음")
            showNoConnectionDialog()
        }
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        view.backgroundColor = .white
        
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: view.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        self.splashImageView = imageView
    }
    
    // MARK: - Network & Server Sync
    
    private func isNetworkAvailable() -> Bool {
        var zeroAddress = sockaddr_in()
        zeroAddress.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        zeroAddress.sin_family = sa_family_t(AF_INET)
        
        guard let defaultRouteReachability = withUnsafePointer(to: &zeroAddress, {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { zeroSockAddress in
                SCNetworkReachabilityCreateWithAddress(nil, zeroSockAddress)
            }
        }) else {
            return false
        }
        
        var flags: SCNetworkReachabilityFlags = []
        if !SCNetworkReachabilityGetFlags(defaultRouteReachability, &flags) {
            return false
        }
        
        let isReachable = flags.contains(.reachable)
        let needsConnection = flags.contains(.connectionRequired)
        return isReachable && !needsConnection
    }
    
    private func fetchFCMTokenAndSyncConfig() {
        let targetUrl = AppConfig.getWebsiteDomain()
        
        if targetUrl.isEmpty {
            print("\(TAG): 웹사이트 도메인을 가져올 수 없음")
            navigateToFlutterWithDelay(AppConfig.defaultSplashDelayMs)
            return
        }
        
        if AppConfig.useFirebase {
            fetchFCMTokenIfAvailable(targetUrl: targetUrl)
        } else {
            syncServerConfig(targetUrl: targetUrl, deviceToken: nil)
        }
    }
    
    private func fetchFCMTokenIfAvailable(targetUrl: String) {
        syncServerConfig(targetUrl: targetUrl, deviceToken: nil)
    }
    
    private func syncServerConfig(targetUrl: String, deviceToken: String?) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            let config = AppConfigParser.fetchAppConfig(targetUrl: targetUrl, deviceToken: deviceToken)
            
            DispatchQueue.main.async {
                self.appConfig = config
                
                if let config = config {
                    print("\(self.TAG): 서버 설정 수신: delay=\(config.delayTime), appUse=\(config.appUse)")
                    
                    if let deviceToken = deviceToken {
                        self.queue.async {
                            _ = AppConfigParser.postDeviceToken(targetUrl: targetUrl, deviceToken: deviceToken)
                        }
                    }
                    
                    self.handleAppConfig(config: config, targetUrl: targetUrl)
                } else {
                    print("\(self.TAG): 서버 설정을 가져올 수 없음 - 기본값으로 진행")
                    self.navigateToFlutterWithDelay(AppConfig.defaultSplashDelayMs)
                }
            }
        }
    }
    
    private func handleAppConfig(config: AppConfigData, targetUrl: String) {
        if !config.isAppUsable() {
            showAppNotUseDialog()
            return
        }
        
        if config.hasBackgroundImage() {
            let imageUrl = AppConfig.getBackgroundImageUrl(imagePath: config.bgImage)
            if !imageUrl.isEmpty {
                downloadBackgroundImage(imageUrl: imageUrl, imageName: config.bgName)
            }
        }
        
        if config.needsVersionCheck() {
            let currentVersion = getCurrentVersionName()
            let serverVersion = config.appVersion.trimmingCharacters(in: .whitespacesAndNewlines)
            
            print("\(TAG): 버전 비교: 현재=\(currentVersion), 서버=\(serverVersion)")
            
            if currentVersion.trimmingCharacters(in: .whitespacesAndNewlines) != serverVersion {
                print("\(TAG): 버전 불일치 - 업데이트 다이얼로그 표시")
                showUpdateDialog(config: config, targetUrl: targetUrl)
                return
            } else {
                print("\(TAG): 버전 일치 - 알림 체크")
                if config.needsNotification() {
                    showNotificationDialog(config: config)
                    return
                }
            }
        } else {
            if config.needsNotification() {
                showNotificationDialog(config: config)
                return
            }
        }
        
        let delay = (pushUrl != nil && !pushUrl!.isEmpty)
            ? AppConfig.pushNotificationSplashDelayMs
            : TimeInterval(config.delayTime) / 1000.0
        navigateToFlutterWithDelay(delay)
    }
    
    private func getCurrentVersionName() -> String {
        let appConfigVersion = AppConfig.appVersion.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if let bundleVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
           !bundleVersion.isEmpty && bundleVersion != appConfigVersion {
            print("\(TAG): CFBundleShortVersionString=\(bundleVersion), AppConfig.appVersion=\(appConfigVersion) (AppConfig 사용)")
        }
        
        return appConfigVersion
    }
    
    // MARK: - Dialogs
    
    private func showAppNotUseDialog() {
        let alert = UIAlertController(
            title: "알림",
            message: "앱 사용안함으로 설정되었습니다.\n앱을 종료합니다.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "종료", style: .default) { [weak self] _ in
            self?.finishAndExit()
        })
        present(alert, animated: true)
    }
    
    private func showUpdateDialog(config: AppConfigData, targetUrl: String) {
        let alert = UIAlertController(
            title: config.updateTitle,
            message: config.getFormattedUpdateDesc(),
            preferredStyle: .alert
        )
        
        let appId = config.appId != "-99" ? config.appId : AppConfig.iosBundleId
        let storeUrl = "https://apps.apple.com/app/id\(appId)"
        
        if config.isRequiredUpdate() {
            alert.addAction(UIAlertAction(title: "업데이트", style: .default) { [weak self] _ in
                if let url = URL(string: storeUrl) {
                    UIApplication.shared.open(url)
                }
                self?.finishAndExit()
            })
        } else {
            alert.addAction(UIAlertAction(title: "업데이트", style: .default) { [weak self] _ in
                if let url = URL(string: storeUrl) {
                    UIApplication.shared.open(url)
                }
                self?.finishAndExit()
            })
            alert.addAction(UIAlertAction(title: "계속사용", style: .cancel) { [weak self] _ in
                guard let self = self else { return }
                if config.needsNotification() {
                    self.showNotificationDialog(config: config)
                } else {
                    let delay = TimeInterval(config.delayTime) / 1000.0
                    self.navigateToFlutterWithDelay(delay)
                }
            })
        }
        
        present(alert, animated: true)
    }
    
    private func showNotificationDialog(config: AppConfigData) {
        let alert = UIAlertController(
            title: config.notiTitle,
            message: config.getFormattedNotiDesc(),
            preferredStyle: .alert
        )
        
        if config.appBtn == "confirm" {
            alert.addAction(UIAlertAction(title: "계속", style: .default) { [weak self] _ in
                self?.removeSplashOverlay()
            })
        } else {
            alert.addAction(UIAlertAction(title: "종료", style: .default) { [weak self] _ in
                self?.finishAndExit()
            })
        }
        
        present(alert, animated: true)
    }
    
    private func showNoConnectionDialog() {
        let alert = UIAlertController(
            title: "알림",
            message: "인터넷에 연결되지 않았습니다.\n설정을 확인하고 다시 해보세요.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "종료", style: .default) { [weak self] _ in
            self?.finishAndExit()
        })
        present(alert, animated: true)
    }
    
    // MARK: - Image Handling
    
    private func downloadBackgroundImage(imageUrl: String, imageName: String) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            guard let url = URL(string: imageUrl) else {
                print("\(self.TAG): 잘못된 이미지 URL: \(imageUrl)")
                return
            }
            
            print("\(self.TAG): 배경 이미지 다운로드 시작: \(imageUrl)")
            
            var request = URLRequest(url: url)
            request.timeoutInterval = AppConfig.httpConnectTimeoutMs
            
            let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("\(self.TAG): 배경 이미지 다운로드 오류: \(error)")
                    return
                }
                
                guard let data = data,
                      let image = UIImage(data: data) else {
                    print("\(self.TAG): 이미지 디코딩 실패")
                    return
                }
                
                if let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first {
                    let imageFile = cacheDir.appendingPathComponent(AppConfig.splashBgImageName)
                    
                    if let imageData = image.jpegData(compressionQuality: 1.0) {
                        do {
                            try imageData.write(to: imageFile)
                            print("\(self.TAG): 배경 이미지 저장 완료: \(imageFile.path)")
                            
                            DispatchQueue.main.async {
                                self.loadSplashImage()
                            }
                        } catch {
                            print("\(self.TAG): 이미지 저장 오류: \(error)")
                        }
                    }
                }
            }
            
            task.resume()
        }
    }
    
    private func firstSetLoadingImage() {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            guard let imagePath = Bundle.main.path(forResource: "loading_image", ofType: "jpg"),
                  let imageData = try? Data(contentsOf: URL(fileURLWithPath: imagePath)),
                  let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
                print("\(self.TAG): 이미지 파일을 찾을 수 없음")
                return
            }
            
            let outputFile = cacheDir.appendingPathComponent(AppConfig.splashBgImageName)
            
            do {
                try imageData.write(to: outputFile)
                print("\(self.TAG): 첫 실행 이미지 복사 완료: \(outputFile.path)")
            } catch {
                print("\(self.TAG): 이미지 복사 오류: \(error)")
            }
        }
    }
    
    private func loadSplashImage() {
        if let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first {
            let imageFile = cacheDir.appendingPathComponent(AppConfig.splashBgImageName)
            
            if FileManager.default.fileExists(atPath: imageFile.path),
               let image = UIImage(contentsOfFile: imageFile.path) {
                splashImageView?.image = image
                print("\(TAG): 스플래시 이미지 로드 완료: \(imageFile.path)")
                return
            }
        }
        
        loadImageFromBundle()
    }
    
    private func loadImageFromBundle() {
        if let imagePath = Bundle.main.path(forResource: "loading_image", ofType: "jpg"),
           let image = UIImage(contentsOfFile: imagePath) {
            splashImageView?.image = image
            print("\(TAG): Bundle에서 이미지 로드 완료")
        } else {
            print("\(TAG): Bundle에서 이미지 로드 오류")
        }
    }
    
    // MARK: - Navigation
    
    private func navigateToFlutterWithDelay(_ delay: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.removeSplashOverlay()
        }
    }
    
    private func navigateToFlutter() {
        removeSplashOverlay()
    }
    
    /**
     * 스플래시 오버레이 제거 (AppDelegate에 위임)
     */
    private func removeSplashOverlay() {
        if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
            appDelegate.removeSplashOverlay()
            print("\(TAG): 스플래시 오버레이 제거 요청 완료")
        }
    }
    
    private func finishAndExit() {
        exit(0)
    }
    
    // MARK: - Lifecycle
    
    override var prefersStatusBarHidden: Bool {
        return false
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
}
