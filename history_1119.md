# 작업 내역 요약 (2024-11-19)

## 개요

Flutter WebView 앱에서 Daum 우편번호 검색 기능을 네이티브 패키지로 전환하고, 다양한 개선 사항을 적용한 작업 내역입니다.

## 프로젝트 전체 기능

### 핵심 기능

#### 1. WebView 기본 기능
- 웹사이트 로드 및 표시 (`AppConfig.websiteUrl` 기반)
- 로딩 진행 표시 (상단 프로그레스 바)
- 뒤로가기/앞으로가기 네비게이션
- 새로고침 기능
- Android/iOS 플랫폼 지원

#### 2. 푸시 알림 (Firebase Cloud Messaging)
- Firebase Cloud Messaging 통합
- FCM 토큰 발급 및 웹뷰로 전달
- 포그라운드/백그라운드 알림 처리
- 알림 클릭 시 URL 이동 지원
- 선택적 활성화 (`AppConfig.useFirebase`)

#### 3. 소셜 로그인
- **구글 로그인**: `google_sign_in` 패키지 사용
- **카카오 로그인**: `kakao_flutter_sdk` 패키지 사용
  - 카카오톡 앱 로그인 우선 시도
  - 카카오 계정 로그인 폴백
- JavaScript 브리지를 통한 웹-앱 통신
- 로그인 결과를 웹뷰로 전달 (`window.onSocialLoginResult`)

#### 4. 위치 서비스 (Geolocation API)
- 웹뷰의 Geolocation API 오버라이드
- 위치 권한 요청 및 관리
- 허용될 때까지 반복 요청
- 영구 거부 시 설정 화면으로 이동 안내
- 현재 위치 정보 제공 (`getCurrentPosition`, `watchPosition`)
- `geolocator` 패키지 사용

#### 5. JavaScript 브리지 통신
- `FlutterChannel` JavaScript 객체 제공
- 지원 액션:
  - `getFCMToken`: FCM 토큰 요청
  - `socialLogin`: 소셜 로그인 요청
  - `openUrl`: URL 열기
  - `openNewWindow`: 새 창 열기
  - `reload`: 새로고침
  - `showAlert`: alert 표시
  - `showConfirm`: confirm 표시
  - `showPrompt`: prompt 표시
  - `searchPostcode`: 우편번호 검색

#### 6. Daum 우편번호 검색
- 네이티브 패키지 사용 (`daum_postcode_search`)
- 로컬 HTTP 서버를 통한 HTML 제공
- 다이얼로그 형태로 표시
- 검색 결과를 웹 페이지 필드에 자동 주입
- 동적 제목 표시
- SafeArea 적용

#### 7. 외부 링크 처리
- **전화 링크**: `tel:` 스킴 → 전화 앱 실행
- **문자 링크**: `sms:` 스킴 → 문자 메시지 앱 실행
- **외부 호스트**: 다른 호스트 링크 → 외부 브라우저 실행
- **소셜 로그인 호스트 예외**: OAuth 리디렉션을 웹뷰 내에서 처리

#### 8. Pull-to-Refresh
- 위에서 당겨서 새로고침
- 300px 이상 당기거나 3초 이상 유지 시 새로고침
- 아래 방향 스크롤은 정상 작동 (지도 드래그 등)

#### 9. 새창 처리
- `_blank` 타겟 링크는 다이얼로그로 표시
- 타이틀 바 포함 (닫기 버튼)
- User-Agent 설정

#### 10. User-Agent 설정
- 웹 프론트와 동일한 형식: `WpApp_ios WpVer_1_0_0` 또는 `WpApp_android WpVer_1_0_0`
- 앱 버전 정보 포함
- 웹에서 디바이스 토큰 등록 감지 가능

#### 11. Android WebView 팝업 지원
- `onCreateWindow` 콜백을 통한 팝업 처리
- 플랫폼 채널을 통한 네이티브 통신

#### 12. 커스텀 다이얼로그
- Alert, Confirm, Prompt 다이얼로그
- 웹 페이지의 JavaScript `alert()`, `confirm()`, `prompt()` 오버라이드
- 제목 없이 표시 (웹 페이지 내용만)

### 설정 및 커스터마이징

