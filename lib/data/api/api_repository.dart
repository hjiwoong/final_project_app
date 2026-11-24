import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/auth/session.dart';
import '../../core/auth/token_storage.dart';
import '../../core/network/api_client.dart';
import '../../core/notifications/push_notification_service.dart';
import '../../data/models/child_student.dart';
import '../../data/models/child_attendance.dart';
import '../../data/models/child_link_request.dart';
import '../../data/models/child_location.dart';
import '../../data/models/account_deletion_schedule.dart';
import '../../data/models/judge_result.dart';
import '../../data/models/notification_item.dart';
import '../../data/models/signup_term.dart';
import '../../data/models/user_role.dart';

abstract interface class SignupGateway {
  Future<List<SignupTermInfo>> getSignupTerms();

  Future<void> signup({
    required String email,
    required String password,
    required String name,
    required List<SignupTermAgreement> agreements,
  });
}

abstract interface class TermsGateway {
  Future<List<SignupTermInfo>> getSignupTerms();
  Future<List<SignupTermAgreement>> getMyAgreements();
  Future<List<SignupTermAgreement>> getPendingTerms();
  Future<void> saveAgreements(List<SignupTermAgreement> agreements);
}

/// FastAPI 연동 Repository. 모든 데이터는 서버 API에서 가져온다.
class ApiRepository implements SignupGateway, TermsGateway {
  ApiRepository._();
  static final ApiRepository instance = ApiRepository._();

  final Dio _dio = ApiClient.instance.dio;

