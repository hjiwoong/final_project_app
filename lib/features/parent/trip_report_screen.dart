
import 'package:flutter/material.dart';

import 'parent_event_mock_store.dart';

// 학부모 운행 리포트 (Mock 데이터)
class TripReportScreen extends StatelessWidget {
  const TripReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('운행 리포트'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            '오늘의 운행 리포트',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 12),

          // 운행 요약 (Mock)
          const Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    Icons.schedule,
                    color: Colors.blue,
                  ),
                  title: Text('정시율'),
                  trailing: Text(
                    '95%',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                Divider(height: 1),

                ListTile(
                  leading: Icon(
                    Icons.shield,
                    color: Colors.green,
                  ),
                  title: Text('안전 점수'),
                  trailing: Text(
                    '92점',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          const Text(
            '이상 상황 발생 현황',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          // 급정거 · 과속 · 경로 이탈 건수 자동 반영
          ValueListenableBuilder<Map<SafetyEventType, int>>(
            valueListenable: ParentEventMockStore.safetyCounts,
            builder: (context, counts, child) {
              return Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.orange,
                      ),
                      title: const Text('급정거'),
                      trailing: Text(
                        '${counts[SafetyEventType.suddenBrake] ?? 0}건',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    const Divider(height: 1),

                    ListTile(
                      leading: const Icon(
                        Icons.speed,
                        color: Colors.red,
                      ),
                      title: const Text('과속'),
                      trailing: Text(
                        '${counts[SafetyEventType.speeding] ?? 0}건',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    const Divider(height: 1),

                    ListTile(
                      leading: const Icon(
                        Icons.alt_route,
                        color: Colors.deepOrange,
                      ),
                      title: const Text('경로 이탈'),
                      trailing: Text(
                        '${counts[SafetyEventType.routeDeviation] ?? 0}건',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          const Text(
            '안전 운행 안내',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '운행 중 발생한 급정거, 과속, 경로 이탈 등의 '
                    '이상 상황을 확인할 수 있습니다.\n\n'
                    '현재 표시되는 운행 리포트는 테스트 데이터이며 '
                    '실제 차량 운행 기록과 연결되지 않았습니다.',
              ),
            ),
          ),

          const SizedBox(height: 16),

          const Text(
            '※ 정시율과 안전 점수는 고정된 Mock 데이터입니다. '
                '이상 상황 발생 건수는 테스트 버튼에 따라 변경됩니다.',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