#### AppConfig (`lib/config/app_config.dart`)
- `websiteUrl`: 웹사이트 URL (기본: `https://howtattoo.co.kr/`)
- `appName`: 앱 이름
- `androidPackageName`: Android 패키지명
- `iosBundleId`: iOS 번들 ID
- `useFirebase`: Firebase 사용 여부
- `enableGoogleLogin`: 구글 로그인 활성화
- `enableKakaoLogin`: 카카오 로그인 활성화
- `kakaoNativeAppKey`: 카카오 네이티브 앱 키
- `jsChannelName`: JavaScript 채널 이름 (기본: `FlutterChannel`)
- `appVersion`: 앱 버전

### 프로젝트 구조

```
lib/
├── main.dart                          # 앱 진입점, Firebase/Kakao SDK 초기화
├── config/
│   └── app_config.dart               # 앱 설정 (URL, 키 등)
├── screens/
│   └── webview_screen.dart           # 메인 웹뷰 화면
└── services/
    ├── js_channel_handler.dart       # JavaScript 채널 핸들러
    ├── social_login_service.dart     # 소셜 로그인 서비스
    ├── push_notification_service.dart # 푸시 알림 서비스
    └── location_service.dart         # 위치 서비스
```

### 주요 의존성

- `webview_flutter`: WebView 위젯
- `webview_flutter_android`: Android WebView 확장
- `firebase_core`, `firebase_messaging`: 푸시 알림
- `google_sign_in`: 구글 로그인
- `kakao_flutter_sdk`: 카카오 로그인
- `url_launcher`: 외부 앱 실행
- `permission_handler`: 권한 관리
- `geolocator`: 위치 서비스
- `package_info_plus`: 앱 정보
- `daum_postcode_search`: 우편번호 검색

## 주요 변경 사항

### 1. Daum 우편번호 검색 네이티브 패키지 통합

#### 배경
- 기존 JavaScript `window.open()` 오버라이드를 통한 팝업 방식에서 앱이 크래시되는 문제 발생
- `daum_postcode_search` 패키지 1.0.0을 사용한 네이티브 방식으로 전환

#### 구현 내용

**1.1 패키지 추가**
- `pubspec.yaml`에 `daum_postcode_search: ^1.0.0` 추가

**1.2 JavaScript 브리지 수정**
- `initDaumPostcode()` 함수를 가로채서 Flutter로 메시지 전송
- 웹 페이지의 원래 함수는 유지하되, 호출 시 네이티브 검색 실행

**1.3 네이티브 우편번호 검색 구현**
- `_searchPostcode()` 메서드: `DaumPostcodeLocalServer`를 사용한 로컬 서버 시작
- `_DaumPostcodeDialog` 위젯: WebView를 사용한 다이얼로그 표시
- `DaumPostcodeChannel` JavaScript 채널을 통한 결과 수신
- `_handleNativePostcodeResult()` 메서드: 결과를 웹 페이지의 `postal`과 `addr` 필드에 주입

**1.4 기존 코드 제거**
- `window.open()` 오버라이드 관련 코드 제거
- `_NewWindowDialog` 클래스 및 관련 메서드 제거
- `onOpenNewWindow`, `onDaumPostcodeComplete`, `onCloseDialog` 콜백 제거

#### 파일 변경
- `lib/screens/webview_screen.dart`: 네이티브 우편번호 검색 로직 추가
- `lib/services/js_channel_handler.dart`: `searchPostcode` 액션 처리 추가
- `android/app/src/main/AndroidManifest.xml`: `android:usesCleartextTraffic="true"` 추가 (로컬 서버 HTTP 접근 허용)

### 2. 다이얼로그 개선

#### 2.1 제목 동적 변경
- 웹 페이지 제목을 동적으로 가져와서 표시
- `_pageTitle` 변수 추가 (초기값: '주소 검색')
- `onPageFinished`에서 `controller.getTitle()`로 제목 가져오기

#### 2.2 SafeArea 적용
- 다이얼로그를 `SafeArea`로 감싸서 상태바와 겹치지 않도록 처리
- 상태바 아래에 정확히 표시되도록 개선

### 3. 외부 링크 처리

#### 3.1 전화 및 문자 스킴 처리
- `tel:` 스킴 → 전화 앱 실행
- `sms:` 스킴 → 문자 메시지 앱 실행
- `url_launcher` 패키지 사용 (`LaunchMode.externalApplication`)

