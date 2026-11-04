import 'package:flutter/material.dart';

import '../../core/auth/session.dart';
import '../auth/login_screen.dart';
import '../../data/api/api_repository.dart';
import '../../data/models/child_student.dart';
import '../../widgets/logout_confirmation_dialog.dart';
import 'attendance_mock_store.dart';
import 'bus_status_screen.dart';
import 'trip_report_screen.dart';
import 'notification_mock_store.dart';
import 'alert_mock_store.dart';
import 'bus_trip_mock_store.dart';
import 'parent_event_mock_store.dart';
import 'parent_event_test_screen.dart';
import '../../core/config/env.dart';

// 학부모 홈: 실제 API 정보와 Mock 테스트 화면 분리
class ParentHomeScreen extends StatefulWidget {
  const ParentHomeScreen({super.key});

  @override
  State<ParentHomeScreen> createState() => _ParentHomeScreenState();
}

class _ParentHomeScreenState extends State<ParentHomeScreen> {
  bool get _isMockMode => Env.useMock || Session.isMockAccount;
  late Future<List<ChildStudent>> _children;
  late Future<List<Map<String, dynamic>>> _busStatusFuture;


  @override
  void initState() {
    super.initState();
    _children = ApiRepository.instance.getChildren();
    _busStatusFuture = ApiRepository.instance.getParentBusStatus();
  }

  void _reloadChildren() {
    setState(() => _children = ApiRepository.instance.getChildren());
  }

  void _reloadBusStatus() {
    setState(() {
      _busStatusFuture = ApiRepository.instance.getParentBusStatus();
    });
  }

  Widget _buildChildCard({
    required String name,
    required String grade,
    required String status,
    required bool isAbsent,
    required String emoji,
  }) {
    final displayStatus = isAbsent ? '오늘 결석' : status;

    final statusColor = isAbsent
        ? Colors.orange.shade100
        : status == '하차 완료'
        ? Colors.green.shade100
        : status == '상태 확인 중'
        ? Colors.black26
        : Colors.black;

    return Card(
      color: const Color(0xFFFAFAFA),
      child: ListTile(
        leading: Text(
          emoji,
          style: const TextStyle(fontSize: 28),
        ),
        title: Text(name),
        subtitle: Text(grade),
        trailing: Chip(
          label: Text(
            displayStatus,
            style: TextStyle(
              color: status == '상태 확인 중' && !isAbsent
                  ? Colors.white
                  : Colors.black,
            ),
          ),
          backgroundColor: statusColor,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('학부모 홈'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
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
        builder: (context, absent, child) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 서버에 연결된 실제 자녀 정보
              const SizedBox(height: 12),
              const Text('오늘의 자녀 탑승 현황', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),

              FutureBuilder<List<ChildStudent>>(
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
                        ),
                      ),
                    );
                  }

                  final children = snapshot.data ?? [];

                  if (children.isEmpty) {
                    return const Card(
                      color: Color(0xFFFAFAFA),
                      child: ListTile(
                        leading: Icon(Icons.child_care),
                        title: Text('연결된 자녀가 없습니다.'),
                      ),
                    );
                  }

                  return Column(
                    children: children.map((child) {
                      return _buildChildCard(
                        name: child.name,
                        grade: child.className ?? '학급 정보 없음',
                        status: '상태 확인 중',
                        isAbsent: false,
                        emoji: '👧',
                      );
                    }).toList(),
                  );
                },
              ),

