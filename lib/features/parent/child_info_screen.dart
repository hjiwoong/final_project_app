
import 'package:flutter/material.dart';

import '../../data/api/api_repository.dart';
import '../../data/models/child_student.dart';

class ChildInfoScreen extends StatefulWidget {
  const ChildInfoScreen({super.key});

  @override
  State<ChildInfoScreen> createState() => _ChildInfoScreenState();
}

class _ChildInfoScreenState extends State<ChildInfoScreen> {
  late Future<List<ChildStudent>> _children;

  @override
  void initState() {
    super.initState();
    _children = ApiRepository.instance.getChildren();
  }

  void _reload() {
    setState(() => _children = ApiRepository.instance.getChildren());
  }

  String _status(ChildStudent child) {
    if (child.isAbsent) return '오늘 결석';
    return switch (child.busStatus) {
      'IN_PROGRESS' => '배정 버스 운행 중',
      'CLOSED' => '배정 버스 운행 완료',
      'NOT_STARTED' => '운행 전',
      'NOT_ASSIGNED' => '버스 미배정',
      _ => '운행 상태 확인 불가',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('자녀 정보')),
      body: FutureBuilder<List<ChildStudent>>(
        future: _children,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('자녀 정보를 불러오지 못했습니다.'),
                  const SizedBox(height: 8),
                  OutlinedButton(onPressed: _reload, child: const Text('다시 시도')),
                ],
              ),
            );
          }

          final children = snapshot.data ?? const <ChildStudent>[];
          if (children.isEmpty) {
            return const Center(child: Text('연결된 자녀가 없습니다.'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                '등록된 자녀',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                '학부모 계정에 등록된 자녀의 정보를 확인할 수 있습니다.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              for (final child in children)
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
                              child: Icon(Icons.person_outline, size: 28),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    child.name,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    child.className ?? '학급 정보 없음',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Chip(
                              label: Text(_status(child)),
                              backgroundColor: child.isAbsent
                                  ? Colors.orange.shade50
                                  : Colors.blue.shade50,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.directions_bus_outlined,
                              size: 20,
                              color: Colors.blue,
                            ),
                            const SizedBox(width: 8),
                            const Text('배정 버스', style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          child.busName ?? '배정 정보 없음',
                          style: const TextStyle(color: Colors.grey),
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