  Future<XFile?> pickImage({ImageSource source = ImageSource.camera}) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1600,
    );
    return file;
  }

  Future<FormData> buildUploadFormData({
    required XFile image,
    required String fieldName,
    required DateTime capturedAt,
  }) async {
    final file = File(image.path);
    if (!await file.exists()) {
      throw StateError('선택한 이미지 파일을 찾을 수 없습니다.');
    }

    return FormData.fromMap({
      fieldName: await MultipartFile.fromFile(
        image.path,
        filename: image.name.isNotEmpty
            ? image.name
            : '${fieldName}_${DateTime.now().millisecondsSinceEpoch}.jpg',
        contentType: DioMediaType('image', 'jpeg'),
      ),
      'captured_at': capturedAt.toUtc().toIso8601String(),
    });
  }

  @override
  Future<List<SignupTermInfo>> getSignupTerms() async {
    final response = await _dio.get(
      '/terms',
      options: Options(
        extra: const {'skipAuth': true, 'skipTermsRequired': true},
      ),
    );
    final payload = response.data;
    final rawTerms = payload is Map ? payload['terms'] : payload;
    if (rawTerms is! List) {
      throw const FormatException('약관 응답 형식이 올바르지 않습니다.');
    }

    final terms = rawTerms
        .map(
          (item) =>
              SignupTermInfo.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
    for (final type in SignupTermType.values) {
      if (terms.where((term) => term.type == type).length != 1) {
        throw FormatException('필수 약관 정보가 올바르지 않습니다: ${type.apiValue}');
      }
    }
    return SignupTermType.values
        .map((type) => terms.singleWhere((term) => term.type == type))
        .toList();
  }

  @override
  Future<List<SignupTermAgreement>> getMyAgreements() async {
    final response = await _dio.get(
      '/me/agreements',
      options: Options(extra: const {'skipTermsRequired': true}),
    );
    final data = response.data;
    if (data is! List) {
      throw const FormatException('동의 내역 응답 형식이 올바르지 않습니다.');
    }
    return data.map((item) {
      final record = Map<String, dynamic>.from(item as Map);
      return SignupTermAgreement.fromJson(record);
    }).toList();
  }

  @override
  Future<List<SignupTermAgreement>> getPendingTerms() async {
    final response = await _dio.get(
      '/me',
      options: Options(extra: const {'skipTermsRequired': true}),
    );
    final user = Map<String, dynamic>.from(response.data as Map);
    final pendingTerms = _parsePendingTerms(user['pending_terms']);
    Session.pendingTerms = pendingTerms;
    return pendingTerms;
  }

  @override
  Future<void> saveAgreements(List<SignupTermAgreement> agreements) async {
    await _dio.post(
      '/me/agreements',
      data: {'agreements': agreements.map((item) => item.toJson()).toList()},
      options: Options(extra: const {'skipTermsRequired': true}),
    );
    Session.pendingTerms = const [];
  }

  @override
  Future<void> signup({
    required String email,
    required String password,
    required String name,
    required List<SignupTermAgreement> agreements,
  }) async {
    final response = await _dio.post(
      '/auth/signup',
      data: {
        'email': email,
        'password': password,
        'name': name,
        'children': [],
        'agreements': agreements
            .map((agreement) => agreement.toJson())
            .toList(),
      },
    );

    final data = Map<String, dynamic>.from(response.data as Map);
    final accessToken = data['access_token'] as String;
    final role = (data['role'] as String).toUpperCase();
    if (role != 'PARENT') {
      throw FormatException('회원가입 응답의 사용자 역할이 올바르지 않습니다: $role');
    }
    await TokenStorage.save(accessToken);
    Session.role = UserRole.parent;
    Session.accountRole = role;
    Session.email = email;
    final user = data['user'];
    if (user is Map) {
      Session.name = user['name'] as String? ?? name;
      Session.createdAt = _parseCreatedAt(user['created_at']);
      Session.signupMethod = user['signup_method'] as String? ?? 'UNKNOWN';
    } else {
      Session.name = name;
      Session.createdAt = null;
      Session.signupMethod = 'UNKNOWN';
    }
    await _initializePushNotifications();
  }

  Future<void> addChildRequest({
    required String email,
    required String name,
    required String className,
    required String relation,
  }) async {
    await _dio.post(
      '/me/child-requests',
      data: {'name': name, 'class_name': className, 'relation': relation},
    );
  }

  Future<List<ChildLinkRequest>> getChildRequests() async {
    final response = await _dio.get('/me/child-requests');
    return (response.data as List)
        .map(
          (item) =>
              ChildLinkRequest.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  Future<void> cancelChildRequest(ChildLinkRequest request) async {
    await _dio.delete('/me/child-requests/${request.id}');
  }

  Future<ChildLocation> getChildLocation(int childId) async {
    final response = await _dio.get('/me/children/$childId/location');
    return ChildLocation.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  /// 입력 중인 주소의 후보 목록 (자동완성). 결과가 없으면 빈 목록.
  Future<List<AddressCandidate>> searchAddressCandidates(
    String address, {
    CancelToken? cancelToken,
  }) async {
    final query = address.trim();
    if (query.length < 2) return const [];

    final response = await _dio.get(
      '/me/location/search',
      queryParameters: {'address': query},
      cancelToken: cancelToken,
    );
    return (response.data as List)
        .map(
          (item) =>
              AddressCandidate.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  Future<ChildLocation> saveChildLocation(
    int childId, {
    required String address,
    double? latitude,
    double? longitude,
  }) async {
    if ((latitude == null) != (longitude == null)) {
      throw ArgumentError('위도와 경도는 함께 입력해야 합니다.');
    }
    final data = <String, Object>{'address': address};
    if (latitude != null) data['latitude'] = latitude;
    if (longitude != null) data['longitude'] = longitude;

    final response = await _dio.put(
      '/me/children/$childId/location',
      data: data,
    );
    return ChildLocation.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<void> clearChildLocation(int childId) async {
    await _dio.delete('/me/children/$childId/location');
  }

  Future<void> unlinkChild(ChildStudent child) async {
    await _dio.delete('/me/children/${child.id}');
  }

  Future<AccountDeletionSchedule> requestAccountDeletion({
    String? currentPassword,
    String? googleIdToken,
  }) async {
    if (Session.accountRole?.toUpperCase() != 'PARENT' &&
        Session.role != UserRole.parent) {
      throw StateError('학부모 계정만 삭제를 요청할 수 있습니다.');
    }
    if ((currentPassword == null) == (googleIdToken == null)) {
      throw ArgumentError('비밀번호 또는 Google 인증 정보 중 하나가 필요합니다.');
    }

    final response = await _dio.post(
      '/me/account-deletion',
      data: {
        'current_password': ?currentPassword,
        'google_id_token': ?googleIdToken,
      },
    );
    return AccountDeletionSchedule.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<void> verifyAccountPassword(String password) async {
    final email = Session.email;
    if (email == null || email.isEmpty) {
      throw StateError('로그인한 계정 이메일 정보를 확인할 수 없습니다.');
    }

    final response = await _dio.post(
      '/auth/login',
      data: {'email': email, 'password': password},
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    if (data['role']?.toString().toUpperCase() != 'PARENT') {
      throw StateError('현재 계정의 비밀번호를 확인하지 못했습니다.');
    }
  }

  Future<AccountDeletionSchedule> getAccountDeletionStatus({
    required String email,
    String? password,
    String? googleIdToken,
  }) async {
    if ((password == null) == (googleIdToken == null)) {
      throw ArgumentError('비밀번호 또는 Google 인증 정보 중 하나가 필요합니다.');
    }
    final response = await _dio.post(
      '/auth/account-deletion/status',
      data: {
        'email': email,
        'password': ?password,
        'google_id_token': ?googleIdToken,
      },
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    if (data['status'] != 'PENDING_DELETION') {
      throw StateError('진행 중인 계정 삭제 예약이 없습니다.');
    }
    return AccountDeletionSchedule.fromJson(data);
  }

  Future<UserRole> cancelAccountDeletion({
    required String email,
    String? password,
    String? googleIdToken,
  }) async {
    if ((password == null) == (googleIdToken == null)) {
      throw ArgumentError('비밀번호 또는 Google 인증 정보 중 하나가 필요합니다.');
    }
    final response = await _dio.post(
      '/auth/account-deletion/cancel',
      data: {
        'email': email,
        'password': ?password,
        'google_id_token': ?googleIdToken,
      },
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    final user = Map<String, dynamic>.from(data['user'] as Map);
    Session.pendingTerms = _parsePendingTerms(
      data['pending_terms'] ?? user['pending_terms'],
    );
    final roleName = (data['role'] as String).toUpperCase();
    final role = switch (roleName) {
      'PARENT' => UserRole.parent,
      'ADMIN' || 'DRIVER' => UserRole.driver,
      _ => throw FormatException('지원하지 않는 사용자 역할입니다: $roleName'),
    };

    await TokenStorage.save(data['access_token'] as String);
    Session.role = role;
    Session.accountRole = roleName;
    Session.email = user['email'] as String?;
    Session.name = user['name'] as String?;
    Session.createdAt = _parseCreatedAt(user['created_at']);
    Session.signupMethod = user['signup_method'] as String? ?? 'UNKNOWN';
    await _initializePushNotifications();
    return role;
  }

  // 비밀번호 변경 (PUT /me/password)
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _dio.put(
      '/me/password',
      data: {'current_password': currentPassword, 'new_password': newPassword},
    );
  }

  // 로그인 API (/auth/login)
  Future<UserRole> login(String email, String password) async {
    final response = await _dio.post(
      '/auth/login',
      data: {'email': email, 'password': password},
    );

    final data = Map<String, dynamic>.from(response.data as Map);
    final accessToken = data['access_token'] as String;
    final roleStr = data['role'] as String;
    await TokenStorage.save(accessToken);
    final user = data['user'];
    Session.pendingTerms = _parsePendingTerms(
      data['pending_terms'] ?? (user is Map ? user['pending_terms'] : null),
    );
    Session.accountRole = roleStr.toUpperCase();
    Session.email = email;
    if (user is Map) {
      Session.email = user['email'] as String? ?? email;
      Session.name = user['name'] as String?;
      Session.createdAt = _parseCreatedAt(user['created_at']);
      Session.signupMethod = user['signup_method'] as String? ?? 'UNKNOWN';
    } else {
      Session.name = null;
      Session.createdAt = null;
      Session.signupMethod = 'UNKNOWN';
    }

    switch (roleStr.toUpperCase()) {
      case 'PARENT':
        await _initializePushNotifications();
        return UserRole.parent;
      case 'ADMIN':
      case 'DRIVER':
        await _initializePushNotifications();
        return UserRole.driver;
    }
    throw FormatException('지원하지 않는 사용자 역할입니다: $roleStr');
  }

  Future<UserRole?> restoreSession() async {
    if (await TokenStorage.read() == null) return null;

    late final Response<dynamic> response;
    try {
      response = await _dio.get('/me');
    } on DioException catch (error) {
      if (error.response?.statusCode == 401 ||
          (error.response?.statusCode == 403 && !_isTermsRequired(error))) {
        await TokenStorage.clear();
        return null;
      }
      rethrow;
    }

    final user = Map<String, dynamic>.from(response.data as Map);
    Session.pendingTerms = _parsePendingTerms(user['pending_terms']);
    final accountRole = (user['role'] as String).toUpperCase();
    final role = switch (accountRole) {
      'PARENT' => UserRole.parent,
      'ADMIN' || 'DRIVER' => UserRole.driver,
      _ => throw FormatException('지원하지 않는 사용자 역할입니다: $accountRole'),
    };

    Session.role = role;
    Session.accountRole = accountRole;
    Session.email = user['email'] as String?;
    Session.name = user['name'] as String?;
    Session.createdAt = _parseCreatedAt(user['created_at']);
    Session.signupMethod = user['signup_method'] as String? ?? 'UNKNOWN';
    await _initializePushNotifications();
    return role;
  }

  Future<UserRole> loginWithGoogle(String idToken) async {
    final response = await _dio.post(
      '/auth/google',
      data: {'id_token': idToken},
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    final accessToken = data['access_token'] as String;
    final roleStr = (data['role'] as String).toUpperCase();
    final user = Map<String, dynamic>.from(data['user'] as Map);
    Session.pendingTerms = _parsePendingTerms(
      data['pending_terms'] ?? user['pending_terms'],
    );

    final role = switch (roleStr) {
      'PARENT' => UserRole.parent,
      'ADMIN' || 'DRIVER' => UserRole.driver,
      _ => throw FormatException('지원하지 않는 사용자 역할입니다: $roleStr'),
    };

    await TokenStorage.save(accessToken);
    Session.role = role;
    Session.accountRole = roleStr;
    Session.email = user['email'] as String;
    Session.name = user['name'] as String?;
    Session.createdAt = _parseCreatedAt(user['created_at']);
    Session.signupMethod = user['signup_method'] as String? ?? 'UNKNOWN';
    await _initializePushNotifications();
    return role;
  }

  Future<void> _initializePushNotifications() => PushNotificationService
      .instance
      .initialize(registerToken: registerPushToken);

  Future<void> registerPushToken(String token) async {
    if (await TokenStorage.read() == null) return;
    await _dio.put('/me/push-token', data: {'push_token': token});
  }

  DateTime? _parseCreatedAt(Object? value) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  List<SignupTermAgreement> _parsePendingTerms(Object? value) {
    if (value == null) return const [];
    if (value is! List) {
      throw const FormatException('미동의 약관 응답 형식이 올바르지 않습니다.');
    }
    return value
        .map(
          (item) => SignupTermAgreement.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  // 버스 목록 조회 (/web/buses)
  Future<List<Map<String, dynamic>>> getBuses() async {
    final response = await _dio.get('/web/buses');
    return List<Map<String, dynamic>>.from(
      (response.data as List).map(
        (bus) => Map<String, dynamic>.from(bus as Map),
      ),
    );
  }

  bool _isTermsRequired(DioException error) {
    final data = error.response?.data;
    return error.response?.statusCode == 403 &&
        data is Map &&
        data['detail'] == 'TERMS_REQUIRED';
  }

  Future<List<Map<String, dynamic>>> getTripSchedules({
    required DateTime serviceDate,
  }) async {
    final response = await _dio.get(
      '/trip-schedules',
      queryParameters: {'service_date': _formatScheduleDate(serviceDate)},
    );
    return List<Map<String, dynamic>>.from(
      (response.data as List).map(
        (schedule) => Map<String, dynamic>.from(schedule as Map),
      ),
    );
  }

  Future<Map<String, dynamic>> saveTripSchedule({
    required int busId,
    required DateTime serviceDate,
    required String startTime,
  }) async {
    final response = await _dio.put(
      '/trip-schedules/$busId',
      data: {
        'service_date': _formatScheduleDate(serviceDate),
        'start_time': startTime,
      },
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  String _formatScheduleDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  // 학부모의 자녀 목록 조회 (/me/children)
  Future<List<ChildStudent>> getChildren({
    DateTime? date,
    bool debugLogResponse = false,
  }) async {
    final response = await _dio.get(
      '/me/children',
      queryParameters: date == null
          ? null
          : {
              'date':
                  '${date.year.toString().padLeft(4, '0')}-'
                  '${date.month.toString().padLeft(2, '0')}-'
                  '${date.day.toString().padLeft(2, '0')}',
            },
    );
    if (kDebugMode && debugLogResponse) {
      debugPrint('GET /me/children 응답: ${response.data}');
    }
    final children = (response.data as List)
        .map(
          (item) =>
              ChildStudent.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
    return children;
  }

  Future<void> confirmChildTripAttendance({
    required int tripId,
    required int studentId,
    required String eventType,
  }) async {
    if (eventType != 'BOARDING' && eventType != 'ALIGHTING') {
      throw ArgumentError.value(eventType, 'eventType');
    }
    await _dio.post(
      '/me/trips/$tripId/students/$studentId/confirmations',
      data: {'event_type': eventType},
    );
  }

  // 기사: 탑승 지도에서 '승차 완료' → 학생 승차 시각 기록 (POST /trips/{tripId}/students/{studentId}/boarded)
  Future<void> markStudentBoarded({
    required int tripId,
    required int studentId,
  }) async {
    await _dio.post('/trips/$tripId/students/$studentId/boarded');
  }

  Future<List<Map<String, dynamic>>> getMyBuses() async {
    final response = await _dio.get('/me/buses');
    return List<Map<String, dynamic>>.from(
      (response.data as List).map(
        (bus) => Map<String, dynamic>.from(bus as Map),
      ),
    );
  }

  // 학부모의 자녀가 배정된 버스 운행 현황 조회 (GET /me/bus-status)
  Future<List<Map<String, dynamic>>> getParentBusStatus({
    bool debugLogResponse = false,
  }) async {
    final response = await _dio.get('/me/bus-status');
    if (kDebugMode && debugLogResponse) {
      debugPrint('GET /me/bus-status 응답: ${response.data}');
    }

    return (response.data as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<List<ChildStudent>> getBusStudents(int busId, {DateTime? date}) async {
    final response = await _dio.get(
      '/web/buses/$busId/students',
      queryParameters: {
        if (date != null) 'date': date.toIso8601String().substring(0, 10),
      },
    );
    final students = (response.data as List)
        .map(
          (item) =>
              ChildStudent.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
    return students;
  }

  Future<List<Map<String, dynamic>>> getAttendanceCalendar({
    required int year,
    required int month,
  }) async {
    final response = await _dio.get(
      '/web/buses/attendance/calendar',
      queryParameters: {'year': year, 'month': month},
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    return (data['days'] as List)
        .map((day) => Map<String, dynamic>.from(day as Map))
        .toList();
  }

  Future<List<ChildStudent>> getTripBoardingMapStudents(int tripId) async {
    final response = await _dio.get('/trips/$tripId/boarding-map');
    final data = Map<String, dynamic>.from(response.data as Map);
    final students = data['students'] as List;
    return students
        .map(
          (item) =>
              ChildStudent.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  // 결석 여부 저장 (PUT /me/children/{studentId}/attendance)
  Future<void> setChildAttendance(
    ChildStudent child, {
    required bool isAbsent,
    required DateTime date,
  }) async {
    await _dio.put(
      '/me/children/${child.id}/attendance',
      data: {
        'date': date.toIso8601String().substring(0, 10),
        'is_absent': isAbsent,
      },
    );
  }

  // 결석 여부 조회 (GET /me/children/{studentId}/attendance)
  Future<bool> getChildAttendance(
    ChildStudent child, {
    required DateTime date,
  }) async {
    final response = await _dio.get(
      '/me/children/${child.id}/attendance',
      queryParameters: {'date': date.toIso8601String().substring(0, 10)},
    );

    final data = Map<String, dynamic>.from(response.data as Map);
    return data['is_absent'] as bool;
  }

  Future<ChildAttendance> getChildAttendanceRecord(
    ChildStudent child, {
    required DateTime date,
  }) async {
    final response = await _dio.get(
      '/me/children/${child.id}/attendance',
      queryParameters: {'date': _attendanceDateKey(date)},
    );
    final payload = Map<String, dynamic>.from(response.data as Map);
    return ChildAttendance.fromJson(payload, fallbackDate: date);
  }

  Future<List<ChildAttendance>> getChildAttendances({
    required ChildStudent child,
    required DateTime from,
    required DateTime to,
  }) async {
    final response = await _dio.get(
      '/me/children/${child.id}/attendances',
      queryParameters: {
        'from': _attendanceDateKey(from),
        'to': _attendanceDateKey(to),
      },
    );
    final payload = response.data;
    final dynamic rawItems;
    if (payload is List) {
      rawItems = payload;
    } else if (payload is Map) {
      rawItems = payload['items'] ?? payload['attendances'] ?? payload['days'];
    } else {
      throw const FormatException('출결 기록 응답 형식이 올바르지 않습니다.');
    }
    if (rawItems is! List) {
      throw const FormatException('출결 기록 응답 형식이 올바르지 않습니다.');
    }

    return rawItems
        .map(
          (item) => ChildAttendance.fromJson(
            Map<String, dynamic>.from(item as Map),
            fallbackDate: from,
          ),
        )
        .toList();
  }

  Future<int> saveChildAttendance({
    required ChildStudent child,
    required DateTime date,
    required bool isAbsent,
    String? reasonType,
    String? reasonMemo,
  }) async {
    final response = await _dio.put(
      '/me/children/${child.id}/attendance',
      data: <String, dynamic>{
        'date': _attendanceDateKey(date),
        'is_absent': isAbsent,
        if (isAbsent && reasonType != null) 'reason_type': reasonType,
        if (isAbsent && reasonMemo != null) 'reason_memo': reasonMemo,
      },
    );
    final payload = response.data;
    if (payload is! Map) {
      throw const FormatException('출결 저장 응답에 출결 ID가 없습니다.');
    }

    final rawId = payload['attendance_id'] ?? payload['id'];
    if (rawId is int) return rawId;
    if (rawId is num && rawId == rawId.toInt()) return rawId.toInt();
    if (rawId is String) {
      final parsedId = int.tryParse(rawId);
      if (parsedId != null) return parsedId;
    }
    throw const FormatException('출결 저장 응답에 출결 ID가 없습니다.');
  }

  Future<void> uploadChildAttendanceFile({
    required int attendanceId,
    required XFile file,
  }) async {
    await _dio.post(
      '/me/attendances/$attendanceId/files',
      data: FormData.fromMap({
        'file': await MultipartFile.fromFile(file.path, filename: file.name),
      }),
    );
  }

  Future<Uint8List> getChildAttendanceFile(
    ChildStudent child, {
    required int fileId,
  }) async {
    final response = await _dio.get<List<int>>(
      '/me/children/${child.id}/attendance/files/$fileId',
      options: Options(responseType: ResponseType.bytes),
    );
    final bytes = response.data;
    if (bytes == null || bytes.isEmpty) {
      throw StateError('첨부 파일을 불러오지 못했습니다.');
    }
    return Uint8List.fromList(bytes);
  }

  // 관리자: 결석 사유 첨부 파일 (GET /web/buses/attendance/files/{fileId})
  Future<Uint8List> getAdminAttendanceFile(int fileId) async {
    final response = await _dio.get<List<int>>(
      '/web/buses/attendance/files/$fileId',
      options: Options(responseType: ResponseType.bytes),
    );
    final bytes = response.data;
    if (bytes == null || bytes.isEmpty) {
      throw StateError('첨부 파일을 불러오지 못했습니다.');
    }
    return Uint8List.fromList(bytes);
  }

  String _attendanceDateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  // 운행 시작 (POST /trips)
  Future<int> startTrip(int busId, {int? scheduleId}) async {
    final response = await _dio.post(
      '/trips',
      data: {'bus_id': busId, 'schedule_id': ?scheduleId},
    );
    return response.data['id'] as int;
  }

  Future<Map<String, dynamic>?> getCurrentTrip() async {
    try {
      final response = await _dio.get('/trips/current');
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<void> cancelTrip(int tripId) async {
    await _dio.delete('/trips/$tripId');
  }

  // 승차 사진 업로드 (POST /trips/{tripId}/boarding-photo)
  Future<({int boardingCount, bool photoDark, String guidance})>
  uploadBoardingPhoto(int tripId, {XFile? image}) async {
    final selectedImage = image ?? await pickImage(source: ImageSource.camera);
    if (selectedImage == null) {
      throw StateError('분석할 사진을 선택해 주세요.');
    }

    try {
      final formData = await buildUploadFormData(
        image: selectedImage,
        fieldName: 'image',
        capturedAt: DateTime.now(),
      );

      final response = await _dio.post(
        '/trips/$tripId/boarding-photo',
        data: formData,
      );
      final payload = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : <String, dynamic>{};
      final count = payload['boarding_count'];
      return (
        boardingCount: count is num ? count.toInt() : 0,
        photoDark: payload['photo_dark'] == true,
        guidance: payload['guidance'] as String? ?? '',
      );
    } on DioException catch (e) {
      if (e.response != null) rethrow;
      debugPrint('승차 촬영 서버 연결 실패: $e');
      rethrow;
    }
  }

  // 종점(하차) 사진 업로드 (POST /trips/{tripId}/dropoff-photo)
  Future<JudgeResult> uploadDropoffPhoto(int tripId, {XFile? image}) async {
    final selectedImage = image ?? await pickImage(source: ImageSource.camera);
    if (selectedImage == null) {
      throw StateError('분석할 사진을 선택해 주세요.');
    }

    try {
      final formData = await buildUploadFormData(
        image: selectedImage,
        fieldName: 'image',
        capturedAt: DateTime.now(),
      );

      final response = await _dio.post(
        '/trips/$tripId/dropoff-photo',
        data: formData,
      );

      final payload = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : <String, dynamic>{};
      final result = JudgeResult.fromJson(
        payload,
        fallbackBoardingCount: Session.currentBoardingCount ?? 0,
      );

      return result.copyWith(
        boardingCount: Session.currentBoardingCount ?? result.boardingCount,
        remainingCount: result.remainingCount,
        imagePath: result.imagePath ?? selectedImage.path,
        imageUrl: result.imageUrl,
      );
    } on DioException catch (e) {
      if (e.response != null) rethrow;
      debugPrint('종점 촬영 서버 연결 실패: $e');
      rethrow;
    }
  }

  // 하차 확인 및 운행 종료 (POST /trips/{tripId}/confirm)
  // 기사가 차량 내부를 직접 확인한 뒤 호출하므로 safety_checked 는 항상 true.
  Future<void> confirmTrip(int tripId, {String? reason}) async {
    await _dio.post(
      '/trips/$tripId/confirm',
      data: {'method': 'button', 'safety_checked': true, 'reason': ?reason},
    );
  }

  Future<Map<String, dynamic>> getTripRecords({
    int offset = 0,
    DateTime? from,
    DateTime? to,
    bool? simulationMode,
  }) async {
    final response = await _dio.get(
      '/trips',
      queryParameters: {
        'limit': 100,
        'offset': offset,
        'from': ?from?.toIso8601String(),
        'to': ?to?.toIso8601String(),
        'simulation_mode': ?simulationMode,
      },
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> getTripRecord(int tripId) async {
    final response = await _dio.get('/trips/$tripId');
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Uint8List> getTripEventImage(int eventId) async {
    final response = await _dio.get<List<int>>(
      '/events/$eventId/image',
      options: Options(responseType: ResponseType.bytes),
    );
    final image = response.data;
    if (image == null) {
      throw StateError('사진 데이터를 받지 못했습니다.');
    }
    if (image.isEmpty) {
      throw StateError('사진 데이터를 받지 못했습니다.');
    }
    return Uint8List.fromList(image);
  }

  Future<Uint8List> getAlertEventImage(int alertId, int eventId) async {
    final response = await _dio.get<List<int>>(
      Session.role == UserRole.parent
          ? '/me/alerts/$alertId/events/$eventId/image'
          : '/alerts/$alertId/events/$eventId/image',
      options: Options(responseType: ResponseType.bytes),
    );
    final image = response.data;
    if (image == null || image.isEmpty) {
      throw StateError('사진 데이터를 받지 못했습니다.');
    }
    return Uint8List.fromList(image);
  }

  // 알림 목록 조회 (GET /me/notifications)
  Future<NotificationPage> getNotifications({String? category}) async {
    final response = await _dio.get(
      '/me/notifications',
      queryParameters: {'category': ?category},
    );
    return NotificationPage.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<int> getNotificationUnreadCount() async {
    final response = await _dio.get(
      '/me/notifications',
      queryParameters: {'unread_only': true, 'limit': 1},
    );
    final payload = Map<String, dynamic>.from(response.data as Map);
    return payload['unread_count'] as int;
  }

  Future<int> getOpenParentAlertCount() async {
    final payload = await _getParentAlertsPayload(status: 'OPEN', limit: 1);
    return payload['total'] as int;
  }

  // 알림 읽음 처리 (POST /me/notifications/{id}/read)
  Future<void> readNotification(NotificationItem notification) async {
    await _dio.post('/me/notifications/${notification.id}/read');
  }

  Future<void> readAllNotifications() async {
    await _dio.post('/me/notifications/read-all');
  }

  // 학부모 미하차 경고 목록 조회 (GET /me/alerts)
  Future<List<Map<String, dynamic>>> getParentAlerts({
    String? status,
    int limit = 20,
  }) async {
    final payload = await _getParentAlertsPayload(status: status, limit: limit);
    return (payload['items'] as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<({int total, List<Map<String, dynamic>> items})> getParentAlertsPage({
    String? status,
    int limit = 20,
  }) async {
    final payload = await _getParentAlertsPayload(status: status, limit: limit);
    final items = payload['items'] as List;

    return (
      total: payload['total'] as int,
      items: items
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList(),
    );
  }

  Future<Map<String, dynamic>> _getParentAlertsPayload({
    String? status,
    required int limit,
  }) async {
    final response = await _dio.get(
      '/me/alerts',
      queryParameters: {'limit': limit, 'status': ?status},
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> getAlertDetail(int alertId) async {
    final path = Session.role == UserRole.parent
        ? '/me/alerts/$alertId'
        : '/alerts/$alertId';
    final response = await _dio.get(path);
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> getChatGreeting() async {
    final response = await _dio.get('/chat/hello');
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> sendChatMessage({
    required String message,
    required List<Map<String, String>> history,
    int? alertId,
    CancelToken? cancelToken,
  }) async {
    final response = await _dio.post(
      '/chat',
      data: {
        'message': message,
        'history': history.length > 20
            ? history.sublist(history.length - 20)
            : history,
        'alert_id': ?alertId,
      },
      cancelToken: cancelToken,
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> askAlertGuidance({
    required int alertId,
    String? question,
  }) async {
    final response = await _dio.post(
      '/rag/ask',
      data: {
        'alert_id': alertId,
        if (question != null && question.trim().isNotEmpty)
          'question': question.trim(),
      },
      options: Options(receiveTimeout: const Duration(seconds: 30)),
    );
    return Map<String, dynamic>.from(response.data as Map);
  }
}
