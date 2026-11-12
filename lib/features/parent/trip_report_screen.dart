import 'package:flutter/material.dart';

import '../../data/api/api_repository.dart';
import '../../data/models/child_student.dart';
import 'alert_detail_screen.dart';
import 'missed_dropoff_alert_screen.dart';

class _ReportData {
  const _ReportData({required this.alerts, required this.children});

  final List<Map<String, dynamic>> alerts;
  final List<ChildStudent> children;
}

/// 학부모 운행 리포트: 자녀의 오늘 운행 상태와 미하차 경고 이력 요약
/// (GET /me/children + GET /me/alerts)
class TripReportScreen extends StatefulWidget {
  const TripReportScreen({super.key});

  @override
  State<TripReportScreen> createState() => _TripReportScreenState();
}

class _TripReportScreenState extends State<TripReportScreen> {
  late Future<_ReportData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_ReportData> _load() async {
    final results = await Future.wait([
      ApiRepository.instance.getParentAlerts(limit: 100),
      ApiRepository.instance.getChildren(),
    ]);
    return _ReportData(
      alerts: results[0] as List<Map<String, dynamic>>,
      children: results[1] as List<ChildStudent>,
    );
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() => _future = future);
    try {
      await future;
    } catch (_) {
      // FutureBuilder 에서 오류 메시지를 표시합니다.
    }
  }

  DateTime? _alertTime(Map<String, dynamic> alert) => DateTime.tryParse(
    (alert['detected_at'] ?? alert['created_at'])?.toString() ?? '',
  )?.toLocal();

  String _childStatus(ChildStudent child) {
    if (child.isAbsent) return '오늘 결석';
    return switch (child.busStatus) {
      'IN_PROGRESS' => '운행 중',
      'CLOSED' => '운행 완료',
      'NOT_STARTED' => '운행 전',
      'NOT_ASSIGNED' => '버스 미배정',
      _ => '확인 불가',
    };
  }

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 8),
    child: Text(
      text,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    ),
  );

  Widget _statTile({
    required IconData icon,
    required Color color,
    required String label,
    required int value,
  }) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label),
      trailing: Text(
        '$value건',
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildReport(_ReportData data) {
    final colors = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekAgo = today.subtract(const Duration(days: 6));

    final alerts = data.alerts;
    final resolved = alerts.where((a) => a['status'] == 'RESOLVED').length;
    final open = alerts.length - resolved;
    final todayCount = alerts.where((a) {
      final t = _alertTime(a);
      return t != null && !t.isBefore(today);
    }).length;
    final weekCount = alerts.where((a) {
      final t = _alertTime(a);
      return t != null && !t.isBefore(weekAgo);
    }).length;
    final recent = alerts.take(5).toList();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        _sectionTitle('오늘의 자녀 운행'),
        if (data.children.isEmpty)
          const Card(
            child: ListTile(
              leading: Icon(Icons.child_care),
              title: Text('연결된 자녀가 없습니다.'),
            ),
          )
        else
          Card(
            child: Column(
              children: [
                for (final child in data.children)
                  ListTile(
                    leading: const Icon(Icons.child_care),
                    title: Text(child.name),
                    subtitle: Text(child.busName ?? '배정 버스 없음'),
                    trailing: Chip(label: Text(_childStatus(child))),
                  ),
              ],
            ),
          ),

        _sectionTitle('미하차 경고 현황'),
        Card(
          child: Column(
            children: [
              _statTile(
                icon: Icons.today,
                color: colors.primary,
                label: '오늘 발생',
                value: todayCount,
              ),
              const Divider(height: 1),
              _statTile(
                icon: Icons.date_range,
                color: colors.primary,
                label: '최근 7일',
                value: weekCount,
              ),
              const Divider(height: 1),
              _statTile(
                icon: Icons.pending_actions,
                color: colors.error,
                label: '확인·조치 중',
                value: open,
              ),
              const Divider(height: 1),
              _statTile(
                icon: Icons.check_circle_outline,
                color: colors.tertiary,
                label: '조치 완료',
                value: resolved,
              ),
            ],
          ),
        ),

        _sectionTitle('최근 경고'),
        if (recent.isEmpty)
          Card(
            child: ListTile(
              leading: Icon(Icons.verified_user_outlined, color: colors.tertiary),
              title: const Text('미하차 경고 이력이 없습니다.'),
            ),
          )
        else
          Card(
            child: Column(
              children: [
                for (final alert in recent)
                  ListTile(
                    leading: Icon(
                      alert['status'] == 'RESOLVED'
                          ? Icons.check_circle_outline
                          : Icons.warning_amber_rounded,
                      color: alert['status'] == 'RESOLVED'
                          ? colors.tertiary
                          : colors.error,
                    ),
                    title: Text(alert['message']?.toString() ?? '미하차 의심 경고'),
                    subtitle: Text(
                      '${alert['bus_name'] ?? '-'} · '
                      '${_MissedDropoffFormat.dateTime(alert['detected_at'] ?? alert['created_at'])}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      final id = alert['id'];
                      if (id is! int) return;
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AlertDetailScreen(alertId: id),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const MissedDropoffAlertScreen()),
          ),
          icon: const Icon(Icons.list_alt),
          label: const Text('전체 경고 내역 보기'),
        ),
        const SizedBox(height: 16),
        Text(
          '경고 집계는 최근 100건 기준입니다. 자동 감지 결과만으로 미하차가 '
          '확정된 것은 아니며, 기관과 기사가 차량을 직접 확인한 뒤 조치 완료로 처리합니다.',
          style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('운행 리포트')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<_ReportData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 180),
                  const Center(child: Text('운행 리포트를 불러오지 못했습니다.')),
                  const SizedBox(height: 12),
                  Center(
                    child: OutlinedButton(
                      onPressed: _refresh,
                      child: const Text('다시 시도'),
                    ),
                  ),
                ],
              );
            }
            return _buildReport(snapshot.data!);
          },
        ),
      ),
    );
  }
}

/// 경고 목록 화면과 같은 시각 표기를 사용한다.
abstract final class _MissedDropoffFormat {
  static String dateTime(Object? value) {
    if (value is! String) return '-';
    final dateTime = DateTime.tryParse(value);
    if (dateTime == null) return value;
    final local = dateTime.toLocal();
    final period = local.hour < 12 ? '오전' : '오후';
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    return '${local.month}월 ${local.day}일 $period '
        '$hour:${local.minute.toString().padLeft(2, '0')}';
  }
}
