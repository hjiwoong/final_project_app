import '../models/child_student.dart';
import '../models/child_link_request.dart';
import '../models/child_location.dart';
import '../models/judge_result.dart';
import '../models/user_role.dart';

/// API 응답이 비어 있거나 서버를 사용할 수 없을 때 보여주는 목업 데이터.
class MockRepository {
  MockRepository._();
  static final MockRepository instance = MockRepository._();

  int boardingCount = 0;
  final Map<int, ChildLocation> _childLocations = {};
  final List<ChildStudent> _mockChildren = [
    ChildStudent(id: -1, name: '김하늘', className: '1학년 2반', isMock: true),
    ChildStudent(id: -2, name: '이도윤', className: '3학년 1반', isMock: true),
  ];
  final Map<int, bool> _mockAbsences = {};
  int _nextChildRequestId = 1;
  final List<ChildLinkRequest> _childRequests = [];

  List<ChildStudent> get children => _mockChildren
      .map(
        (child) => ChildStudent(
          id: child.id,
          name: child.name,
          className: child.className,
          isAbsent: _mockAbsences[child.id] ?? child.isAbsent,
          isMock: true,
          location: _childLocations[child.id],
        ),
      )
      .toList();

  List<ChildLinkRequest> get childRequests => List.unmodifiable(_childRequests);

  ChildLocation childLocation(int childId) =>
      _childLocations[childId] ?? const ChildLocation();

  void setChildLocation(int childId, ChildLocation location) {
    _childLocations[childId] = location;
  }

  void clearChildLocation(int childId) {
    _childLocations.remove(childId);
  }

  List<AddressCandidate> searchAddress(String query) {
    const samples = [
      AddressCandidate(
        name: '광운대학교',
        address: '서울특별시 노원구 광운로 20',
        latitude: 37.6199,
        longitude: 127.0577,
      ),
      AddressCandidate(
        address: '서울특별시 중구 세종대로 110',
        roadAddress: '서울특별시 중구 세종대로 110',
        jibunAddress: '서울특별시 중구 태평로1가 31',
        latitude: 37.5663174,
        longitude: 126.9779692,
      ),
      AddressCandidate(
        address: '서울특별시 종로구 세종대로 175',
        roadAddress: '서울특별시 종로구 세종대로 175',
        jibunAddress: '서울특별시 종로구 세종로 1-68',
        latitude: 37.5724,
        longitude: 126.9769,
      ),
    ];
    final normalized = query.replaceAll(' ', '');
    return samples
        .where(
          (item) =>
              (item.name ?? '').replaceAll(' ', '').contains(normalized) ||
              item.address.replaceAll(' ', '').contains(normalized) ||
              normalized.contains('세종') ||
              normalized.contains('서울'),
        )
        .toList();
  }

  Future<void> addChildRequest({
    required String name,
    required String className,
    required String relation,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));
    _childRequests.insert(
      0,
      ChildLinkRequest(
        id: _nextChildRequestId++,
        childName: name,
        className: className,
        relation: relation,
        status: 'PENDING',
        createdAt: DateTime.now(),
      ),
    );
  }

  void cancelChildRequest(int requestId) {
    final requestIndex = _childRequests.indexWhere(
      (request) => request.id == requestId,
    );
    if (requestIndex == -1) {
      throw StateError('연결 요청을 찾을 수 없습니다.');
    }
    if (_childRequests[requestIndex].status != 'PENDING') {
      throw StateError('이미 처리된 요청은 취소할 수 없습니다.');
    }
    _childRequests.removeAt(requestIndex);
  }

  void unlinkChild(int studentId) {
    _mockChildren.removeWhere((child) => child.id == studentId);
    _mockAbsences.remove(studentId);
  }

  void setMockAttendance(int studentId, bool isAbsent) {
    _mockAbsences[studentId] = isAbsent;
  }

  int _nextSignupRequestId = 1;
  final List<MockSignupRequest> signupRequests = [];

  /// 회원가입과 자녀 연결 요청을 메모리에만 접수하는 실험용 목업
  Future<MockSignupRequest> signup({
    required String name,
    required String email,
    required List<MockChildLinkRequest> children,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));

    final request = MockSignupRequest(
      id: _nextSignupRequestId++,
      name: name,
      email: email,
      children: List.unmodifiable(children),
      status: 'pending',
      createdAt: DateTime.now(),
    );
    signupRequests.add(request);
    return request;
  }

  /// Adds child-link requests to an existing mock signup.
  Future<void> addChildLinks({
    required String email,
    required List<MockChildLinkRequest> children,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));

    final requestIndex = signupRequests.lastIndexWhere(
      (request) => request.email.toLowerCase() == email.toLowerCase(),
    );
    if (requestIndex == -1) {
      throw StateError('해당 이메일의 가입 정보를 찾을 수 없습니다.');
    }

    final request = signupRequests[requestIndex];
    signupRequests[requestIndex] = request.copyWith(
      children: [...request.children, ...children],
    );
  }

  /// 이메일에 'parent' 가 들어가면 학부모, 아니면 관리자(기사)
  Future<UserRole> login(String email, String password) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return email.contains('parent') ? UserRole.parent : UserRole.driver;
  }

  /// 승차 사진 → YOLO 카운트 (mock: 5명)
  Future<int> uploadBoardingPhoto() async {
    await Future.delayed(const Duration(seconds: 1));
    boardingCount = 5;
    return boardingCount;
  }

  /// 종점 사진 → 잔류 카운트 → 판정
  /// oneRemaining=true 이면 '한 명 남음' 시나리오
  Future<JudgeResult> uploadDropoffPhoto({required bool oneRemaining}) async {
    await Future.delayed(const Duration(seconds: 1));
    return JudgeResult(
      boardingCount: boardingCount,
      remainingCount: oneRemaining ? 1 : 0,
    );
  }
}

class MockSignupRequest {
  const MockSignupRequest({
    required this.id,
    required this.name,
    required this.email,
    required this.children,
    required this.status,
    required this.createdAt,
  });

  final int id;
  final String name;
  final String email;
  final List<MockChildLinkRequest> children;
  final String status;
  final DateTime createdAt;

  MockSignupRequest copyWith({List<MockChildLinkRequest>? children}) =>
      MockSignupRequest(
        id: id,
        name: name,
        email: email,
        children: children ?? this.children,
        status: status,
        createdAt: createdAt,
      );
}

class MockChildLinkRequest {
  const MockChildLinkRequest({
    required this.name,
    required this.className,
    required this.relation,
  });

  final String name;
  final String className;
  final String relation;
}
