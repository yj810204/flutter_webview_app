import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart' as kakao;
import '../config/app_config.dart';

/// 소셜 로그인 서비스
/// 구글과 카카오 소셜 로그인을 처리합니다.
class SocialLoginService {
  static final SocialLoginService _instance = SocialLoginService._internal();
  factory SocialLoginService() => _instance;
  SocialLoginService._internal();

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  /// 구글 로그인
  Future<Map<String, dynamic>?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      
      if (account == null) {
        debugPrint('구글 로그인 취소됨');
        return null;
      }

      final GoogleSignInAuthentication auth = await account.authentication;
      
      final result = {
        'provider': 'google',
        'id': account.id,
        'email': account.email,
        'name': account.displayName,
        'photoUrl': account.photoUrl,
        'idToken': auth.idToken,
        'accessToken': auth.accessToken,
      };

      debugPrint('구글 로그인 성공: ${account.email}');
      return result;
    } catch (e) {
      debugPrint('구글 로그인 오류: $e');
      return {
        'error': e.toString(),
      };
    }
  }

  /// 구글 로그아웃
  Future<void> signOutGoogle() async {
    try {
      await _googleSignIn.signOut();
      debugPrint('구글 로그아웃 완료');
    } catch (e) {
      debugPrint('구글 로그아웃 오류: $e');
    }
  }

  /// 카카오 로그인
  Future<Map<String, dynamic>?> signInWithKakao() async {
    try {
      // 카카오 SDK 초기화 확인
      if (!await kakao.isKakaoTalkInstalled() && !await kakao.isKakaoTalkInstalled()) {
        debugPrint('카카오톡이 설치되어 있지 않습니다. 카카오 계정으로 로그인합니다.');
      }

      kakao.OAuthToken token;
      if (await kakao.isKakaoTalkInstalled()) {
        // 카카오톡으로 로그인 시도
        try {
          token = await kakao.UserApi.instance.loginWithKakaoTalk();
        } catch (e) {
          // 카카오톡 로그인 실패 시 카카오 계정으로 로그인
          debugPrint('카카오톡 로그인 실패, 카카오 계정으로 시도: $e');
          token = await kakao.UserApi.instance.loginWithKakaoAccount();
        }
      } else {
        // 카카오 계정으로 로그인
        token = await kakao.UserApi.instance.loginWithKakaoAccount();
      }

      // 사용자 정보 가져오기
      kakao.User user = await kakao.UserApi.instance.me();
      
      final result = {
        'provider': 'kakao',
        'id': user.id.toString(),
        'email': user.kakaoAccount?.email,
        'name': user.kakaoAccount?.profile?.nickname,
        'photoUrl': user.kakaoAccount?.profile?.profileImageUrl,
        'accessToken': token.accessToken,
        'refreshToken': token.refreshToken,
      };

      debugPrint('카카오 로그인 성공: ${user.kakaoAccount?.email}');
      return result;
    } catch (e) {
      debugPrint('카카오 로그인 오류: $e');
      return {
        'error': e.toString(),
      };
    }
  }

  /// 카카오 로그아웃
  Future<void> signOutKakao() async {
    try {
      await kakao.UserApi.instance.logout();
      debugPrint('카카오 로그아웃 완료');
    } catch (e) {
      debugPrint('카카오 로그아웃 오류: $e');
    }
  }

  /// 로그인 결과를 JSON 문자열로 변환 (웹뷰로 전달용)
  String loginResultToJson(Map<String, dynamic>? result) {
    if (result == null) {
      return jsonEncode({'success': false, 'error': '로그인 취소됨'});
    }
    
    if (result.containsKey('error')) {
      return jsonEncode({'success': false, 'error': result['error']});
    }
    
    return jsonEncode({'success': true, 'data': result});
  }
}

