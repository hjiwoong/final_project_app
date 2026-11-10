import 'package:flutter/material.dart';

import '../../core/auth/session.dart';
import '../../core/config/env.dart';
import '../../core/notifications/in_app_notification_banner.dart';
import '../../data/api/api_repository.dart';
import '../../data/models/child_student.dart';
import '../auth/child_link_request_screen.dart';
import '../auth/login_screen.dart';
import 'alert_mock_store.dart';
import 'bus_status_screen.dart';
import 'missed_dropoff_alert_screen.dart';
import 'parent_event_test_screen.dart';
import 'trip_report_screen.dart';

// 학부모 홈: 실제 API 정보와 Mock 테스트 화면 분리
class ParentHomeScreen extends StatefulWidget {
  const ParentHomeScreen({super.key});

  @override
  State<ParentHomeScreen> createState() => _ParentHomeScreenState();
}

class _ParentHomeScreenState extends State<ParentHomeScreen> {
  bool get _isMockMode => Env.useMock || Session.isMockAccount;
  late Future<List<ChildStudent>> _children;

  // 배정 버스(main: getMyBuses) + 운행 상태(parent-app: getParentBusStatus)를 합친 목록
  late Future<List<Map<String, dynamic>>> _buses;

  @override
  void initState() {
    super.initState();
    _children = ApiRepository.instance.getChildren();
    _buses = _loadBuses();
  }

  void _reloadChildren() {
    setState(() => _children = ApiRepository.instance.getChildren());
  }

  void _reloadBuses() {
    setState(() => _buses = _loadBuses());
  }

  // 배정 버스 목록을 기준으로, 차량번호가 같은 운행 상태를 붙인다.
  // 운행 상태 조회가 실패해도 배정 버스 목록은 그대로 보여준다.
  Future<List<Map<String, dynamic>>> _loadBuses() async {
    final assigned = await ApiRepository.instance.getMyBuses();

    List<Map<String, dynamic>> statuses;
    try {
      statuses = await ApiRepository.instance.getParentBusStatus();
    } catch (_) {
      statuses = <Map<String, dynamic>>[];
    }

    String plateOf(Map<String, dynamic> bus) =>
        (bus['plate_no'] ?? '').toString();

    final statusByPlate = <String, Map<String, dynamic>>{
      for (final s in statuses) plateOf(s): s,
    };

    final merged = <Map<String, dynamic>>[];

    for (final bus in assigned) {
      final status = statusByPlate.remove(plateOf(bus));
      merged.add(<String, dynamic>{
        'name': bus['name'] ?? bus['bus_name'] ?? status?['bus_name'],
        'plate_no': bus['plate_no'],
        'student_count': bus['student_count'],
        'status': status?['status'],
      });
    }

    // 배정 목록에는 없지만 운행 상태에만 있는 버스도 표시
    for (final s in statusByPlate.values) {
      merged.add(<String, dynamic>{
        'name': s['bus_name'] ?? s['name'],
        'plate_no': s['plate_no'],
        'student_count': null,
        'status': s['status'],
      });
    }

    return merged;
  }

  // ---------- 실제 자녀 상태 (main) ----------
  String _childStatus(ChildStudent child) {
    if (child.isAbsent) return '오늘 결석';
    return switch (child.busStatus) {
      'IN_PROGRESS' => '배정 버스 운행 중',
      'CLOSED' => '배정 버스 운행 완료',
      'NOT_STARTED' => '운행 전',
      'NOT_ASSIGNED' => '버스 미배정',
      _ => '운행 상태 확인 불가',
    };
  }

  Color _childStatusColor(BuildContext context, ChildStudent child) {
    if (child.isAbsent) return Theme.of(context).colorScheme.errorContainer;
    return switch (child.busStatus) {
      'IN_PROGRESS' => Theme.of(context).colorScheme.primaryContainer,
      'CLOSED' => Theme.of(context).colorScheme.tertiaryContainer,
      _ => Theme.of(context).colorScheme.surfaceContainerHighest,
    };
  }