              if (_isMockMode) ...[
                const SizedBox(height: 16),
                const Text('테스트용 학부모 기능', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                // 읽지 않은 알림 개수
                ValueListenableBuilder<int>(
                  valueListenable: NotificationMockStore.unreadCount,
                  builder: (context, count, child) {
                    return ValueListenableBuilder<List<ParentMockEvent>>(
                      valueListenable: ParentEventMockStore.events,
                      builder: (context, events, child) {
                        return ValueListenableBuilder<Set<int>>(
                          valueListenable:
                          ParentEventMockStore.readEventIds,
                          builder: (context, readIds, child) {
                            final eventUnreadCount =
                                ParentEventMockStore.unreadEventCount;

                            final totalCount =
                                count + eventUnreadCount;

                            return Card(
                              child: ListTile(
                                leading: const Icon(
                                  Icons.notifications,
                                  color: Colors.blue,
                                ),
                                title: const Text('읽지 않은 알림'),
                                subtitle: const Text(
                                  '알림 탭에서 내용을 확인할 수 있습니다.',
                                ),
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
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                // 승하차 이벤트와 자녀 상태 자동 연동
                ValueListenableBuilder<
                    Map<String, ChildBoardingStatus>>(
                  valueListenable:
                  ParentEventMockStore.childStatuses,
                  builder: (context, statuses, child) {
                    return Column(
                      children: [
                        _buildChildCard(
                          name: '김하늘',
                          grade: '1학년 2반',
                          status:
                          ParentEventMockStore.getChildStatusText(
                            statuses['김하늘'] ??
                                ChildBoardingStatus.waiting,
                          ),
                          isAbsent: absent['김하늘'] ?? false,
                          emoji: '👧',
                        ),

                        _buildChildCard(
                          name: '이도윤',
                          grade: '3학년 1반',
                          status:
                          ParentEventMockStore.getChildStatusText(
                            statuses['이도윤'] ??
                                ChildBoardingStatus.waiting,
                          ),
                          isAbsent: absent['이도윤'] ?? false,
                          emoji: '👦',
                        ),
                      ],
                    );
                  },
                ),

              ],

              const SizedBox(height: 24),

              const Text(
                '버스 운행 정보',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              // 버스 운행 상태 (Mock)

              if (_isMockMode)
                ValueListenableBuilder<BusTripStatus>(
                  valueListenable: BusTripMockStore.status,
                  builder: (context, status, child) {
                    return Card(
                      color: const Color(0xFFFAFAFA),
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Icon(
                              Icons.directions_bus,
                              color: Colors.blue,
                            ),
                            title: const Text('1호차'),
                            subtitle: const Text('차량번호: 12가3456'),
                            trailing: Chip(
                              label: Text(BusTripMockStore.getStatusText(status)),
                            ),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(
                              Icons.access_time,
                              color: Colors.blue,
                            ),
                            title: const Text('예상 도착 시간 (Mock)'),
                            trailing: Text(BusTripMockStore.getEtaText(status)),
                          ),
                        ],
                      ),
                    );
                  },
                )
              else
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _busStatusFuture,
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
                          title: const Text('버스 정보를 불러오지 못했습니다.'),
                          trailing: IconButton(
                            onPressed: _reloadBusStatus,
                            icon: const Icon(Icons.refresh),
                          ),
                        ),
                      );
                    }

                    final buses = snapshot.data ?? [];

                    if (buses.isEmpty) {
                      return const Card(
                        child: ListTile(
                          leading: Icon(Icons.directions_bus),
                          title: Text('배정된 버스가 없습니다.'),
                        ),
                      );
                    }

                    return Column(
                      children: buses.map((bus) {
                        final isRunning = bus['status'] == 'IN_PROGRESS';

                        return Card(
                          color: const Color(0xFFFAFAFA),
                          child: ListTile(
                            leading: const Icon(
                              Icons.directions_bus,
                              color: Colors.blue,
                            ),
                            title: Text(
                              bus['bus_name']?.toString() ?? '버스',
                            ),
                            subtitle: Text(
                              '차량번호: ${bus['plate_no'] ?? '-'}',
                            ),
                            trailing: Chip(
                              label: Text(
                                isRunning ? '운행 중' : '운행 중 아님',
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),


              const SizedBox(height: 24),

              Card(
                margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
                elevation: 4,
                shadowColor: const Color(0x30000000),
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const BusStatusScreen()),
                    );
                  },
                  child: Ink(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFFAFAFA), Color(0xFFFAFAFA), Color(0xFFFFF8E6)],
                        stops: [0.0, 0.65, 1.0],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 27,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.90),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: const Icon(
                              Icons.directions_bus,
                              color: Color(0xFFFF8A00),
                              size: 36,
                            ),
                          ),
                          const SizedBox(width: 17),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '버스 운행 현황',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 7),
                                Text(
                                  '차량 위치 및 운행 상태 확인',
                                  style: TextStyle(
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
              ),
              // 미하차 경고 시뮬레이션 (Mock)
              if (_isMockMode)
                ValueListenableBuilder<bool>(
                  valueListenable: AlertMockStore.hasAlert,
                  builder: (context, hasAlert, child) {
                    return Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          '안전 상태 안내',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 8),

                        Card(
                          color: hasAlert
                              ? Colors.red.shade50
                              : const Color(0xFFFFF3E0),
                          child: ListTile(
                            leading: Icon(
                              hasAlert
                                  ? Icons.warning_amber_rounded
                                  : Icons.info_outline,
                              color: hasAlert
                                  ? Colors.red
                                  : Colors.orange,
                            ),
                            title: Text(
                              hasAlert
                                  ? '미하차 의심 경고 (테스트)'
                                  : '안전 상태 확인 안내',
                            ),
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
                          icon: const Icon(
                            Icons.warning_amber_rounded,
                          ),
                          label:
                          const Text('미하차 경고 발생 테스트'),
                        ),

                        const SizedBox(height: 8),

                        OutlinedButton(
                          onPressed: AlertMockStore.resetAlert,
                          child: const Text('테스트 경고 초기화'),
                        ),
                      ],
                    );
                  },
                ),

              const SizedBox(height: 24),

              // 승하차 및 안전 이벤트 테스트 화면
              if (_isMockMode)
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                        const ParentEventTestScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.fact_check),
                  label:
                  const Text('승하차 · 안전 이벤트 테스트'),
                ),

              const SizedBox(height: 12),

              Card(
                margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
                elevation: 4,
                shadowColor: const Color(0x30000000),
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const TripReportScreen()),
                    );
                  },
                  child: Ink(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFFAFAFA), Color(0xFFFAFAFA), Color(0xFFEAF7F0)],
                        stops: [0.0, 0.65, 1.0],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 27,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.90),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: const Icon(
                              Icons.bar_chart_rounded,
                              color: Color(0xFF25865A),
                              size: 36,
                            ),
                          ),
                          const SizedBox(width: 17),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '운행 리포트',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 7),
                                Text(
                                  '운행 기록 및 안전 정보 확인',
                                  style: TextStyle(
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
              ),

              const SizedBox(height: 16),

              if (_isMockMode)
                const Text(
                  '※ 현재 자녀 상태와 차량 정보는 Mock 데이터입니다.',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
