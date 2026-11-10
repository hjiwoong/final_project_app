/// 서버 주소 설정
/// - 안드로이드 에뮬레이터: 10.0.2.2 = PC의 localhost
/// - 실기기: PC 내부 IP 로 변경
/// 실행 시 덮어쓰기: flutter run --dart-define=API_BASE_URL=http://192.168.0.10:8000
class Env {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://223.194.48.32:8000',
  );

  /// Google OAuth 웹 클라이언트 ID. API의 GOOGLE_CLIENT_ID와 같아야 한다.
  /// Android google-services.json의 웹 클라이언트 ID와 일치하며,
  /// 환경별 값은 GOOGLE_SERVER_CLIENT_ID로 덮어쓸 수 있다.
  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue:
        '639796441499-s3fdvlvau43s3n7389nt32f7qa145l65.apps.googleusercontent.com',
  );

  /// true 이면 API를 호출하지 않고 명시적으로 mock 모드로 동작
  static const bool useMock = bool.fromEnvironment(
    'USE_MOCK',
    defaultValue: false,
  );
}