  Widget _buildChildCard(ChildStudent child) {
    return Card(
      color: const Color(0xFFFAFAFA),
      child: ListTile(
        leading: const Icon(Icons.child_care),
        title: Text(child.name),
        subtitle: Text(
          [
            child.className ?? '학급 정보 없음',
            if (child.busName != null) child.busName!,
          ].join(' · '),
        ),
        trailing: Chip(
          label: Text(_childStatus(child)),
          backgroundColor: _childStatusColor(context, child),
        ),
      ),
    );
  }

  // ---------- 테스트용 자녀 상태 (parent-app) ----------
  Widget _buildMockChildCard({
    required String name,
    required String grade,
    required String status,
    required bool isAbsent,
    required String emoji,
  }) {
    final displayStatus = isAbsent ? '오늘 결석' : status;
    final isChecking = status == '상태 확인 중' && !isAbsent;

    final Color statusColor = isAbsent
        ? Colors.orange.shade100
        : status == '하차 완료'
        ? Colors.green.shade100
        : isChecking
        ? Colors.black26
        : Colors.blue.shade50;

    return Card(
      color: const Color(0xFFFAFAFA),
      child: ListTile(
        leading: Text(emoji, style: const TextStyle(fontSize: 28)),
        title: Text(name),
        subtitle: Text(grade),
        trailing: Chip(
          label: Text(
            displayStatus,
            style: TextStyle(
              color: isChecking ? Colors.white : Colors.black,
            ),
          ),
          backgroundColor: statusColor,
        ),
      ),
    );
  }

  // ---------- 공통 화면 조각 ----------
  String _busStatusText(Object? status) {
    return switch (status) {
      'IN_PROGRESS' => '운행 중',
      'CLOSED' => '운행 완료',
      null => '상태 정보 없음',
      _ => '운행 중 아님',
    };
  }

