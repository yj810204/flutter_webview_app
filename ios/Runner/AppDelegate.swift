import UIKit
import Flutter
import Photos

@main
@objc class AppDelegate: FlutterAppDelegate {
  var launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  var flutterEngine: FlutterEngine?
  var geolocationEnabled = false
  var popupSupportEnabled = false
  var splashWindow: UIWindow?
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    print("AppDelegate: didFinishLaunchingWithOptions 호출됨")
    self.launchOptions = launchOptions
    
    // Window 초기화
    if window == nil {
      window = UIWindow(frame: UIScreen.main.bounds)
      print("AppDelegate: 새 window 생성")
    }
    
    // FlutterEngine을 먼저 생성하여 FlutterAppDelegate가 사용하도록 함
    // FlutterAppDelegate는 flutterEngine 프로퍼티가 설정되어 있으면 그것을 사용함
    let engine = FlutterEngine(name: "flutter_engine")
    let engineResult = engine.run()
    if !engineResult {
      print("AppDelegate: ❌ FlutterEngine.run() 실패")
      return false
    }
    
    self.flutterEngine = engine
    print("AppDelegate: FlutterEngine 생성 완료")
    
    // FlutterAppDelegate의 기본 동작 활용
    // FlutterAppDelegate는 flutterEngine이 설정되어 있으면 그것을 사용하여 FlutterViewController 생성
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    
    print("AppDelegate: super.application() 완료 - FlutterViewController가 rootViewController로 설정됨")
    
    // configureFlutterEngine 호출하여 플러그인 등록 보장
    if let configuredEngine = self.flutterEngine {
      print("AppDelegate: FlutterEngine 확인 - configureFlutterEngine 호출")
      configureFlutterEngine(configuredEngine)
    } else {
      print("AppDelegate: ⚠️ FlutterEngine이 없음")
    }
    
    // FlutterViewController 위에 스플래시 오버레이 표시
    showSplashOverlay()
    
