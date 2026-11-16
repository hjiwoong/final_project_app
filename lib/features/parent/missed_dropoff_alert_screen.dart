import 'package:flutter/material.dart';

import '../../data/api/api_repository.dart';
import 'alert_detail_screen.dart';

/// 학부모 미하차 경고 내역 화면 (GET /me/alerts)
class MissedDropoffAlertScreen extends StatefulWidget {
  const MissedDropoffAlertScreen({super.key});

  @override
  State<MissedDropoffAlertScreen> createState() =>
      _MissedDropoffAlertScreenState();
}

class _MissedDropoffAlertScreenState extends State<MissedDropoffAlertScreen> {
  late Future<List<Map<String, dynamic>>> _alertsFuture;

  @override
  void initState() {
    super.initState();
    _alertsFuture = ApiRepository.instance.getParentAlerts(limit: 50);
  }

  Future<void> _refreshAlerts() async {
    final future = ApiRepository.instance.getParentAlerts(limit: 50);
    setState(() => _alertsFuture = future);
    try {
      await future;
    } catch (_) {
      // FutureBuilder 에서 오류 메시지를 표시합니다.
    }
  }

  static String statusLabel(Object? status) {
    return switch (status?.toString().toUpperCase()) {
      'OPEN' => '확인 필요',
      'ACKED' => '관리자 확인 중',
      'RESOLVED' => '조치 완료',
      _ => status?.toString() ?? '-',
    };
  }

  static String formatDateTime(Object? value) {
    if (value is! String) return '-';
    final dateTime = DateTime.tryParse(value);
    if (dateTime == null) return value;
    final local = dateTime.toLocal();
    final period = local.hour < 12 ? '오전' : '오후';
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    return '${local.month}월 ${local.day}일 $period '
        '$hour:${local.minute.toString().padLeft(2, '0')}';
  }

  Widget _messageList(String message) {
    return RefreshIndicator(
      onRefresh: _refreshAlerts,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 180),
          Center(child: Text(message, textAlign: TextAlign.center)),
        ],
      ),
    );
  }

  Widget _buildAlertCard(Map<String, dynamic> alert) {
    final colors = Theme.of(context).colorScheme;
    final isUrgent = alert['level']?.toString().toUpperCase() != 'CHECK';
    final isResolved = alert['status']?.toString().toUpperCase() == 'RESOLVED';
    final accent = isResolved
        ? colors.tertiary
        : isUrgent
        ? colors.error
        : Colors.orange;

    return Card(
      color: isResolved
          ? colors.surfaceContainerLow
          : isUrgent
          ? colors.errorContainer.withValues(alpha: 0.35)
          : colors.secondaryContainer,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          final rawId = alert['id'];
          final id = rawId is int ? rawId : int.tryParse('$rawId');
          if (id == null) return;
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => AlertDetailScreen(alertId: id)),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isResolved
                        ? Icons.check_circle_outline
                        : Icons.warning_amber_rounded,
                    color: accent,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isUrgent ? '미하차 의심 경고' : '확인 필요 경고',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Chip(
                    label: Text(statusLabel(alert['status'])),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text('대상 차량: ${alert['bus_name'] ?? '-'}'),
              const SizedBox(height: 8),
              Text('경고 내용: ${alert['message'] ?? '-'}'),
              if (alert['detected_count'] != null) ...[
                const SizedBox(height: 8),
                Text('차량 내 감지 인원: ${alert['detected_count']}명'),
              ],
              const SizedBox(height: 8),
              Text(
                '발생 시각: ${formatDateTime(alert['detected_at'] ?? alert['created_at'])}',
              ),
              if (alert['llm_summary'] != null) ...[
                const SizedBox(height: 12),
                Text('AI 상황 요약: ${alert['llm_summary']}'),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('미하차 경고 내역')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _alertsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _messageList('미하차 경고 내역을 불러오지 못했습니다.\n아래로 당겨 다시 시도해 주세요.');
            }

            final alerts = snapshot.data ?? const <Map<String, dynamic>>[];
            if (alerts.isEmpty) {
              return _messageList('현재 미하차 경고 내역이 없습니다.');
            }

            return RefreshIndicator(
              onRefresh: _refreshAlerts,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: alerts.length,
                itemBuilder: (context, index) => _buildAlertCard(alerts[index]),
              ),
            );
          },
        ),
      ),
    );
  }
}
