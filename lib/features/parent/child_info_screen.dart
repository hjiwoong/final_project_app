
import 'package:flutter/material.dart';

import 'attendance_mock_store.dart';

// 학부모 자녀 정보 화면 (Mock 데이터)
class ChildInfoScreen extends StatelessWidget {
  const ChildInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('자녀 정보'),
      ),
      body: ValueListenableBuilder<Map<String, bool>>(
        valueListenable: AttendanceMockStore.absent,
        builder: (context, absent, child) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                '등록된 자녀',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                '학부모 계정에 등록된 자녀의 정보를 확인할 수 있습니다.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey,
                ),
              ),

              const SizedBox(height: 16),

              for (final name in absent.keys)
                Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const CircleAvatar(
                              radius: 24,
                              child: Icon(
                                Icons.person_outline,
                                size: 28,
                              ),
                            ),

                            const SizedBox(width: 12),

                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),

                                  const SizedBox(height: 4),

                                  const Text(
                                    '등록된 자녀',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            Chip(
                              label: Text(
                                absent[name] == true
                                    ? '오늘 결석'
                                    : '오늘 등교',
                              ),
                              backgroundColor: absent[name] == true
                                  ? Colors.orange.shade50
                                  : Colors.green.shade50,
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        const Divider(),

                        const SizedBox(height: 8),

                        const Row(
                          children: [
                            Icon(
                              Icons.directions_bus_outlined,
                              size: 20,
                              color: Colors.blue,
                            ),

                            SizedBox(width: 8),

                            Text(
                              '배정 버스',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        const Text(
                          '버스 배정 정보는 추후 연동 예정',
                          style: TextStyle(
                            color: Colors.grey,
                          ),
                        ),

                        const SizedBox(height: 16),

                        const Row(
                          children: [
                            Icon(
                              Icons.school_outlined,
                              size: 20,
                              color: Colors.blue,
                            ),

                            SizedBox(width: 8),

                            Text(
                              '학교 / 학년 / 반',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        const Text(
                          '학교 정보는 추후 연동 예정',
                          style: TextStyle(
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 16),

              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.grey,
                      ),

                      SizedBox(width: 12),

                      Expanded(
                        child: Text(
                          '현재 자녀 정보는 Mock 데이터입니다. '
                              '학교, 학년, 반 및 배정 버스 정보는 '
                              '실제 서버 연동 후 표시할 예정입니다.',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
