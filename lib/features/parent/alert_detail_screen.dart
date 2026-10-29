
import 'package:flutter/material.dart';

import '../../data/api/api_repository.dart';

/// 경고 상세: LLM 요약 + RAG 대응 수칙
class AlertDetailScreen extends StatefulWidget {
  const AlertDetailScreen({super.key, this.alertId});

  final int? alertId;

  @override
  State<AlertDetailScreen> createState() => _AlertDetailScreenState();
}

class _AlertDetailScreenState extends State<AlertDetailScreen> {
  Future<Map<String, dynamic>>? _alert;

  @override
  void initState() {
    super.initState();
    _loadAlert();
  }

  void _loadAlert() {
    final alertId = widget.alertId;
    if (alertId != null) {
      _alert = ApiRepository.instance.getAlertDetail(alertId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('경고 상세')),
      body: widget.alertId == null
          ? _buildDetail(
        message: '미하차 의심 1명',
        summary: '종점에서 하차 후 1명이 남아 있을 가능성이 있습니다.',
        isMock: true,
      )
          : FutureBuilder<Map<String, dynamic>>(
        future: _alert,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('경고 정보를 불러오지 못했습니다.'),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => setState(_loadAlert),
                    child: const Text('다시 시도'),
                  ),
                ],
              ),
            );
          }

          final alert = snapshot.data!;

          return _buildDetail(
            message: alert['message'] as String? ??
                '경고가 발생했습니다.',
            summary: alert['llm_summary'] as String? ??
                'AI 요약이 없습니다.',
            isMock: false,
          );
        },
      ),
    );
  }

  Widget _buildDetail({
    required String message,
    required String summary,
    required bool isMock,
  }) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 미하차 의심 경고
        Card(
          color: const Color(0xFFFEE2E2),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              '🚨 $message',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Mock 경고 발생 정보
        if (isMock) ...[
          const Text(
            '경고 발생 정보',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          const Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.directions_bus),
                  title: Text('차량'),
                  trailing: Text('1호차'),
                ),
                Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.access_time),
                  title: Text('감지 시간'),
                  trailing: Text('오전 8:40'),
                ),
                Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.person_search),
                  title: Text('차량 내 감지 인원'),
                  trailing: Text('1명'),
                ),
                Divider(height: 1),
                ListTile(
                  leading: Icon(
                    Icons.warning_amber,
                    color: Colors.red,
                  ),
                  title: Text('확인 상태'),
                  trailing: Text(
                    '관리자 확인 대기',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),
        ],

        // AI 요약
        Card(
          child: ListTile(
            leading: const Text('✨'),
            title: const Text('AI 요약'),
            subtitle: Text(summary),
          ),
        ),

        // 기존 대응 수칙 (Mock)
        if (isMock)
          const Card(
            child: ListTile(
              leading: Text('📄'),
              title: Text('대응 수칙'),
              subtitle: Text(
                '즉시 차량 확인 후 보호자·학교에 연락',
              ),
            ),
          ),

        const SizedBox(height: 12),

        if (isMock)
          const Text(
            '※ 현재 경고 정보와 AI 요약은 테스트용 Mock 데이터입니다.',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
      ],
    );
  }
}
