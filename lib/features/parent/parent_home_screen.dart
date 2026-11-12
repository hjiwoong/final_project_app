import 'package:flutter/material.dart';

import '../../core/auth/session.dart';
import '../../core/notifications/in_app_notification_banner.dart';
import '../../data/api/api_repository.dart';
import '../../data/models/child_student.dart';
import '../../widgets/logout_confirmation_dialog.dart';
import '../auth/child_link_request_screen.dart';
import '../auth/login_screen.dart';
import 'bus_status_screen.dart';
import 'missed_dropoff_alert_screen.dart';
import 'trip_report_screen.dart';

// 학부모 홈: 자녀 연결 · 자녀 탑승 현황 · 배정 버스 · 바로가기
Color _homeCardColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? Theme.of(context).colorScheme.surfaceContainerHigh
    : const Color(0xFFFAFAFA);

class ParentHomeScreen extends StatefulWidget {
  const ParentHomeScreen({super.key});

  @override
  State<ParentHomeScreen> createState() => _ParentHomeScreenState();
}

class _ParentHomeScreenState extends State<ParentHomeScreen> {
  late Future<List<ChildStudent>> _children;

  // 배정 버스(getMyBuses) + 운행 상태(getParentBusStatus)를 합친 목록
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

  // ---------- 자녀 상태 ----------
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
      color: _homeCardColor(context),
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

  // ---------- 공통 화면 조각 ----------
  String _busStatusText(Object? status) {
    return switch (status) {
      'IN_PROGRESS' => '운행 중',
      'CLOSED' => '운행 완료',
      null => '상태 정보 없음',
      _ => '운행 중 아님',
    };
  }

  // 큰 이동 카드
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
      shadowColor: Theme.of(context).brightness == Brightness.dark
          ? Colors.transparent
          : const Color(0x30000000),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: InkWell(
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _homeCardColor(context),
                _homeCardColor(context),
                Theme.of(context).brightness == Brightness.dark
                    ? accent.withValues(alpha: 0.18)
                    : accent,
              ],
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
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.white.withValues(alpha: 0.90),
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
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
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

  // 자녀 연결 요청 카드
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
            color: _homeCardColor(context),
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
          return Card(
            color: _homeCardColor(context),
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
                color: _homeCardColor(context),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
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
      body: RefreshIndicator(
        onRefresh: () async {
          _reloadChildren();
          _reloadBuses();
          try {
            await Future.wait<Object?>([_children, _buses]);
          } catch (_) {
            // 각 섹션의 FutureBuilder 가 오류 상태를 표시합니다.
          }
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
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

            const SizedBox(height: 24),

            const Text(
              '버스 운행 정보',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            _buildBusSection(),

            const SizedBox(height: 24),

            _buildNavCard(
              icon: Icons.directions_bus,
              iconColor: const Color(0xFFFF8A00),
              accent: const Color(0xFFFFF8E6),
              title: '버스 운행 현황',
              subtitle: '배정 버스 운행 단계와 탑승 예정 자녀 확인',
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

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}