#### 3.2 외부 호스트 링크 처리
- `AppConfig.websiteUrl`의 호스트와 다른 호스트로의 링크는 외부 브라우저로 열기
- HTTP/HTTPS 스킴만 처리

#### 3.3 소셜 로그인 호스트 예외 처리
- 카카오, 구글, 애플, 네이버 로그인 호스트는 웹뷰 내에서 처리
- OAuth 리디렉션을 웹뷰 내에서 받을 수 있도록 예외 처리

**소셜 로그인 호스트 목록:**
- 카카오: `kauth.kakao.com`, `kapi.kakao.com`, `accounts.kakao.com`
- 구글: `accounts.google.com`, `oauth2.googleapis.com`, `www.googleapis.com`
- 애플: `appleid.apple.com`, `idmsa.apple.com`
- 네이버: `nid.naver.com`, `openapi.naver.com`

## 기술적 세부 사항

### Daum 우편번호 검색 플로우

1. 웹 페이지에서 `initDaumPostcode()` 호출
2. JavaScript 브리지가 호출을 가로채서 `searchPostcode` 액션을 Flutter로 전송
3. `_searchPostcode()` 메서드 실행:
   - `DaumPostcodeLocalServer` 시작 (포트 8080)
   - `_DaumPostcodeDialog` 다이얼로그 표시
   - 로컬 서버의 HTML 파일 로드 (`daum_search_jschannel.html`)
4. 사용자가 주소 선택
5. HTML에서 `window.DaumPostcodeChannel.postMessage(JSON.stringify(data))` 호출
6. `DaumPostcodeChannel`에서 메시지 수신 및 `DataModel`로 변환
7. `pop(result)`로 다이얼로그 닫고 결과 반환
8. `_handleNativePostcodeResult()`에서 웹 페이지 필드에 값 주입:
   - `document.getElementById('postal').value = data.zonecode`
   - `document.getElementById('addr').value = roadAddr` (도로명 주소 우선)

### 네비게이션 처리 순서

1. `tel:` 스킴 → 전화 앱 실행
2. `sms:` 스킴 → 문자 메시지 앱 실행
3. `about:blank` 또는 빈 URL → 웹뷰 내에서 처리
4. HTTP/HTTPS 스킴:
   - 소셜 로그인 호스트 → 웹뷰 내에서 처리
   - 다른 호스트 → 외부 브라우저 실행
   - 같은 호스트 → 웹뷰 내에서 네비게이션

## 해결된 문제

1. **우편번호 검색 시 앱 크래시**: 네이티브 패키지 사용으로 해결
2. **다이얼로그 제목 고정**: 웹 페이지 제목으로 동적 변경
3. **상태바 겹침**: SafeArea 적용으로 해결
4. **전화/문자 링크 미작동**: 스킴 처리 추가
5. **외부 링크 처리**: 호스트 비교 로직 추가
6. **소셜 로그인 리디렉션 실패**: 소셜 로그인 호스트 예외 처리 추가

## 주요 파일 변경 내역

### lib/screens/webview_screen.dart
- `_postcodeServer` 변수 추가 (`DaumPostcodeLocalServer`)
- `_searchPostcode()` 메서드 추가
- `_handleNativePostcodeResult()` 메서드 추가
- `_launchUrl()` 메서드 추가
- `_socialLoginHosts` 상수 리스트 추가
- `_DaumPostcodeDialog` 위젯 추가
- `onNavigationRequest` 로직 개선 (스킴 및 호스트 처리)
- `initDaumPostcode()` JavaScript 오버라이드 추가

### lib/services/js_channel_handler.dart
- `onSearchPostcode` 콜백 추가
- `_handleSearchPostcode()` 메서드 추가
- `onPostcodeResult` 콜백 및 처리 로직 제거 (DaumPostcodeChannel에서 직접 처리)

### android/app/src/main/AndroidManifest.xml
- `android:usesCleartextTraffic="true"` 추가 (로컬 서버 HTTP 접근 허용)

## 테스트 항목

- [x] 우편번호 검색 다이얼로그 정상 표시
- [x] 우편번호 검색 결과를 웹 페이지 필드에 정상 주입
- [x] 다이얼로그 제목 동적 변경
- [x] 다이얼로그 상태바 겹침 없음
- [x] 전화 링크 (`tel:`) 외부 앱 실행
- [x] 문자 링크 (`sms:`) 외부 앱 실행
- [x] 외부 호스트 링크 외부 브라우저 실행
- [x] 소셜 로그인 호스트 웹뷰 내 처리

