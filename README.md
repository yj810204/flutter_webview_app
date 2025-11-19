# Flutter WebView 템플릿 앱

라이믹스 기반 웹사이트를 모바일 앱으로 감싸는 Flutter WebView 템플릿 앱입니다. 푸시 알림과 소셜 로그인 기능을 지원하며, 설정 파일만 수정하면 다른 웹사이트용 앱으로 쉽게 변환할 수 있습니다.

## 주요 기능

- ✅ 웹뷰로 웹사이트 로드
- ✅ 로딩 진행 표시
- ✅ 뒤로가기/앞으로가기 네비게이션
- ✅ 새로고침 기능
- ✅ 푸시 알림 지원 (Firebase Cloud Messaging)
- ✅ 소셜 로그인 지원 (구글, 카카오)
- ✅ JavaScript 채널을 통한 웹-앱 통신
- ✅ 설정 파일에서 URL 쉽게 변경 가능

## 시작하기

### 1. 프로젝트 설정

#### 웹사이트 URL 변경

`lib/config/app_config.dart` 파일을 열어 웹사이트 URL을 변경하세요:

```dart
static const String websiteUrl = 'https://your-website.com/';
```

#### 앱 이름 변경

같은 파일에서 앱 이름도 변경할 수 있습니다:

```dart
static const String appName = 'Your App Name';
```

### 2. Firebase 설정 (푸시 알림 사용 시)

#### Android

1. [Firebase Console](https://console.firebase.google.com/)에서 프로젝트 생성
2. Android 앱 추가
3. `google-services.json` 파일 다운로드
4. `android/app/` 디렉토리에 `google-services.json` 파일 복사
5. `android/app/build.gradle` 파일에서 다음 주석 해제:
   ```gradle
   id "com.google.gms.google-services"
   ```
6. `android/build.gradle` 파일에서 다음 주석 해제:
   ```gradle
   classpath 'com.google.gms:google-services:4.4.0'
   ```
7. `android/app/build.gradle`의 dependencies 섹션에서 다음 주석 해제:
   ```gradle
   implementation platform('com.google.firebase:firebase-bom:32.7.0')
   implementation 'com.google.firebase:firebase-messaging'
   ```

#### iOS

1. Firebase Console에서 iOS 앱 추가
2. `GoogleService-Info.plist` 파일 다운로드
3. `ios/Runner/` 디렉토리에 `GoogleService-Info.plist` 파일 복사
4. Xcode에서 프로젝트 열기
5. `ios/Runner/Info.plist`의 URL Schemes에 REVERSED_CLIENT_ID 추가 (GoogleService-Info.plist에서 확인)

### 3. 소셜 로그인 설정

#### 구글 로그인

**Android:**
- Firebase 설정 시 자동으로 구성됩니다
- `google-services.json` 파일에 설정이 포함되어 있습니다

**iOS:**
- `ios/Runner/Info.plist`의 `CFBundleURLSchemes`에 REVERSED_CLIENT_ID 추가
- GoogleService-Info.plist의 `REVERSED_CLIENT_ID` 값을 사용하세요

#### 카카오 로그인

1. [카카오 개발자 콘솔](https://developers.kakao.com/)에서 앱 등록
2. 네이티브 앱 키 발급
3. `lib/config/app_config.dart`에서 카카오 네이티브 앱 키 설정:
   ```dart
   static const String kakaoNativeAppKey = 'YOUR_KAKAO_NATIVE_APP_KEY';
   ```
4. Android: `android/app/src/main/AndroidManifest.xml`에 카카오 URL Scheme 추가
5. iOS: `ios/Runner/Info.plist`의 `CFBundleURLSchemes`에 카카오 URL Scheme 추가 (예: `kakaoYOUR_APP_KEY`)

### 4. 의존성 설치

```bash
flutter pub get
```

### 5. 앱 실행

```bash
# Android
flutter run

# iOS
flutter run
```

## 웹사이트에서 사용하기

### JavaScript 브리지 사용

웹사이트에서 다음 JavaScript 함수를 사용하여 네이티브 기능을 호출할 수 있습니다:

#### FCM 토큰 가져오기

```javascript
window.flutterChannel.getFCMToken();

// 콜백으로 토큰 수신
window.onFCMTokenReceived = function(token) {
  console.log('FCM Token:', token);
  // 서버로 토큰 전송
};
```

#### 소셜 로그인

```javascript
// 구글 로그인
window.flutterChannel.socialLogin('google');

// 카카오 로그인
window.flutterChannel.socialLogin('kakao');

// 콜백으로 결과 수신
window.onSocialLoginResult = function(result) {
  const data = JSON.parse(result);
  if (data.success) {
    console.log('로그인 성공:', data.data);
    // 서버로 로그인 정보 전송
  } else {
    console.error('로그인 실패:', data.error);
  }
};
```

#### URL 열기

```javascript
window.flutterChannel.openUrl('https://example.com/page');
```

## 프로젝트 구조

```
lib/
  ├── main.dart                    # 앱 진입점
  ├── config/
  │   └── app_config.dart         # 앱 설정 (URL, 키 등)
  ├── screens/
  │   └── webview_screen.dart      # 웹뷰 화면
  └── services/
      ├── js_channel_handler.dart  # JavaScript 채널 핸들러
      ├── social_login_service.dart # 소셜 로그인 서비스
      └── push_notification_service.dart # 푸시 알림 서비스
```

## 다른 웹사이트용 앱으로 변환하기

1. `lib/config/app_config.dart`에서 `websiteUrl` 변경
2. `pubspec.yaml`에서 앱 이름과 버전 변경
3. Android: `android/app/build.gradle`의 `applicationId` 변경
4. iOS: Xcode에서 Bundle Identifier 변경
5. Firebase 및 소셜 로그인 키 재설정 (필요한 경우)
6. 앱 아이콘 및 스플래시 화면 변경

## 문제 해결

### Firebase 초기화 오류

- `google-services.json` (Android) 또는 `GoogleService-Info.plist` (iOS) 파일이 올바른 위치에 있는지 확인
- Firebase 프로젝트 설정이 올바른지 확인

### 소셜 로그인이 작동하지 않음

- 각 플랫폼의 URL Scheme 설정 확인
- 개발자 콘솔에서 앱 설정 확인
- `app_config.dart`의 키 값 확인

### 웹뷰가 로드되지 않음

- 인터넷 권한이 올바르게 설정되었는지 확인
- 웹사이트 URL이 올바른지 확인
- 네트워크 연결 확인

## 라이선스

이 프로젝트는 템플릿으로 자유롭게 사용할 수 있습니다.

## 지원

문제가 발생하거나 질문이 있으시면 이슈를 등록해주세요.

