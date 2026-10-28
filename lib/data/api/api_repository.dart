import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../../core/auth/session.dart';
import '../../core/auth/token_storage.dart';
import '../../core/config/env.dart';
import '../../core/network/api_client.dart';
import '../../data/models/child_student.dart';
import '../../data/mock/mock_repository.dart';
import '../../data/models/judge_result.dart';
import '../../data/models/notification_item.dart';
import '../../data/models/user_role.dart';

/// FastAPI 연동 Repository. 목록은 비어 있거나 서버에 연결할 수 없을 때만 Mock으로 대체한다.
class ApiRepository {
  ApiRepository._();
  static final ApiRepository instance = ApiRepository._();

  final Dio _dio = ApiClient.instance.dio;

  Future<void> signup({
    required String email,
    required String password,
    required String name,
  }) async {
    if (Env.useMock) {
      await MockRepository.instance.signup(
        name: name,
        email: email,
        children: const [],
      );
      await TokenStorage.clear();
      Session.role = UserRole.parent;
      Session.email = email;
      Session.name = name;
      Session.isMockAccount = true;
      return;
    }

    late final Response<dynamic> response;
    try {
      response = await _dio.post(
        '/auth/signup',
        data: {'email': email, 'password': password, 'name': name},
      );
    } on DioException catch (e) {
      if (e.response != null) rethrow;
      debugPrint('회원가입 서버에 연결할 수 없어 Mock으로 폴백: $e');
      await MockRepository.instance.signup(
        name: name,
        email: email,
        children: const [],
      );
      await TokenStorage.clear();
      Session.role = UserRole.parent;
      Session.email = email;
      Session.name = name;
      Session.isMockAccount = true;
      return;
    }

    final data = Map<String, dynamic>.from(response.data as Map);
    final accessToken = data['access_token'] as String;
    final role = (data['role'] as String).toUpperCase();
    if (role != 'PARENT') {
      throw FormatException('회원가입 응답의 사용자 역할이 올바르지 않습니다: $role');
    }
    await TokenStorage.save(accessToken);
    Session.role = UserRole.parent;
    Session.email = email;
    final user = data['user'];
    Session.name = user is Map ? user['name'] as String? : name;
    Session.isMockAccount = false;
  }

  Future<void> addChildRequest({
    required String email,
    required String name,
    required String className,
    required String relation,
  }) async {
    if (Env.useMock || Session.isMockAccount) {
      await MockRepository.instance.addChildLinks(
        email: email,
        children: [
          MockChildLinkRequest(
            name: name,
            className: className,
            relation: relation,
          ),
        ],
      );
      return;
    }

    await _dio.post(
      '/me/child-requests',
      data: {'name': name, 'class_name': className, 'relation': relation},
    );
  }

  // 1. 로그인 API (/auth/login)
  Future<UserRole> login(String email, String password) async {
    if (Env.useMock) {
      await TokenStorage.clear();
      Session.isMockAccount = true;
      Session.name = email.split('@').first;
      return MockRepository.instance.login(email, password);
    }

    late final Response<dynamic> response;
    try {
      response = await _dio.post(
        '/auth/login',
        data: {'email': email, 'password': password},
      );
    } on DioException catch (e) {
      if (e.response != null) rethrow;
      debugPrint('로그인 서버에 연결할 수 없어 Mock으로 폴백: $e');
      await TokenStorage.clear();
      Session.isMockAccount = true;
      Session.name = email.split('@').first;
      return await MockRepository.instance.login(email, password);
    }

    final data = Map<String, dynamic>.from(response.data as Map);
    final accessToken = data['access_token'] as String;
    final roleStr = data['role'] as String;
    await TokenStorage.save(accessToken);
    Session.isMockAccount = false;
    final user = data['user'];
    Session.name = user is Map ? user['name'] as String? : null;

    switch (roleStr.toUpperCase()) {
      case 'PARENT':
        return UserRole.parent;
      case 'ADMIN':
      case 'DRIVER':
        return UserRole.driver;
    }
    throw FormatException('지원하지 않는 사용자 역할입니다: $roleStr');
  }

  // 2. 버스 목록 조회 (/web/buses)
  Future<List<Map<String, dynamic>>> getBuses() async {
    if (Env.useMock) return _mockBuses;

    late final Response<dynamic> response;
    try {
      response = await _dio.get('/web/buses');
    } on DioException catch (e) {
      if (e.response != null) rethrow;
      debugPrint('버스 목록 서버에 연결할 수 없어 Mock 데이터 반환: $e');
      return _mockBuses;
    }

    final buses = List<Map<String, dynamic>>.from(response.data);
    return buses.isEmpty ? _mockBuses : buses;
  }