    print("AppDelegate: didFinishLaunchingWithOptions 완료: \(result)")
    return result
  }
  
  /**
   * 스플래시 오버레이를 별도 Window로 표시
   */
  private func showSplashOverlay() {
    // 별도 Window 생성
    splashWindow = UIWindow(frame: UIScreen.main.bounds)
    splashWindow?.windowLevel = UIWindow.Level.alert + 1 // FlutterViewController 위에 표시
    splashWindow?.backgroundColor = .clear
    
    // SplashViewController 생성 및 설정
    let splashViewController = SplashViewController()
    splashWindow?.rootViewController = splashViewController
    splashWindow?.makeKeyAndVisible()
    
    print("AppDelegate: 스플래시 오버레이 Window 표시 완료")
  }
  
  /**
   * 스플래시 오버레이 제거
   */
  func removeSplashOverlay() {
    DispatchQueue.main.async { [weak self] in
      self?.splashWindow?.isHidden = true
      self?.splashWindow = nil
      print("AppDelegate: 스플래시 오버레이 Window 제거 완료")
    }
  }
  
  func configureFlutterEngine(_ flutterEngine: FlutterEngine) {
    print("AppDelegate: ===== configureFlutterEngine 호출됨 =====")
    self.flutterEngine = flutterEngine
    
    // FlutterEngine 상태 확인
    let isEngineRunning = flutterEngine.binaryMessenger != nil
    print("AppDelegate: FlutterEngine 실행 상태: \(isEngineRunning ? "실행됨" : "실행 안됨")")
    
    if !isEngineRunning {
      print("AppDelegate: ⚠️ FlutterEngine이 실행되지 않았습니다. 플러그인 등록을 건너뜁니다.")
      return
    }
    
    // ⚠️ 중요: FlutterEngine이 생성된 후에 플러그인 등록
    // 이 시점에 engine이 실행되어 있으므로 registrar가 유효함
    print("AppDelegate: ===== 플러그인 등록 시작 (configureFlutterEngine) =====")
    print("AppDelegate: self는 FlutterPluginRegistry 준수: \(self is FlutterPluginRegistry)")
    print("AppDelegate: FlutterEngine binaryMessenger 유효: \(flutterEngine.binaryMessenger != nil)")
    
    // 플러그인 등록 시도
    GeneratedPluginRegistrant.register(with: self)
    
    print("AppDelegate: ===== 플러그인 등록 완료 (configureFlutterEngine) =====")
    
    // MethodChannels 설정
    print("AppDelegate: ===== MethodChannels 설정 시작 =====")
    setupMethodChannels(flutterEngine: flutterEngine)
    print("AppDelegate: ===== MethodChannels 설정 완료 =====")
    print("AppDelegate: ===== configureFlutterEngine 완료 =====")
  }
  
  private func setupMethodChannels(flutterEngine: FlutterEngine) {
    // Geolocation Channel
    let geolocationChannel = FlutterMethodChannel(
      name: AppConfig.methodChannelGeolocation,
      binaryMessenger: flutterEngine.binaryMessenger
    )
    geolocationChannel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      if call.method == "setGeolocationEnabled" {
        if let args = call.arguments as? [String: Any],
           let enabled = args["enabled"] as? Bool {
          self?.geolocationEnabled = enabled
          print("AppDelegate: Geolocation enabled: \(enabled)")
          result(nil)
        } else {
          result(FlutterError(code: "INVALID_ARGUMENT", message: "enabled parameter is required", details: nil))
        }
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
    
    // Image Channel
    let imageChannel = FlutterMethodChannel(
      name: AppConfig.methodChannelImage,
      binaryMessenger: flutterEngine.binaryMessenger
    )
    imageChannel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      if call.method == "saveImageToGallery" {
        self?.handleSaveImageToGallery(call: call, result: result)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
    
    // WebView Channel
    let webviewChannel = FlutterMethodChannel(
      name: AppConfig.methodChannelWebview,
      binaryMessenger: flutterEngine.binaryMessenger
    )
    webviewChannel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      if call.method == "enablePopupSupport" {
        self?.popupSupportEnabled = true
        print("AppDelegate: Popup support enabled")
        result(nil)
      } else if call.method == "showFileChooser" {
        self?.handleShowFileChooser(call: call, result: result)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
    
    print("AppDelegate: Flutter Engine configured with MethodChannels")
  }
  
  private func handleSaveImageToGallery(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let imageBytes = args["imageBytes"] as? [Int],
          let fileName = args["fileName"] as? String else {
      result(FlutterError(code: "INVALID_ARGUMENT", message: "Image bytes and fileName are required", details: nil))
      return
    }
    
    let data = Data(imageBytes.map { UInt8($0 & 0xFF) })
    
    guard let image = UIImage(data: data) else {
      result(FlutterError(code: "INVALID_IMAGE", message: "Failed to decode image", details: nil))
      return
    }
    
    saveImageToPhotoLibrary(image: image, result: result)
  }
  
  private func saveImageToPhotoLibrary(image: UIImage, result: @escaping FlutterResult) {
    PHPhotoLibrary.requestAuthorization { status in
      var isAuthorized = false
      if status == .authorized {
        isAuthorized = true
      } else if #available(iOS 14, *) {
        if status == .limited {
          isAuthorized = true
        }
      }
      
      if isAuthorized {
        PHPhotoLibrary.shared().performChanges({
          PHAssetChangeRequest.creationRequestForAsset(from: image)
        }) { success, error in
          DispatchQueue.main.async {
            if success {
              result(true)
            } else {
              result(FlutterError(code: "SAVE_FAILED", message: error?.localizedDescription, details: nil))
            }
          }
        }
      } else {
        DispatchQueue.main.async {
          result(FlutterError(code: "PERMISSION_DENIED", message: "Photo library permission denied", details: nil))
        }
      }
    }
  }
  
  private func handleShowFileChooser(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let window = self.window,
          let rootViewController = window.rootViewController else {
      result(FlutterError(code: "NO_WINDOW", message: "No window or root view controller", details: nil))
      return
    }
    
    let alert = UIAlertController(title: "파일 선택", message: nil, preferredStyle: .actionSheet)
    
    alert.addAction(UIAlertAction(title: "카메라", style: .default) { [weak self] _ in
      self?.openCamera(result: result, rootViewController: rootViewController)
    })
    
    alert.addAction(UIAlertAction(title: "갤러리", style: .default) { [weak self] _ in
      self?.openGallery(result: result, rootViewController: rootViewController)
    })
    
    alert.addAction(UIAlertAction(title: "취소", style: .cancel) { _ in
      result(nil)
    })
    
    if let popover = alert.popoverPresentationController {
      popover.sourceView = window
      popover.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
      popover.permittedArrowDirections = []
    }
    
    rootViewController.present(alert, animated: true)
  }
  
  private func openCamera(result: @escaping FlutterResult, rootViewController: UIViewController) {
    guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
      result(FlutterError(code: "CAMERA_NOT_AVAILABLE", message: "Camera is not available", details: nil))
      return
    }
    
    let picker = UIImagePickerController()
    picker.sourceType = .camera
    picker.delegate = FileChooserDelegate(result: result)
    rootViewController.present(picker, animated: true)
  }
  
  private func openGallery(result: @escaping FlutterResult, rootViewController: UIViewController) {
    let picker = UIImagePickerController()
    picker.sourceType = .photoLibrary
    picker.delegate = FileChooserDelegate(result: result)
    rootViewController.present(picker, animated: true)
  }
}

class FileChooserDelegate: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
  private let result: FlutterResult
  
  init(result: @escaping FlutterResult) {
    self.result = result
  }
  
  func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
    picker.dismiss(animated: true)
    
    if let imageUrl = info[.imageURL] as? URL {
      result([imageUrl.absoluteString])
    } else if let image = info[.originalImage] as? UIImage {
      if let data = image.jpegData(compressionQuality: 1.0),
         let tempUrl = saveTemporaryImage(data: data) {
        result([tempUrl.absoluteString])
      } else {
        result(FlutterError(code: "SAVE_FAILED", message: "Failed to save temporary image", details: nil))
      }
    } else {
      result(nil)
    }
  }
  
  func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
    picker.dismiss(animated: true)
    result(nil)
  }
  
  private func saveTemporaryImage(data: Data) -> URL? {
    let tempDir = FileManager.default.temporaryDirectory
    let tempFile = tempDir.appendingPathComponent("\(UUID().uuidString).jpg")
    
    do {
      try data.write(to: tempFile)
      return tempFile
    } catch {
      return nil
    }
  }
}
