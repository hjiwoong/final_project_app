import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 자동 로그인용 JWT 저장
class TokenStorage {
  static const _storage = FlutterSecureStorage();
  static const _key = 'access_token';

  static Future<String?> read() => _storage.read(key: _key);
  static Future<void> save(String token) => _storage.write(key: _key, value: token);
  static Future<void> clear() => _storage.delete(key: _key);
}