  static final List<Map<String, dynamic>> _mockBuses = [
    {
      'id': 1,
      'name': '1호차',
      'plate_no': '12가3456',
      'student_count': 5,
      'is_mock': true,
    },
    {
      'id': 2,
      'name': '2호차',
      'plate_no': '34나5678',
      'student_count': 6,
      'is_mock': true,
    },
  ];

  // 학부모의 자녀 목록 조회 (/me/children)
  Future<List<ChildStudent>> getChildren() async {
    if (Env.useMock) return MockRepository.instance.children;

    late final Response<dynamic> response;
    try {
      response = await _dio.get('/me/children');
    } on DioException catch (e) {
      if (e.response != null) rethrow;
      debugPrint('자녀 목록 서버에 연결할 수 없어 Mock 데이터 반환: $e');
      return MockRepository.instance.children;
    }

    final children = (response.data as List)
        .map(
          (item) =>
              ChildStudent.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
    return children.isEmpty ? MockRepository.instance.children : children;
  }

  Future<List<ChildStudent>> getBusStudents(
    int busId, {
    bool isMock = false,
  }) async {
    if (Env.useMock || isMock) return MockRepository.instance.children;

    late final Response<dynamic> response;
    try {
      response = await _dio.get('/web/buses/$busId/students');
    } on DioException catch (e) {
      if (e.response != null) rethrow;
      debugPrint('버스 학생 서버에 연결할 수 없어 Mock 데이터 반환: $e');
      return MockRepository.instance.children;
    }

    final students = (response.data as List)
        .map(
          (item) =>
              ChildStudent.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
    return students.isEmpty ? MockRepository.instance.children : students;
  }

  // 결석 여부 저장 (PUT /me/children/{studentId}/attendance)
  Future<void> setChildAttendance(
    ChildStudent child, {
    required bool isAbsent,
    required DateTime date,
  }) async {
    if (Env.useMock || child.isMock) {
      MockRepository.instance.setMockAttendance(child.id, isAbsent);
      return;
    }

    await _dio.put(
      '/me/children/${child.id}/attendance',
      data: {
        'date': date.toIso8601String().substring(0, 10),
        'is_absent': isAbsent,
      },
    );
  }

  // 3. 운행 시작 (POST /trips)
  Future<int> startTrip(
    int busId, {
    bool isMock = false,
    bool simulationMode = false,
  }) async {
    if (Env.useMock || isMock) return 1;
    try {
      final response = await _dio.post(
        '/trips',
        data: {'bus_id': busId, 'simulation_mode': simulationMode},
      );
      return response.data['id'];
    } on DioException catch (e) {
      if (e.response != null) rethrow;
      debugPrint('운행 시작 서버에 연결할 수 없어 가상 ID 반환: $e');
      return 1;
    }
  }

  Future<Map<String, dynamic>?> getCurrentTrip() async {
    if (Env.useMock || Session.isMockAccount) return null;
    try {
      final response = await _dio.get('/trips/current');
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<void> cancelTrip(int tripId) async {
    if (Env.useMock || Session.currentTripIsMock) return;
    await _dio.delete('/trips/$tripId');
  }

  // 4. 승차 사진 업로드 (POST /trips/{tripId}/boarding-photo)
  Future<int> uploadBoardingPhoto(int tripId, {int mockCount = 5}) async {
    if (Env.useMock || Session.currentTripIsMock) {
      return MockRepository.instance.uploadBoardingPhoto();
    }
    try {
      final dummyBytes = [
        0x89,
        0x50,
        0x4E,
        0x47,
        0x0D,
        0x0A,
        0x1A,
        0x0A,
        0x00,
        0x00,
        0x00,
        0x0D,
        0x49,
        0x48,
        0x44,
        0x52,
        0x00,
        0x00,
        0x00,
        0x01,
        0x00,
        0x00,
        0x00,
        0x01,
        0x08,
        0x06,
        0x00,
        0x00,
        0x00,
        0x1F,
        0x15,
        0xC4,
        0x89,
        0x00,
        0x00,
        0x00,
        0x0A,
        0x49,
        0x44,
        0x41,
        0x54,
        0x78,
        0x9C,
        0x63,
        0x00,
        0x01,
        0x00,
        0x00,
        0x05,
        0x00,
        0x01,
        0x0D,
        0x0A,
        0x2D,
        0xB4,
        0x00,
        0x00,
        0x00,
        0x00,
        0x49,
        0x45,
        0x4E,
        0x44,
        0xAE,
        0x42,
        0x60,
        0x82,
      ];

      FormData formData = FormData.fromMap({
        'image': MultipartFile.fromBytes(
          dummyBytes,
          filename: 'boarding.png',
          contentType: DioMediaType('image', 'png'),
        ),
        'captured_at': DateTime.now().toIso8601String(),
        'mock_count': mockCount,
      });

      final response = await _dio.post(
        '/trips/$tripId/boarding-photo',
        data: formData,
      );
      return response.data['boarding_count'] ?? mockCount;
    } on DioException catch (e) {
      if (e.response != null) rethrow;
      debugPrint('승차 촬영 서버에 연결할 수 없어 Mock 사용: $e');
      return await MockRepository.instance.uploadBoardingPhoto();
    }
  }

  // 5. 종점(하차) 사진 업로드 (POST /trips/{tripId}/dropoff-photo)
  Future<JudgeResult> uploadDropoffPhoto(
    int tripId, {
    required bool oneRemaining,
  }) async {
    if (Env.useMock || Session.currentTripIsMock) {
      return MockRepository.instance.uploadDropoffPhoto(
        oneRemaining: oneRemaining,
      );
    }
    try {
      final dummyBytes = [
        0x89,
        0x50,
        0x4E,
        0x47,
        0x0D,
        0x0A,
        0x1A,
        0x0A,
        0x00,
        0x00,
        0x00,
        0x0D,
        0x49,
        0x48,
        0x44,
        0x52,
        0x00,
        0x00,
        0x00,
        0x01,
        0x00,
        0x00,
        0x00,
        0x01,
        0x08,
        0x06,
        0x00,
        0x00,
        0x00,
        0x1F,
        0x15,
        0xC4,
        0x89,
        0x00,
        0x00,
        0x00,
        0x0A,
        0x49,
        0x44,
        0x41,
        0x54,
        0x78,
        0x9C,
        0x63,
        0x00,
        0x01,
        0x00,
        0x00,
        0x05,
        0x00,
        0x01,
        0x0D,
        0x0A,
        0x2D,
        0xB4,
        0x00,
        0x00,
        0x00,
        0x00,
        0x49,
        0x45,
        0x4E,
        0x44,
        0xAE,
        0x42,
        0x60,
        0x82,
      ];

      FormData formData = FormData.fromMap({
        'image': MultipartFile.fromBytes(
          dummyBytes,
          filename: 'dropoff.png',
          contentType: DioMediaType('image', 'png'),
        ),
        'captured_at': DateTime.now().toIso8601String(),
        'mock_count': oneRemaining ? 1 : 0,
      });

      final response = await _dio.post(
        '/trips/$tripId/dropoff-photo',
        data: formData,
      );
      final remaining =
          response.data['remaining_count'] ?? (oneRemaining ? 1 : 0);
      return JudgeResult(
        boardingCount: Session.currentBoardingCount ?? 0,
        remainingCount: remaining,
      );
    } on DioException catch (e) {
      if (e.response != null) rethrow;
      debugPrint('종점 촬영 서버에 연결할 수 없어 Mock 사용: $e');
      return await MockRepository.instance.uploadDropoffPhoto(
        oneRemaining: oneRemaining,
      );
    }
  }

  // 6. 하차 확인 및 운행 종료 (POST /trips/{tripId}/confirm)
  Future<void> confirmTrip(
    int tripId, {
    required bool simulationMode,
    required bool safetyChecked,
  }) async {
    if (Env.useMock || Session.currentTripIsMock) return;
    try {
      await _dio.post(
        '/trips/$tripId/confirm',
        data: {
          'method': 'button',
          'simulation_mode': simulationMode,
          'safety_checked': safetyChecked,
        },
      );
    } on DioException catch (e) {
      if (e.response != null) rethrow;
      debugPrint('운행 종료 서버에 연결할 수 없습니다: $e');
    }
  }

  // 7. 알림 목록 조회 (GET /me/notifications)
  Future<List<NotificationItem>> getNotifications() async {
    if (Env.useMock || Session.isMockAccount) return [];

    final response = await _dio.get('/me/notifications');

    final payload = Map<String, dynamic>.from(response.data as Map);
    final items = payload['items'] as List;
    final notifications = items.map((item) {
      final n = Map<String, dynamic>.from(item as Map);
      return NotificationItem(
        id: n['id'],
        title: n['title'],
        busName: '통학버스',
        time: n['sent_at'] ?? '',
        isAlert: n['alert_id'] != null,
        read: n['is_read'],
        alertId: n['alert_id'] as int?,
      );
    }).toList();
    return notifications;
  }

  // 8. 알림 읽음 처리 (POST /me/notifications/{id}/read)
  Future<void> readNotification(NotificationItem notification) async {
    if (Env.useMock || Session.isMockAccount) return;
    await _dio.post('/me/notifications/${notification.id}/read');
  }

  Future<Map<String, dynamic>> getAlertDetail(int alertId) async {
    final path = Session.role == UserRole.parent
        ? '/me/alerts/$alertId'
        : '/alerts/$alertId';
    final response = await _dio.get(path);
    return Map<String, dynamic>.from(response.data as Map);
  }
}
