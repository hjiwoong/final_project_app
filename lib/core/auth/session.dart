import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../data/models/user_role.dart';
import '../network/api_client.dart';
import 'trip_progress_storage.dart';
import 'token_storage.dart';

/// 로그인한 사용자 정보 (앱 실행 중 메모리 보관)
class Session {
  static UserRole? role;
  static String? accountRole;
  static String? email;
  static String? name;
  static DateTime? createdAt;
  static int? currentTripId;
  static String? currentTripBusName;
  static int? currentBoardingCount;
  static bool currentTripIsMock = false;
  static bool currentTripSimulationMode = false;
  static bool isMockAccount = false;

  static Future<void> clear() async {
    if (!isMockAccount && await TokenStorage.read() != null) {
      try {
        await ApiClient.instance.dio.delete('/me/push-token');
      } on DioException catch (error) {
        debugPrint('로그아웃 시 푸시 토큰 해제 실패: $error');
      }
    }
    role = null;
    accountRole = null;
    email = null;
    name = null;
    createdAt = null;
    currentTripId = null;
    currentTripBusName = null;
    currentBoardingCount = null;
    currentTripIsMock = false;
    currentTripSimulationMode = false;
    isMockAccount = false;
    await TokenStorage.clear();
    await TripProgressStorage.clear();
  }
}
