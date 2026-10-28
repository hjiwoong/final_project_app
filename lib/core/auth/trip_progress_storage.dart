import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../data/models/trip_progress.dart';

class TripProgressStorage {
  static const _storage = FlutterSecureStorage();
  static const _key = 'active_trip_progress';

  static Future<TripProgress?> read() async {
    final value = await _storage.read(key: _key);
    if (value == null) return null;
    return TripProgress.fromJson(
      Map<String, dynamic>.from(jsonDecode(value) as Map),
    );
  }

  static Future<void> save(TripProgress progress) =>
      _storage.write(key: _key, value: jsonEncode(progress.toJson()));

  static Future<void> clear() => _storage.delete(key: _key);
}
