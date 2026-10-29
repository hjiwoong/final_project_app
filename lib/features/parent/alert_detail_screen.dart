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
          ? const Center(child: Text('경고 정보를 찾을 수 없습니다.'))
          : FutureBuilder<Map<String, dynamic>>(
              future: _alert,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
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
                  message: alert['message'] as String? ?? '경고가 발생했습니다.',
                  summary: alert['llm_summary'] as String? ?? 'AI 요약이 없습니다.',
                );
              },
            ),
    );
  }

  Widget _buildDetail({required String message, required String summary}) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: const Color(0xFFFEE2E2),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              '🚨 $message',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Text('✨'),
            title: const Text('AI 요약'),
            subtitle: Text(summary),
          ),
        ),
      ],
    );
  }
}
