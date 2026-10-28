import '../../data/models/user_role.dart';
import 'trip_progress_storage.dart';
import 'token_storage.dart';

/// 로그인한 사용자 정보 (앱 실행 중 메모리 보관)
class Session {
  static UserRole? role;
  static String? email;
  static String? name;
  static int? currentTripId;
  static int? currentBoardingCount;
  static bool currentTripIsMock = false;
  static bool currentTripSimulationMode = false;
  static bool isMockAccount = false;

  static Future<void> clear() async {
    role = null;
    email = null;
    name = null;
    currentTripId = null;
    currentBoardingCount = null;
    currentTripIsMock = false;
    currentTripSimulationMode = false;
    isMockAccount = false;
    await TokenStorage.clear();
    await TripProgressStorage.clear();
  }
}
