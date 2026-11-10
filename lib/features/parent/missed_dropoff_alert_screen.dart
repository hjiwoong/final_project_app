
import 'package:flutter/material.dart';

import '../../core/auth/session.dart';
import '../../core/config/env.dart';
import 'alert_mock_store.dart';
import '../../data/api/api_repository.dart';
import 'alert_detail_screen.dart';

// 학부모 미하차 경고 내역 화면
// Mock 계정은 테스트 경고를, 실제 계정은 API 경고 내역을 표시합니다.
class MissedDropoffAlertScreen extends StatefulWidget {
  const MissedDropoffAlertScreen({super.key});

  @override
  State<MissedDropoffAlertScreen> createState() =>
      _MissedDropoffAlertScreenState();
}

class _MissedDropoffAlertScreenState
    extends State<MissedDropoffAlertScreen> {
  bool get _isMockMode => Env.useMock || Session.isMockAccount;

  late Future<List<Map<String, dynamic>>> _alertsFuture;

  @override
  void initState() {
    super.initState();
    _alertsFuture = _isMockMode
        ? Future.value(<Map<String, dynamic>>[])
        : ApiRepository.instance.getParentAlerts();
  }

  Future<void> _refreshAlerts() async {
    final future = ApiRepository.instance.getParentAlerts();

    setState(() {
      _alertsFuture = future;
    });

    try {
      await future;
    } catch (_) {
      // FutureBuilder에서 오류 메시지를 표시합니다.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('미하차 경고 내역'),
        backgroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _isMockMode
            ? ValueListenableBuilder<bool>(
          valueListenable: AlertMockStore.hasAlert,
          builder: (context, hasAlert, child) {
            if (!hasAlert) {
              return const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.verified_user_outlined,
                      size: 56,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 12),
                    Text('현재 테스트 경고가 없습니다.'),
                    SizedBox(height: 8),
                    Text(
                      '홈 화면에서 미하차 경고 발생 테스트를 실행해 보세요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              );
            }

            return ListView(
              children: [
                Card(
                  color: const Color(0xFFFFF4F4),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: Color(0xFFE05252),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '미하차 의심 경고 (테스트)',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text('대상 차량: 1호차'),
                        const SizedBox(height: 8),
                        const Text('가정된 잔류 인원: 1명'),
                        const SizedBox(height: 8),
                        const Text('확인 상태: 관리자 확인 필요'),
                        const SizedBox(height: 12),
                        const Text(
                          '이 경고는 테스트 데이터입니다. 실제 AI 감지 결과가 아닙니다.',
                          style: TextStyle(color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        )
            : FutureBuilder<List<Map<String, dynamic>>>(
          future: _alertsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState ==
                ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (snapshot.hasError) {
              return RefreshIndicator(
                onRefresh: _refreshAlerts,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 180),
                    Center(
                      child: Text(
                        '미하차 경고 내역을 불러오지 못했습니다.',
                      ),
                    ),
                  ],
                ),
              );
            }

            final alerts = snapshot.data ?? [];

            if (alerts.isEmpty) {
              return RefreshIndicator(
                onRefresh: _refreshAlerts,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 180),
                    Center(
                      child: Text('현재 미하차 경고 내역이 없습니다.'),
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: _refreshAlerts,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: alerts.length,
                itemBuilder: (context, index) {

                  final alert = alerts[index];

                  return InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        final alertId = alert['id'];

                        if (alertId == null) return;

                        final id = alertId is int
                            ? alertId
                            : int.tryParse(alertId.toString());

                        if (id == null) return;

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AlertDetailScreen(alertId: id),
                          ),
                        );
                      },
                      child: Card(
                        color: const Color(0xFFFFF4F4),
                        child: Padding(

                        padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: Color(0xFFE05252),
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '미하차 의심 경고',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '대상 차량: ${alert['bus_name'] ?? '-'}',
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '경고 내용: ${alert['message'] ?? '-'}',
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '확인 상태: ${switch (alert['status']?.toString().toUpperCase()) {
                              'OPEN' => '확인 필요',
                              'ACKED' => '관리자 확인 중',
                              'RESOLVED' => '조치 완료',
                              _ => alert['status']?.toString() ?? '-',
                            }}',
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '발생 시각: ${alert['created_at'] ?? '-'}',
                          ),
                          if (alert['llm_summary'] != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              'AI 상황 요약: ${alert['llm_summary']}',
                            ),
                          ],
                        ],
                      ),
                        ),
                      ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
