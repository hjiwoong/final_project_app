import 'package:flutter/material.dart';

import '../../core/auth/session.dart';
import '../auth/child_link_request_screen.dart';
import '../../data/api/api_repository.dart';
import '../../data/models/child_student.dart';
import 'alert_mock_store.dart';
import 'bus_status_screen.dart';
import 'parent_event_test_screen.dart';
import 'trip_report_screen.dart';

// 학부모 홈
class ParentHomeScreen extends StatefulWidget {
  const ParentHomeScreen({super.key});

  @override
  State<ParentHomeScreen> createState() => _ParentHomeScreenState();
}

class _ParentHomeScreenState extends State<ParentHomeScreen> {
  late Future<List<ChildStudent>> _children;
  late Future<List<Map<String, dynamic>>> _buses;

  @override
  void initState() {
    super.initState();
    _children = ApiRepository.instance.getChildren();
    _buses = ApiRepository.instance.getMyBuses();
  }

  void _reloadChildren() {
    setState(() => _children = ApiRepository.instance.getChildren());
  }

  void _reloadBuses() {
    setState(() => _buses = ApiRepository.instance.getMyBuses());
  }

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

  Color _childStatusColor(ChildStudent child) {
    if (child.isAbsent) return Colors.orange.shade100;
    return switch (child.busStatus) {
      'IN_PROGRESS' => Colors.blue.shade100,
      'CLOSED' => Colors.green.shade100,
      _ => Colors.grey.shade200,
    };
  }

  Widget _buildChildCard(ChildStudent child) {
    return Card(
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
          backgroundColor: _childStatusColor(child),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        //학부모 홈
        automaticallyImplyLeading: false,
        title: const Text('홈'),
      ),
      body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 서버에 연결된 실제 자녀 정보
              Card(
                color: const Color(0xFFF1F6FF),
                elevation: 0,
                child: ListTile(
                  leading: const Icon(
                    Icons.family_restroom_rounded,
                    color: Color(0xFF3B82F6),
                  ),
                  title: const Text(
                    '자녀 연결 요청',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  // subtitle: const Text(''),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    final email = Session.email;
                    if (email == null || email.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('로그인한 계정 정보를 확인할 수 없습니다.'),
                        ),
                      );
                      return;
                    }
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ChildLinkRequestScreen(email: email),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '서버에 연결된 자녀',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
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
                  return Column(
                    children: snapshot.data!
                        .map(
                          (child) => Card(
                            child: ListTile(
                              leading: const Icon(Icons.child_care),
                              title: Text(child.name),
                              subtitle: Text(child.className ?? '학급 정보 없음'),
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: 16),

              const Text(
                '오늘의 자녀 탑승 현황',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 12),

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
                      child: ListTile(
                        leading: const Icon(Icons.error_outline),
                        title: const Text('오늘의 자녀 운행 현황을 불러오지 못했습니다.'),
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
                      child: ListTile(title: Text('연결된 자녀가 없습니다.')),
                    );
                  }
                  return Column(
                    children: children.map(_buildChildCard).toList(),
                  );
                },
              ),
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  '버스 운행 상태를 표시합니다. 학생 개인별 승차 여부는 확인되지 않습니다.',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                '버스 운행 정보',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 8),

              FutureBuilder<List<Map<String, dynamic>>>(
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
                  final buses = snapshot.data ?? const [];
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
                          child: ListTile(
                            leading: const Icon(
                              Icons.directions_bus,
                              color: Colors.blue,
                            ),
                            title: Text(bus['name'] as String),
                            subtitle: Text(
                              '차량번호: ${bus['plate_no']} · 자녀 ${bus['student_count']}명 배정',
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 24),

              // 미하차 경고 시뮬레이션 (Mock)
              ValueListenableBuilder<bool>(
                valueListenable: AlertMockStore.hasAlert,
                builder: (context, hasAlert, child) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
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
                            color: hasAlert ? Colors.red : Colors.orange,
                          ),
                          title: Text(
                            hasAlert ? '미하차 의심 경고 (테스트)' : '안전 상태 확인 안내',
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
              ),

              const SizedBox(height: 24),

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

              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const BusStatusScreen()),
                  );
                },
                icon: const Icon(Icons.directions_bus),
                label: const Text('버스 운행 현황'),
              ),

              const SizedBox(height: 12),

              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const TripReportScreen()),
                  );
                },
                icon: const Icon(Icons.assessment),
                label: const Text('운행 리포트'),
              ),

              const SizedBox(height: 16),

            ],
          ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: const SizedBox.shrink(),
        ),
      ),
    );
  }
}
