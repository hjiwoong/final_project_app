
import 'package:flutter/material.dart';

import 'parent_event_mock_store.dart';

class ParentEventTestScreen extends StatelessWidget {
  const ParentEventTestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('승하차 · 안전 이벤트 테스트'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            '승차 · 하차 이벤트',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 12),

          ValueListenableBuilder<Map<String, ChildBoardingStatus>>(
            valueListenable: ParentEventMockStore.childStatuses,
            builder: (context, statuses, child) {
              return Column(
                children: statuses.entries.map((entry) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            '${entry.key} · '
                                '${ParentEventMockStore.getChildStatusText(entry.value)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 8),

                          ElevatedButton(
                            onPressed: () {
                              ParentEventMockStore.updateChildStatus(
                                entry.key,
                                ChildBoardingStatus.boarded,
                              );
                            },
                            child: const Text('승차 테스트'),
                          ),

                          OutlinedButton(
                            onPressed: () {
                              ParentEventMockStore.updateChildStatus(
                                entry.key,
                                ChildBoardingStatus.droppedOff,
                              );
                            },
                            child: const Text('하차 테스트'),
                          ),

                          TextButton(
                            onPressed: () {
                              ParentEventMockStore.updateChildStatus(
                                entry.key,
                                ChildBoardingStatus.waiting,
                              );
                            },
                            child: const Text('탑승 대기로 변경'),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),

          const SizedBox(height: 24),

          const Text(
            '이상 상황 알림 테스트',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 12),

          ElevatedButton.icon(
            onPressed: () {
              ParentEventMockStore.addSafetyEvent(
                SafetyEventType.suddenBrake,
              );
            },
            icon: const Icon(Icons.warning_amber),
            label: const Text('급정거 발생 테스트'),
          ),

          const SizedBox(height: 8),

          ElevatedButton.icon(
            onPressed: () {
              ParentEventMockStore.addSafetyEvent(
                SafetyEventType.speeding,
              );
            },
            icon: const Icon(Icons.speed),
            label: const Text('과속 발생 테스트'),
          ),

          const SizedBox(height: 8),

          ElevatedButton.icon(
            onPressed: () {
              ParentEventMockStore.addSafetyEvent(
                SafetyEventType.routeDeviation,
              );
            },
            icon: const Icon(Icons.alt_route),
            label: const Text('경로 이탈 발생 테스트'),
          ),

          const SizedBox(height: 24),

          const Text(
            '※ 모든 이벤트는 테스트 데이터이며 실제 차량과 연결되지 않습니다.',
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
