import 'package:flutter/material.dart';

import '../../data/api/api_repository.dart';
import 'alert_chat_screen.dart';

class AlertDetailScreen extends StatefulWidget {
  const AlertDetailScreen({super.key, this.alertId});

  final int? alertId;

  @override
  State<AlertDetailScreen> createState() => _AlertDetailScreenState();
}

class _AlertDetailScreenState extends State<AlertDetailScreen> {
  Future<Map<String, dynamic>>? _alert;
  Future<Map<String, dynamic>>? _guidance;

  @override
  void initState() {
    super.initState();
    _loadAlert();
  }

  void _loadAlert() {
    final alertId = widget.alertId;
    if (alertId != null) {
      _alert = ApiRepository.instance.getAlertDetail(alertId);
      _guidance = ApiRepository.instance.askAlertGuidance(alertId: alertId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('안전 확인 안내')),
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
                final detectedAt = _formatDateTime(
                  alert['detected_at'] ?? alert['created_at'],
                );
                return _buildDetail(
                  message: alert['message'] as String? ?? '경고가 발생했습니다.',
                  busName: alert['bus_name'] as String? ?? '정보 없음',
                  detectedAt: detectedAt,
                  detectedCount: alert['detected_count'] is num
                      ? '${(alert['detected_count'] as num).toInt()}명'
                      : null,
                  status: alert['status'] as String? ?? 'OPEN',
                  summary: alert['llm_summary'] as String? ?? 'AI 요약이 없습니다.',
                  alertId: widget.alertId,
                  guidance: _guidance,
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
    return '${local.month}월 ${local.day}일 $period '
        '$hour:${local.minute.toString().padLeft(2, '0')}';
  }

  String _statusLabel(String status) => switch (status) {
    'ACKED' => '관리자 확인 중',
    'RESOLVED' => '확인 완료',
    _ => '관리자 확인 대기',
  };

  Widget _buildDetail({
    required String message,
    required String busName,
    required String detectedAt,
    required String? detectedCount,
    required String status,
    required String summary,
    required int? alertId,
    required Future<Map<String, dynamic>>? guidance,
  }) {
    final isResolved = status == 'RESOLVED';
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      children: [
        Card(
          color: isResolved
              ? Theme.of(context).colorScheme.tertiaryContainer
              : status == 'ACKED'
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.secondaryContainer,
          shape: RoundedRectangleBorder(
            side: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
            child: Text(message, style: const TextStyle(fontSize: 15)),
          ),
        ),
        const SizedBox(height: 28),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            '안전 확인 상황',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ),
        Card(
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            side: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              _infoRow(Icons.directions_bus, '차량', busName),
              const Divider(height: 1),
              _infoRow(Icons.access_time, '감지 시간', detectedAt),
              if (detectedCount != null) ...[
                const Divider(height: 1),
                _infoRow(Icons.person_search, '차량 내 감지 인원', detectedCount),
              ],
              const Divider(height: 1),
              _infoRow(
                Icons.warning_amber_rounded,
                '확인 상태',
                _statusLabel(status),
                valueColor: isResolved
                    ? Theme.of(context).colorScheme.tertiary
                    : status == 'ACKED'
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.error,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _detailCard(
          icon: Icons.info_outline,
          title: '경고 요약',
          description: summary,
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            '자동 감지와 AI 요약만으로 자녀의 미하차가 확정되는 것은 아닙니다.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ),
        if (alertId != null && guidance != null) ...[
          const SizedBox(height: 12),
          FutureBuilder<Map<String, dynamic>>(
            future: guidance,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.auto_awesome),
                            SizedBox(width: 8),
                            Text(
                              'AI 대응 수칙 (참고용)',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        const LinearProgressIndicator(),
                        const SizedBox(height: 10),
                        Text(
                          '분석 중...',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              if (snapshot.hasError) {
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.auto_awesome),
                    title: const Text('AI 대응 수칙 (참고용)'),
                    subtitle: const Text('안내를 불러오지 못했습니다. 다시 시도해 주세요.'),
                    trailing: IconButton(
                      onPressed: () => setState(_loadAlert),
                      icon: const Icon(Icons.refresh),
                      tooltip: '다시 시도',
                    ),
                  ),
                );
              }
              final response = snapshot.data!;
              final sources = response['sources'];
              final sourceTitles = sources is List
                  ? sources
                        .whereType<Map>()
                        .map((source) => source['title'])
                        .whereType<String>()
                        .take(2)
                        .join(', ')
                  : '';
              final answer =
                  response['answer'] as String? ?? '등록된 대응 수칙을 찾지 못했습니다.';
              return Card(
                clipBehavior: Clip.antiAlias,
                child: ExpansionTile(
                  leading: Icon(
                    Icons.auto_awesome,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: const Text(
                    'AI 대응 수칙 (참고용)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(_guidancePreview(answer), maxLines: 2),
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(),
                    SelectableText(answer),
                    if (sourceTitles.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        '근거 문서: $sourceTitles',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => AlertChatScreen(
                              alertId: alertId,
                              alertContext: {
                                'message': message,
                                'busName': busName,
                                'detectedAt': detectedAt,
                                'status': _statusLabel(status),
                              },
                              initialResponse: response,
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.chat_outlined),
                        label: const Text('추가 질문하기'),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
        const SizedBox(height: 12),
        _detailCard(
          icon: Icons.info_outline_rounded,
          title: '추가 확인이 필요하신가요?',
          description:
              '자동 감지 결과만으로 자녀의 미하차가 확인된 것은 아닙니다. '
              '자세한 내용은 학교 또는 운행 담당자에게 문의해 주세요.',
        ),
      ],
    );
  }

  String _guidancePreview(String answer) {
    final trimmed = answer.trim();
    final firstPart = trimmed.split(RegExp(r'[\r\n]|(?<=[.!?])\s+')).first;
    if (firstPart.length <= 100) return firstPart;
    return '${firstPart.substring(0, 100).trimRight()}…';
  }

  Widget _infoRow(
    IconData icon,
    String title,
    String value, {
    Color? valueColor,
  }) {
    return ListTile(
      minVerticalPadding: 18,
      leading: Icon(
        icon,
        color: valueColor ?? Theme.of(context).colorScheme.primary,
      ),
      title: Text(title),
      trailing: Text(
        value,
        style: TextStyle(fontWeight: FontWeight.w600, color: valueColor),
      ),
    );
  }

  Widget _detailCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Card(
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
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
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
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
