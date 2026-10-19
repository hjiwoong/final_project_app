import 'package:dio/dio.dart';
import '../../core/auth/token_storage.dart';
import '../../core/network/api_client.dart';
import '../../data/models/judge_result.dart';
import '../../data/models/notification_item.dart';
import '../../data/models/user_role.dart';
import '../mock/mock_repository.dart';

/// FastAPI 백엔드 연동 Repository (서버 미연동/실패 시 Mock으로 자동 폴백)
class ApiRepository {
  ApiRepository._();
  static final ApiRepository instance = ApiRepository._();

  final Dio _dio = ApiClient.instance.dio;

  // 1. 로그인 API (/auth/login)
  Future<UserRole> login(String email, String password) async {
    try {
      final response = await _dio.post('/auth/login', data: {
        'email': email,
        'password': password,
      });

      final data = response.data;
      final String accessToken = data['access_token'];
      final String roleStr = data['role']; // 'admin', 'driver', 'parent'

      await TokenStorage.save(accessToken);

      if (roleStr == 'parent') {
        return UserRole.parent;
      } else {
        return UserRole.driver;
      }
    } catch (e) {
      print('API 로그인 실패, Mock으로 폴백: $e');
      return await MockRepository.instance.login(email, password);
    }
  }

  // 2. 버스 목록 조회 (/web/buses)
  Future<List<Map<String, dynamic>>> getBuses() async {
    try {
      final response = await _dio.get('/web/buses');
      return List<Map<String, dynamic>>.from(response.data);
    } catch (e) {
      print('버스 목록 조회 실패, Mock 데이터 반환: $e');
      return [
        {'id': 1, 'name': '1호차', 'plate_no': '12가3456', 'student_count': 5},
        {'id': 2, 'name': '2호차', 'plate_no': '34나5678', 'student_count': 6},
      ];
    }
  }

  // 3. 운행 시작 (POST /trips)
  Future<int> startTrip(int busId) async {
    try {
      final response = await _dio.post('/trips', data: {
        'bus_id': busId,
      });
      return response.data['id'];
    } catch (e) {
      print('운행 시작 API 실패, 가상 ID 반환: $e');
      return 1;
    }
  }

  // 4. 승차 사진 업로드 (POST /trips/{tripId}/boarding-photo)
  Future<int> uploadBoardingPhoto(int tripId, {int mockCount = 5}) async {
    try {
      final dummyBytes = [
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
        0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
        0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
        0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
        0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
        0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
        0x42, 0x60, 0x82
      ];

      FormData formData = FormData.fromMap({
        'image': MultipartFile.fromBytes(dummyBytes, filename: 'boarding.png'),
        'captured_at': DateTime.now().toIso8601String(),
        'mock_count': mockCount,
      });

      final response = await _dio.post('/trips/$tripId/boarding-photo', data: formData);
      return response.data['boarding_count'] ?? mockCount;
    } catch (e) {
      print('승차 촬영 API 실패, Mock 사용: $e');
      return await MockRepository.instance.uploadBoardingPhoto();
    }
  }

  // 5. 종점(하차) 사진 업로드 (POST /trips/{tripId}/dropoff-photo)
  Future<JudgeResult> uploadDropoffPhoto(int tripId, {required bool oneRemaining}) async {
    try {
      final dummyBytes = [
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
        0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
        0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
        0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
        0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
        0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
        0x42, 0x60, 0x82
      ];

      FormData formData = FormData.fromMap({
        'image': MultipartFile.fromBytes(dummyBytes, filename: 'dropoff.png'),
        'captured_at': DateTime.now().toIso8601String(),
        'mock_count': oneRemaining ? 1 : 0,
      });

      final response = await _dio.post('/trips/$tripId/dropoff-photo', data: formData);
      final remaining = response.data['remaining_count'] ?? (oneRemaining ? 1 : 0);
      return JudgeResult(
        boardingCount: 5,
        remainingCount: remaining,
      );
    } catch (e) {
      print('종점 촬영 API 실패, Mock 사용: $e');
      return await MockRepository.instance.uploadDropoffPhoto(oneRemaining: oneRemaining);
    }
  }

  // 6. 하차 확인 및 운행 종료 (POST /trips/{tripId}/confirm)
  Future<void> confirmTrip(int tripId) async {
    try {
      await _dio.post('/trips/$tripId/confirm', data: {'method': 'BUTTON'});
    } catch (e) {
      print('운행 확인 API 실패 (무시): $e');
    }
  }

  // 7. 알림 목록 조회 (GET /me/notifications)
  Future<List<NotificationItem>> getNotifications() async {
    try {
      final response = await _dio.get('/me/notifications');
      final items = response.data['items'] as List;
      return items.map((n) => NotificationItem(
        id: n['id'],
        title: n['title'],
        busName: '통학버스',
        time: n['sent_at'] ?? '',
        isAlert: n['alert_id'] != null,
        read: n['is_read'],
      )).toList();
    } catch (e) {
      print('알림 조회 API 실패, Mock 사용: $e');
      return MockRepository.instance.notifications;
    }
  }

  // 8. 알림 읽음 처리 (POST /me/notifications/{id}/read)
  Future<void> readNotification(int id) async {
    try {
      await _dio.post('/me/notifications/$id/read');
    } catch (e) {
      print('알림 읽음 처리 API 실패: $e');
    }
  }
}
