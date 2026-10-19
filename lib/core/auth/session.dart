import '../../data/models/user_role.dart';

/// 로그인한 사용자 정보 (앱 실행 중 메모리 보관)
class Session {
  static UserRole? role;
  static String? email;
  static int? currentTripId;

  static void clear() {
    role = null;
    email = null;
    currentTripId = null;
  }
}
