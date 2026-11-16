import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/auth/session.dart';
import '../../core/errors/app_error_message.dart';
import '../../core/notifications/in_app_notification_banner.dart';
import '../../core/theme/app_theme.dart';
import '../../data/api/api_repository.dart';
import '../../data/models/child_student.dart';
import '../../widgets/logout_confirmation_dialog.dart';
import '../auth/child_link_request_screen.dart';
import '../auth/login_screen.dart';
import 'bus_status_screen.dart';
import 'bus_trip_simulation.dart';
import 'missed_dropoff_alert_screen.dart';

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

class _ParentHomeScreenState extends State<ParentHomeScreen>
    with WidgetsBindingObserver {
  late Future<List<ChildStudent>> _children;
  final Set<int> _confirmingChildren = {};
  late DateTime _loadedDate;
  Timer? _midnightRefresh;

  // 배정 버스(getMyBuses) + 운행 상태(getParentBusStatus)를 합친 목록
  late Future<List<Map<String, dynamic>>> _buses;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadedDate = _dateOnly(DateTime.now());
    _children = ApiRepository.instance.getChildren(date: _loadedDate);
    _buses = _loadBuses();
    _scheduleMidnightRefresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _midnightRefresh?.cancel();
    super.dispose();
  }

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  void _refreshDailyData() {
    final today = _dateOnly(DateTime.now());
    setState(() {
      _loadedDate = today;
      _children = ApiRepository.instance.getChildren(date: today);
      _buses = _loadBuses();
    });
  }

  void _scheduleMidnightRefresh() {
    _midnightRefresh?.cancel();
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    _midnightRefresh = Timer(midnight.difference(now), () {
      if (!mounted) return;
      _refreshDailyData();
      _scheduleMidnightRefresh();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (_dateOnly(DateTime.now()) != _loadedDate) {
      _refreshDailyData();
    }
    _scheduleMidnightRefresh();
  }

  void _reloadChildren() {
    final today = _dateOnly(DateTime.now());
    setState(() {
      _loadedDate = today;
      _children = ApiRepository.instance.getChildren(date: today);
    });
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
    final canConfirm =
        child.busStatus == 'IN_PROGRESS' &&
        child.tripId != null &&
        !child.isAbsent;
    final showAttendance = child.tripId != null && !child.isAbsent;
    return Card(
      color: _homeCardColor(context),
      child: Column(
        children: [
          ListTile(
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
          if (showAttendance)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      child.alightingConfirmedAt != null
                          ? '승차·하차 확인 완료'
                          : child.boardingConfirmedAt != null
                          ? canConfirm
                                ? '승차 확인 완료 · 하차 확인 대기'
                                : '승차 확인 완료 · 하차 미확인'
                          : canConfirm
                          ? '승차 확인 대기'
                          : '승·하차 확인 기록 없음',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  if (canConfirm && child.alightingConfirmedAt == null)
                    FilledButton.tonal(
                      onPressed: _confirmingChildren.contains(child.id)
                          ? null
                          : () => _requestChildAttendanceConfirmation(
                              child,
                              eventType: child.boardingConfirmedAt == null
                                  ? 'BOARDING'
                                  : 'ALIGHTING',
                            ),
                      child: Text(
                        _confirmingChildren.contains(child.id)
                            ? '처리 중'
                            : child.boardingConfirmedAt == null
                            ? '승차 완료'
                            : '하차 완료',
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _requestChildAttendanceConfirmation(
    ChildStudent child, {
    required String eventType,
  }) async {
    final isBoarding = eventType == 'BOARDING';
    final action = isBoarding ? '승차' : '하차';
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        top: false,
        child: Container(
          margin: AppTheme.sheetMargin,
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
          decoration: AppTheme.sheetDecoration(context),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isBoarding
                        ? Icons.directions_bus_rounded
                        : Icons.exit_to_app_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '$action 완료를 확인할까요?',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                '${child.name} 학생의 ${child.busName ?? '배정 버스'} $action 여부를 '
                '완료로 기록합니다.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '완료를 누르면 운행 기록에 저장되며 직접 취소할 수 없습니다. '
                '실제 $action을 마친 경우에만 확인해 주세요.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('취소'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: Text('$action 완료 확인'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    await _confirmChildAttendance(child, eventType: eventType);
  }

  Future<void> _confirmChildAttendance(
    ChildStudent child, {
    required String eventType,
  }) async {
    final tripId = child.tripId;
    if (tripId == null || _confirmingChildren.contains(child.id)) return;
    setState(() => _confirmingChildren.add(child.id));
    try {
      await ApiRepository.instance.confirmChildTripAttendance(
        tripId: tripId,
        studentId: child.id,
        eventType: eventType,
      );
      if (!mounted) return;
      _reloadChildren();
      await _children;
      if (!mounted) return;
      InAppNotificationBanner.showMessage(
        eventType == 'BOARDING' ? '승차 확인을 완료했습니다.' : '하차 확인을 완료했습니다.',
      );
    } catch (e) {
      if (!mounted) return;
      InAppNotificationBanner.showMessage(
        AppErrorMessage.from(e, fallback: '승·하차 확인을 저장하지 못했습니다. 다시 시도해 주세요.'),
      );
    } finally {
      if (mounted) setState(() => _confirmingChildren.remove(child.id));
    }
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
  // 테스트 운행(버스 위치 시뮬레이션) 요약 카드 → 버스 운행 현황으로 이동
  Widget _buildTestRunCard() {
    return ValueListenableBuilder<BusTripStatus>(
      valueListenable: BusTripSimulation.status,
      builder: (context, status, _) {
        return ValueListenableBuilder<double>(
          valueListenable: BusTripSimulation.progress,
          builder: (context, _, _) {
            return Card(
              color: _homeCardColor(context),
              child: ListTile(
                leading: const Icon(Icons.route, color: Colors.blue),
                title: const Text('버스 위치 (테스트 운행)'),
                subtitle: Text(
                  '${BusTripSimulation.statusText(status)} · '
                  '도착 예정 ${BusTripSimulation.etaText(status)}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const BusStatusScreen()),
                ),
              ),
            );
          },
        );
      },
    );
  }

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
                '현재 운행 중인 자녀의 승차와 하차를 확인 처리할 수 있습니다.',
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

            _buildTestRunCard(),

            const SizedBox(height: 24),

            _buildNavCard(
              icon: Icons.directions_bus,
              iconColor: const Color(0xFFFF8A00),
              accent: const Color(0xFFFFF8E6),
              title: '버스 운행 현황',
              subtitle: '버스 위치(테스트 운행)와 실제 운행 상태 확인',
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

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