  // parent-app 디자인의 큰 이동 카드
  Widget _buildNavCard({
    required IconData icon,
    required Color iconColor,
    required Color accent,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
      elevation: 4,
      shadowColor: const Color(0x30000000),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: InkWell(
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color(0xFFFAFAFA), const Color(0xFFFAFAFA), accent],
              stops: const [0.0, 0.65, 1.0],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 27),
            child: Row(
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.90),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(icon, color: iconColor, size: 36),
                ),
                const SizedBox(width: 17),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF505A66),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, size: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // main: 자녀 연결 요청 카드
  Widget _buildChildLinkCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.primaryContainer,
      elevation: 0,
      child: ListTile(
        leading: Icon(Icons.family_restroom_rounded, color: scheme.primary),
        title: const Text(
          '자녀 연결 요청',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () {
          final email = Session.email;
          if (email == null || email.isEmpty) {
            InAppNotificationBanner.showMessage('로그인한 계정 정보를 확인할 수 없습니다.');
            return;
          }
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ChildLinkRequestScreen(email: email),
            ),
          );
        },
      ),
    );
  }

  // 서버에 연결된 실제 자녀 정보
  Widget _buildChildrenSection() {
    return FutureBuilder<List<ChildStudent>>(
      future: _children,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Card(
            color: const Color(0xFFFAFAFA),
            child: ListTile(
              leading: const Icon(Icons.error_outline),
              title: const Text('자녀 정보를 불러오지 못했습니다.'),
              trailing: IconButton(
                onPressed: _reloadChildren,
                icon: const Icon(Icons.refresh),
                tooltip: '다시 시도',
              ),
            ),
          );
        }

        final children = snapshot.data ?? const <ChildStudent>[];

        if (children.isEmpty) {
          return const Card(
            color: Color(0xFFFAFAFA),
            child: ListTile(
              leading: Icon(Icons.child_care),
              title: Text('연결된 자녀가 없습니다.'),
              subtitle: Text('위의 자녀 연결 요청에서 자녀를 연결하세요.'),
            ),
          );
        }

        return Column(children: children.map(_buildChildCard).toList());
      },
    );
  }

  // 실제 배정 버스 + 운행 상태
  Widget _buildBusSection() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _buses,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Card(
            child: ListTile(
              leading: const Icon(Icons.error_outline),
              title: const Text('배정된 버스 정보를 불러오지 못했습니다.'),
              trailing: IconButton(
                onPressed: _reloadBuses,
                icon: const Icon(Icons.refresh),
                tooltip: '다시 시도',
              ),
            ),
          );
        }

        final buses = snapshot.data ?? const <Map<String, dynamic>>[];

        if (buses.isEmpty) {
          return const Card(
            child: ListTile(
              leading: Icon(Icons.directions_bus_outlined),
              title: Text('자녀에게 배정된 버스가 없습니다.'),
            ),
          );
        }

        return Column(
          children: [
            for (final bus in buses)
              Card(
                color: const Color(0xFFFAFAFA),
                child: ListTile(
                  leading: const Icon(Icons.directions_bus, color: Colors.blue),
                  title: Text(bus['name']?.toString() ?? '버스'),
                  subtitle: Text(
                    [
                      '차량번호: ${bus['plate_no'] ?? '-'}',
                      if (bus['student_count'] != null)
                        '자녀 ${bus['student_count']}명 배정',
                    ].join(' · '),
                  ),
                  trailing: bus['status'] == null
                      ? null
                      : Chip(label: Text(_busStatusText(bus['status']))),
                ),
              ),
          ],
        );
      },
    );
  }

  // ---------- Mock 전용 화면 조각 (parent-app) ----------
  List<Widget> _buildMockChildrenSection(Map<String, bool> absent) {
    return [
      const SizedBox(height: 16),
      const Text(
        '테스트용 학부모 기능',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),

      // 읽지 않은 알림 개수
      ValueListenableBuilder<int>(
        valueListenable: NotificationMockStore.unreadCount,
        builder: (context, count, _) {
          return ValueListenableBuilder<List<ParentMockEvent>>(
            valueListenable: ParentEventMockStore.events,
            builder: (context, events, _) {
              return ValueListenableBuilder<Set<int>>(
                valueListenable: ParentEventMockStore.readEventIds,
                builder: (context, readIds, _) {
                  final totalCount =
                      count + ParentEventMockStore.unreadEventCount;

                  return Card(
                    child: ListTile(
                      leading: const Icon(
                        Icons.notifications,
                        color: Colors.blue,
                      ),
                      title: const Text('읽지 않은 알림'),
                      subtitle: const Text('알림 탭에서 내용을 확인할 수 있습니다.'),
                      trailing: Text(
                        '$totalCount건',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),

      const SizedBox(height: 16),

      const Text(
        '테스트용 자녀 탑승 현황',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),

      const SizedBox(height: 12),

      // 승하차 이벤트와 자녀 상태 자동 연동
      ValueListenableBuilder<Map<String, ChildBoardingStatus>>(
        valueListenable: ParentEventMockStore.childStatuses,
        builder: (context, statuses, _) {
          return Column(
            children: [
              _buildMockChildCard(
                name: '김하늘',
                grade: '1학년 2반',
                status: ParentEventMockStore.getChildStatusText(
                  statuses['김하늘'] ?? ChildBoardingStatus.waiting,
                ),
                isAbsent: absent['김하늘'] ?? false,
                emoji: '👧',
              ),
              _buildMockChildCard(
                name: '이도윤',
                grade: '3학년 1반',
                status: ParentEventMockStore.getChildStatusText(
                  statuses['이도윤'] ?? ChildBoardingStatus.waiting,
                ),
                isAbsent: absent['이도윤'] ?? false,
                emoji: '👦',
              ),
            ],
          );
        },
      ),
    ];
  }

  // 버스 운행 상태 (Mock)
  Widget _buildMockBusCard() {
    return ValueListenableBuilder<BusTripStatus>(
      valueListenable: BusTripMockStore.status,
      builder: (context, status, _) {
        return Card(
          color: const Color(0xFFFAFAFA),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.directions_bus, color: Colors.blue),
                title: const Text('1호차'),
                subtitle: const Text('차량번호: 12가3456'),
                trailing: Chip(
                  label: Text(BusTripMockStore.getStatusText(status)),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.access_time, color: Colors.blue),
                title: const Text('예상 도착 시간 (Mock)'),
                trailing: Text(BusTripMockStore.getEtaText(status)),
              ),
            ],
          ),
        );
      },
    );
  }

  // 미하차 경고 시뮬레이션 (Mock)
  Widget _buildMockAlertSection() {
    return ValueListenableBuilder<bool>(
      valueListenable: AlertMockStore.hasAlert,
      builder: (context, hasAlert, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '안전 상태 안내',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            Card(
              color: hasAlert ? Colors.red.shade50 : const Color(0xFFFFF3E0),
              child: ListTile(
                leading: Icon(
                  hasAlert ? Icons.warning_amber_rounded : Icons.info_outline,
                  color: hasAlert ? Colors.red : Colors.orange,
                ),
                title: Text(hasAlert ? '미하차 의심 경고 (테스트)' : '안전 상태 확인 안내'),
                subtitle: Text(
                  hasAlert
                      ? '1호차 내부에 어린이 1명이 남아 있는 상황을 '
                            '가정한 Mock 경고입니다. 관리자 확인이 필요합니다.'
                      : '현재 표시되는 운행 및 안전 정보는 테스트 데이터입니다. '
                            '실제 미하차 감지 결과는 아직 연결되지 않았습니다.',
                ),
              ),
            ),

            const SizedBox(height: 12),

            ElevatedButton.icon(
              onPressed: AlertMockStore.triggerAlert,
              icon: const Icon(Icons.warning_amber_rounded),
              label: const Text('미하차 경고 발생 테스트'),
            ),

            const SizedBox(height: 8),

            OutlinedButton(
              onPressed: AlertMockStore.resetAlert,
              child: const Text('테스트 경고 초기화'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        automaticallyImplyLeading: false,
        title: const Text('학부모 홈'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: '로그아웃',
            onPressed: () async {
              final shouldLogout = await showLogoutConfirmationDialog(context);
              if (!shouldLogout || !context.mounted) return;
              await Session.clear();
              if (!context.mounted) return;
              Navigator.of(context, rootNavigator: true).pushReplacement(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: ValueListenableBuilder<Map<String, bool>>(
        valueListenable: AttendanceMockStore.absent,
        builder: (context, absent, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildChildLinkCard(context),

              const SizedBox(height: 16),

              const Text(
                '오늘의 자녀 탑승 현황',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 8),

              _buildChildrenSection(),

              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '버스 운행 상태를 표시합니다. 학생 개인별 승차 여부는 확인되지 않습니다.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ),

              if (_isMockMode) ..._buildMockChildrenSection(absent),

              const SizedBox(height: 24),

              const Text(
                '버스 운행 정보',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 8),

              if (_isMockMode) _buildMockBusCard() else _buildBusSection(),

              const SizedBox(height: 24),

              _buildNavCard(
                icon: Icons.directions_bus,
                iconColor: const Color(0xFFFF8A00),
                accent: const Color(0xFFFFF8E6),
                title: '버스 운행 현황',
                subtitle: '차량 위치 및 운행 상태 확인',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const BusStatusScreen()),
                ),
              ),

              const SizedBox(height: 12),

              _buildNavCard(
                icon: Icons.warning_amber_rounded,
                iconColor: const Color(0xFFE05252),
                accent: const Color(0xFFFFEEEE),
                title: '미하차 안전 알림',
                subtitle: '미하차 의심 경고 및 안전 상태 확인',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const MissedDropoffAlertScreen(),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              _buildNavCard(
                icon: Icons.bar_chart_rounded,
                iconColor: const Color(0xFF25865A),
                accent: const Color(0xFFEAF7F0),
                title: '운행 리포트',
                subtitle: '운행 기록 및 안전 정보 확인',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const TripReportScreen()),
                ),
              ),

              if (_isMockMode) ...[
                const SizedBox(height: 24),

                _buildMockAlertSection(),

                const SizedBox(height: 12),

                // 승하차 및 안전 이벤트 테스트 화면
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ParentEventTestScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.fact_check),
                  label: const Text('승하차 · 안전 이벤트 테스트'),
                ),

                const SizedBox(height: 12),

                const Text(
                  '※ 현재 자녀 상태와 차량 정보는 Mock 데이터입니다.',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],

              const SizedBox(height: 16),
            ],
          );
        },
      ),
    );
  }
}