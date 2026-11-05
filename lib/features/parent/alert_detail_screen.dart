import 'package:flutter/material.dart';

import '../../data/api/api_repository.dart';

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
              busName: '1호차',
              detectedAt: '오전 8:40',
              detectedCount: '1명',
              status: 'OPEN',
              summary: '종점에서 하차 후 1명이 남아 있을 가능성이 있습니다.',
              isMock: true,
            )
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
                final detectedAt = _formatDateTime(
                  alert['detected_at'] ?? alert['created_at'],
                );
                final detectedCount = alert['detected_count'];

                return _buildDetail(
                  message: alert['message'] as String? ?? '경고가 발생했습니다.',
                  busName: alert['bus_name'] as String? ?? '정보 없음',
                  detectedAt: detectedAt,
                  detectedCount: detectedCount is num
                      ? '$detectedCount명'
                      : '정보 없음',
                  status: alert['status'] as String? ?? 'OPEN',
                  summary: alert['llm_summary'] as String? ?? 'AI 요약이 없습니다.',
                  isMock: false,
                );
              },
            ),
    );
  }

  String _formatDateTime(Object? value) {
    if (value is! String) return '정보 없음';
    final dateTime = DateTime.tryParse(value);
    if (dateTime == null) return value;
    final local = dateTime.toLocal();
    final period = local.hour < 12 ? '오전' : '오후';
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    return '$period $hour:${local.minute.toString().padLeft(2, '0')}';
  }

  String _statusLabel(String status) => switch (status) {
    'ACKED' => '관리자 확인 중',
    'RESOLVED' => '조치 완료',
    _ => '관리자 확인 대기',
  };

  Widget _buildDetail({
    required String message,
    required String busName,
    required String detectedAt,
    required String detectedCount,
    required String status,
    required String summary,
    required bool isMock,
  }) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      children: [
        Card(
          color: const Color(0xFFFEE2E2),
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: Color(0xFFE5E7EB)),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
            child: Text(
              '🚨 $message',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 28),
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            '경고 발생 정보',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        Card(
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: Color(0xFFE5E7EB)),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              _infoRow(Icons.directions_bus, '차량', busName),
              const Divider(height: 1),
              _infoRow(Icons.access_time, '감지 시간', detectedAt),
              const Divider(height: 1),
              _infoRow(Icons.person_search, '차량 내 감지 인원', detectedCount),
              const Divider(height: 1),
              _infoRow(
                Icons.warning_amber_rounded,
                '확인 상태',
                _statusLabel(status),
                valueColor: status == 'RESOLVED'
                    ? Colors.green
                    : const Color(0xFFE53935),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _detailCard(icon: '✨', title: 'AI 요약', description: summary),
        const SizedBox(height: 12),
        _detailCard(
          icon: '📄',
          title: '대응 수칙',
          description: '즉시 차량 확인 후 보호자·학교에 연락',
        ),
        if (isMock) ...[
          const SizedBox(height: 16),
          const Text(
            '※ 현재 경고 정보와 AI 요약은 테스트용 Mock 데이터입니다.',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      ],
    );
  }

  Widget _infoRow(
    IconData icon,
    String title,
    String value, {
    Color? valueColor,
  }) {
    return ListTile(
      minVerticalPadding: 18,
      leading: Icon(icon, color: valueColor ?? Colors.blueGrey.shade700),
      title: Text(title),
      trailing: Text(
        value,
        style: TextStyle(fontWeight: FontWeight.w600, color: valueColor),
      ),
    );
  }

  Widget _detailCard({
    required String icon,
    required String title,
    required String description,
  }) {
    return Card(
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(icon, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 18)),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: TextStyle(
                      color: Colors.blueGrey.shade700,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
