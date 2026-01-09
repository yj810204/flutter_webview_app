import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';

/// 위치 정보 서비스
/// geolocator를 사용하여 실제 위치 정보를 가져옵니다.
class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  /// 현재 위치 정보 가져오기
  /// 위치 권한이 허용되어 있으면 실제 위치를 반환하고,
  /// 그렇지 않으면 null을 반환합니다.
  Future<Position?> getCurrentPosition() async {
    try {
      debugPrint('=== 위치 정보 가져오기 시작 ===');
      
      // 위치 권한 확인
      final permissionStatus = await Permission.location.status;
      debugPrint('위치 권한 상태: $permissionStatus');
      
      if (!permissionStatus.isGranted) {
        debugPrint('위치 권한이 허용되지 않았습니다.');
        return null;
      }
      
      // 위치 서비스 활성화 확인
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('위치 서비스가 비활성화되어 있습니다.');
        return null;
      }
      
      // 현재 위치 가져오기
      debugPrint('현재 위치 정보 요청 중...');
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      
      debugPrint('위치 정보 획득 성공:');
      debugPrint('  - 위도: ${position.latitude}');
      debugPrint('  - 경도: ${position.longitude}');
      debugPrint('  - 정확도: ${position.accuracy}m');
      debugPrint('  - 고도: ${position.altitude}m');
      debugPrint('  - 속도: ${position.speed}m/s');
      debugPrint('  - 방향: ${position.heading}°');
      debugPrint('  - 타임스탬프: ${position.timestamp}');
      
      return position;
    } catch (e, stackTrace) {
      debugPrint('위치 정보 가져오기 실패: $e');
      debugPrint('스택 트레이스: $stackTrace');
      return null;
    }
  }

  /// 위치 정보를 JavaScript 형식으로 변환
  /// navigator.geolocation API의 Position 객체 형식으로 변환합니다.
  Map<String, dynamic> positionToJsFormat(Position position) {
    return {
      'coords': {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'altitude': position.altitude,
        'altitudeAccuracy': position.altitudeAccuracy,
        'heading': position.heading,
        'speed': position.speed,
      },
      'timestamp': position.timestamp.millisecondsSinceEpoch,
    };
  }
}