## 참고 사항

- `daum_postcode_search` 패키지 1.0.0은 위젯을 제공하지 않고 로컬 서버와 HTML 파일을 제공
- 로컬 서버는 `rootBundle.load()`로 에셋을 로드하므로 전체 경로(`packages/daum_postcode_search/assets/...`) 필요
- Android에서 HTTP 로컬 서버 접근을 위해 `usesCleartextTraffic` 설정 필요
- 소셜 로그인 호스트 목록은 필요시 추가 가능

---

## 2024-12-XX 작업 내역: Confirm 다이얼로그 프리징 문제 해결

### 문제 상황
- `fileuploader` JavaScript 라이브러리에서 `window.confirm()` 호출 시 약 5초간 프리징 발생
- JavaScript에서 Flutter로 비동기 통신을 하면서 동기적으로 결과를 기다리는 구조로 인한 문제
- 일반 웹 브라우저에서는 네이티브 다이얼로그가 동기적으로 작동하여 프리징이 없음

### 해결 방법
**JavaScript `window.confirm` 오버라이드 제거 및 Android 네이티브 `onJsConfirm` 사용**

#### 변경 사항

**1. JavaScript 오버라이드 제거**
- `lib/screens/webview_screen.dart`의 `_injectJavaScriptBridge` 함수에서 `window.confirm` 오버라이드 제거
- 기존 Flutter 채널을 통한 비동기 처리 방식 제거
- 원래 `window.confirm()` 동작으로 복원하여 Android 네이티브 `onJsConfirm`이 자동으로 호출되도록 변경

**2. Android 네이티브 다이얼로그 활용**
- `MainActivity.kt`의 `onJsConfirm` 메서드가 이미 구현되어 있음
- 네이티브 Android `AlertDialog`를 동기적으로 표시
- `JsResult.confirm()` 또는 `JsResult.cancel()`로 즉시 결과 반환
- 프리징 없이 일반 브라우저와 동일한 사용자 경험 제공

**3. 추가 설정**
- `_setupAndroidNativeDialogs()` 메서드 추가 (확인용, 실제 설정은 불필요)
- `webview_flutter`가 네이티브 `WebChromeClient`를 자동으로 사용하므로 추가 설정 없이 작동

### 동작 방식

**이전 방식 (프리징 발생):**
1. 웹 페이지에서 `window.confirm()` 호출
2. JavaScript 오버라이드가 Flutter로 비동기 메시지 전송
3. JavaScript에서 폴링 루프로 결과 대기 (5초 프리징)
4. Flutter에서 다이얼로그 표시 및 결과 전송
5. JavaScript에서 결과 수신 및 반환

**현재 방식 (프리징 없음):**
1. 웹 페이지에서 `window.confirm()` 호출
2. Android 네이티브 `onJsConfirm` 자동 호출
3. 네이티브 `AlertDialog` 동기적으로 표시
4. 사용자 선택 시 즉시 `JsResult`로 결과 반환
5. JavaScript 실행 즉시 재개 (프리징 없음)

### 파일 변경 내역

**lib/screens/webview_screen.dart**
- `window.confirm` 오버라이드 코드 주석 처리 (902-911줄)
- `_setupAndroidNativeDialogs()` 메서드 추가 (확인용)
- `_setupAndroidPopupSupport()` 호출 시 `_setupAndroidNativeDialogs()` 추가 호출

**android/app/src/main/kotlin/com/example/flutter_webview_app/MainActivity.kt**
- 변경 없음 (기존 `onJsConfirm` 구현 그대로 사용)

### 테스트 결과
- ✅ `fileuploader` 라이브러리의 파일 삭제 확인 다이얼로그가 프리징 없이 즉시 표시
- ✅ 사용자 선택 시 즉시 반응
- ✅ 일반 웹 브라우저와 동일한 사용자 경험 제공

### 참고 사항
- `webview_flutter`는 네이티브 `WebChromeClient`를 자동으로 사용하므로 JavaScript 오버라이드를 제거하면 네이티브 다이얼로그가 자동으로 작동
- `MainActivity.kt`의 `onJsConfirm`이 이미 구현되어 있어 추가 작업 불필요
- 일반 브라우저처럼 네이티브 다이얼로그를 사용하는 것이 가장 간단하고 효율적인 해결 방법

