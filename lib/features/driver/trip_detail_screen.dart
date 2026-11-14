import 'package:flutter/material.dart';

import '../../data/api/api_repository.dart';

/// 운행 기록 화면과 상세 화면이 함께 쓰는 포맷·상태 도우미
class TripFormat {
  TripFormat._();

  static const okColor = Color(0xFF2E7D32);
  static const warnColor = Color(0xFFEF6C00);
  static const dangerColor = Color(0xFFC62828);

  static DateTime? parse(Object? value) =>
      value is String ? DateTime.tryParse(value)?.toLocal() : null;

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String time(DateTime t) => '${_two(t.hour)}:${_two(t.minute)}';

  static String timeWithSeconds(DateTime t) =>
      '${time(t)}:${_two(t.second)}';

  static const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

  /// 11월 12일 (목) / 2025년 12월 3일 (수)
  static String date(DateTime d) {
    final base = '${d.month}월 ${d.day}일 (${_weekdays[d.weekday - 1]})';
    return d.year == DateTime.now().year ? base : '${d.year}년 $base';
  }

  /// 목록 섹션 제목: 오늘 / 어제 / 날짜
  static String dateHeader(DateTime? d) {
    if (d == null) return '날짜 정보 없음';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(DateTime(d.year, d.month, d.day)).inDays;
    if (diff == 0) return '오늘';
    if (diff == 1) return '어제';
    return date(d);
  }

  static String duration(DateTime start, DateTime end) {
    final minutes = end.difference(start).inMinutes;
    if (minutes < 0) return '시간 정보 없음';
    if (minutes < 1) return '1분 미만';
    if (minutes < 60) return '$minutes분';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '$h시간' : '$h시간 $m분';
  }

  /// 18:12 ~ 18:19 · 6분
  static String timeRange(Map<String, dynamic> trip) {
    final start = parse(trip['started_at']);
    final end = parse(trip['ended_at']);
    if (start == null) return '시간 정보 없음';
    if (end == null) return '${time(start)} ~ 운행 중';
    final sameDay = start.year == end.year &&
        start.month == end.month &&
        start.day == end.day;
    final endText =
        sameDay ? time(end) : '${end.month}/${end.day} ${time(end)}';
    return '${time(start)} ~ $endText · ${duration(start, end)}';
  }

  static int? toInt(Object? value) => value is num ? value.toInt() : null;

  /// 잔류(미하차 의심) 인원. 서버 값이 없으면 승차 - 하차로 계산
  static int remaining(Map<String, dynamic> trip) {
    final server = toInt(trip['remaining_count']);
    if (server != null) return server;
    final boarding = toInt(trip['boarding_count']);
    final alighted = toInt(trip['alighted_count']);
    if (boarding == null || alighted == null) return 0;
    return boarding > alighted ? boarding - alighted : 0;
  }

  static String title(Map<String, dynamic> trip) =>
      '${trip['bus_name'] ?? '차량 정보 없음'}'
      '${trip['plate_no'] == null ? '' : ' · ${trip['plate_no']}'}';
}

/// 운행 상태 배지 (운행 중 / 정상 하차 / 미하차 의심 / 확인 필요 / 판정 전)
class TripStatusBadge extends StatelessWidget {
  const TripStatusBadge({super.key, required this.trip});

  final Map<String, dynamic> trip;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (trip['status'] != 'CLOSED') {
      return InfoBadge('운행 중', colors.primary,
          icon: Icons.play_circle_outline);
    }
    switch (trip['result']) {
      case 'OK':
        return const InfoBadge('정상 하차', TripFormat.okColor,
            icon: Icons.check_circle_outline);
      case 'MISSED':
        return InfoBadge(
          '미하차 의심 ${TripFormat.remaining(trip)}명',
          TripFormat.dangerColor,
          icon: Icons.warning_amber_rounded,
        );
      case 'NEEDS_CHECK':
        return const InfoBadge('확인 필요', TripFormat.warnColor,
            icon: Icons.help_outline_rounded);
      case 'PENDING':
        return InfoBadge('판정 전', colors.onSurfaceVariant,
            icon: Icons.hourglass_empty_rounded);
    }
    // result 값이 없을 때는 인원으로 판단
    final missing = TripFormat.remaining(trip);
    return missing > 0
        ? InfoBadge('미하차 의심 $missing명', TripFormat.dangerColor,
            icon: Icons.warning_amber_rounded)
        : const InfoBadge('운행 완료', TripFormat.okColor,
            icon: Icons.check_circle_outline);
  }

  /// 아이콘 등에 쓸 대표 색
  static Color colorOf(BuildContext context, Map<String, dynamic> trip) {
    final colors = Theme.of(context).colorScheme;
    if (trip['status'] != 'CLOSED') return colors.primary;
    switch (trip['result']) {
      case 'MISSED':
        return TripFormat.dangerColor;
      case 'NEEDS_CHECK':
        return TripFormat.warnColor;
    }
    return TripFormat.remaining(trip) > 0
        ? TripFormat.dangerColor
        : colors.onSurfaceVariant;
  }
}

class InfoBadge extends StatelessWidget {
  const InfoBadge(this.text, this.color, {super.key, this.icon});

  final String text;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 3),
          ],
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// 운행 상세 화면
/// 목록에서 받은 요약([trip])을 먼저 보여주고, GET /trips/{id} 로 상세를 불러와 채운다.
class TripDetailScreen extends StatefulWidget {
  const TripDetailScreen({super.key, required this.trip});

  final Map<String, dynamic> trip;

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  Future<Map<String, dynamic>>? _detail;

  int? get _tripId => TripFormat.toInt(widget.trip['id']);

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final id = _tripId;
    if (id == null) return;
    _detail = ApiRepository.instance.getTripRecord(id);
  }

  Future<void> _refresh() async {
    setState(_load);
    try {
      await _detail;
    } catch (_) {
      // 오류는 FutureBuilder 가 보여준다
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('운행 상세')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<Map<String, dynamic>>(
          future: _detail,
          builder: (context, snapshot) {
            // 상세가 오기 전에는 목록에서 받은 요약으로 화면을 먼저 채운다
            final trip = snapshot.data ?? widget.trip;
            final loading =
                snapshot.connectionState == ConnectionState.waiting;
            final failed = snapshot.hasError || _detail == null;
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(12),
              children: [
                _SummaryCard(trip: trip),
                const SizedBox(height: 10),
                _CountCard(trip: trip),
                if (loading)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (failed)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const Text('운행 상세를 불러오지 못했습니다.'),
                        TextButton(
                          onPressed: _refresh,
                          child: const Text('다시 시도'),
                        ),
                      ],
                    ),
                  )
                else ...[
                  _AlertsSection(alerts: trip['open_alerts']),
                  _StudentsSection(students: trip['student_attendances']),
                  _EventsSection(events: trip['events']),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

// ---------- 섹션 공통 ----------

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
          SizedBox(width: double.infinity, child: Card(child: child)),
        ],
      ),
    );
  }
}

// ---------- 요약 ----------

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.trip});

  final Map<String, dynamic> trip;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final start = TripFormat.parse(trip['started_at']);
    final confirm = switch (trip['confirm_method']) {
      'scan' => '차량 내부 스캔',
      'button' => '버튼 확인',
      _ => null,
    };
    Widget row(IconData icon, String text) => Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            children: [
              Icon(icon, size: 16, color: colors.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(child: Text(text)),
            ],
          ),
        );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.directions_bus_outlined,
                    color: TripStatusBadge.colorOf(context, trip)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    TripFormat.title(trip),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                TripStatusBadge(trip: trip),
                if (trip['simulation_mode'] == true)
                  InfoBadge('시뮬레이션', colors.onSurfaceVariant,
                      icon: Icons.science_outlined),
              ],
            ),
            const SizedBox(height: 6),
            row(Icons.calendar_today_outlined,
                start == null ? '날짜 정보 없음' : TripFormat.date(start)),
            row(Icons.schedule, TripFormat.timeRange(trip)),
            row(Icons.person_outline,
                '${trip['driver_name'] ?? '운전자 정보 없음'}'),
            if (confirm != null) row(Icons.fact_check_outlined, '하차 확인: $confirm'),
          ],
        ),
      ),
    );
  }
}

class _CountCard extends StatelessWidget {
  const _CountCard({required this.trip});

  final Map<String, dynamic> trip;

  @override
  Widget build(BuildContext context) {
    final closed = trip['status'] == 'CLOSED';
    final remaining = TripFormat.remaining(trip);
    Widget count(String label, Object? value, {Color? color}) => Expanded(
          child: Column(
            children: [
              Text(
                value is num ? '${value.toInt()}명' : '-',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(label),
            ],
          ),
        );
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            count('탑승 예정', trip['expected_count']),
            count('승차', trip['boarding_count']),
            count('하차', trip['alighted_count']),
            if (closed)
              count('미하차', remaining,
                  color: remaining > 0 ? TripFormat.dangerColor : null),
          ],
        ),
      ),
    );
  }
}

// ---------- 경고 ----------

class _AlertsSection extends StatelessWidget {
  const _AlertsSection({required this.alerts});

  final Object? alerts;

  @override
  Widget build(BuildContext context) {
    final items = alerts is List ? (alerts as List).whereType<Map>().toList() : [];
    if (items.isEmpty) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    return _Section(
      title: '처리 중인 경고 ${items.length}건',
      child: Column(
        children: [
          for (final (i, a) in items.indexed) ...[
            if (i > 0) const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    children: [
                      a['level'] == 'URGENT'
                          ? const InfoBadge('긴급', TripFormat.dangerColor,
                              icon: Icons.priority_high_rounded)
                          : const InfoBadge('확인 필요', TripFormat.warnColor),
                      InfoBadge(
                        a['status'] == 'ACKED' ? '확인함' : '미확인',
                        colors.onSurfaceVariant,
                      ),
                    ],
                  ),
                  if ((a['message']?.toString() ?? '').isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      a['message'].toString(),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                  if ((a['llm_summary']?.toString() ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.auto_awesome,
                            size: 16, color: colors.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            a['llm_summary'].toString().trim(),
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------- 학생별 승·하차 ----------

class _StudentsSection extends StatelessWidget {
  const _StudentsSection({required this.students});

  final Object? students;

  Widget _check(String label, Object? confirmedAt) {
    final t = TripFormat.parse(confirmedAt);
    final ok = t != null;
    final color = ok ? TripFormat.okColor : TripFormat.warnColor;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(ok ? Icons.check_circle : Icons.error_outline,
            size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          ok ? '$label ${TripFormat.time(t)}' : '$label 미확인',
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final items =
        students is List ? (students as List).whereType<Map>().toList() : [];
    if (items.isEmpty) {
      return const _Section(
        title: '학생 승·하차',
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('학생 승·하차 확인 기록이 없습니다.'),
        ),
      );
    }
    final unconfirmed = items
        .where((s) =>
            s['boarding_confirmed_at'] == null ||
            s['alighting_confirmed_at'] == null)
        .length;
    return _Section(
      title: '학생 승·하차',
      trailing: Text(
        unconfirmed == 0
            ? '${items.length}명 모두 확인'
            : '${items.length}명 중 $unconfirmed명 확인 필요',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: unconfirmed == 0 ? TripFormat.okColor : TripFormat.warnColor,
        ),
      ),
      child: Column(
        children: [
          for (final (i, s) in items.indexed) ...[
            if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
            ListTile(
              leading: const Icon(Icons.child_care_outlined),
              title: Text(s['student_name']?.toString() ?? '학생'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if ((s['class_name']?.toString() ?? '').isNotEmpty)
                    Text(s['class_name'].toString()),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 12,
                    runSpacing: 2,
                    children: [
                      _check('승차', s['boarding_confirmed_at']),
                      _check('하차', s['alighting_confirmed_at']),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------- 이벤트 타임라인 ----------

class _EventsSection extends StatelessWidget {
  const _EventsSection({required this.events});

  final Object? events;

  @override
  Widget build(BuildContext context) {
    final items =
        events is List ? (events as List).whereType<Map>().toList() : [];
    if (items.isEmpty) return const SizedBox.shrink();
    items.sort((a, b) {
      final ta = TripFormat.parse(a['captured_at'] ?? a['uploaded_at']);
      final tb = TripFormat.parse(b['captured_at'] ?? b['uploaded_at']);
      if (ta == null || tb == null) return 0;
      return ta.compareTo(tb);
    });
    final colors = Theme.of(context).colorScheme;

    return _Section(
      title: '운행 타임라인',
      child: Column(
        children: [
          for (final e in items)
            Builder(builder: (context) {
              final (label, icon, color) = switch (e['event_type']) {
                'BOARDING' => ('승차 사진', Icons.login_rounded, colors.primary),
                'DROPOFF' => ('종점 사진', Icons.logout_rounded, TripFormat.okColor),
                'MISMATCH' => (
                    '인원 불일치',
                    Icons.warning_amber_rounded,
                    TripFormat.dangerColor
                  ),
                _ => ('기록', Icons.circle_outlined, colors.onSurfaceVariant),
              };
              final t = TripFormat.parse(e['captured_at'] ?? e['uploaded_at']);
              final people = TripFormat.toInt(e['person_count']);
              final lowConf = TripFormat.toInt(e['low_conf_count']) ?? 0;
              final excluded = TripFormat.toInt(e['exclude_count']) ?? 0;
              final details = [
                if (people != null) '감지 $people명',
                if (excluded > 0) '제외 $excluded명',
                if (lowConf > 0) '불확실 $lowConf명',
                if (e['image_available'] == false) '사진 만료',
              ].join(' · ');
              return ListTile(
                leading: Icon(icon, color: color),
                title: Text(label),
                subtitle: details.isEmpty ? null : Text(details),
                trailing: Text(
                  t == null ? '-' : TripFormat.timeWithSeconds(t),
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
              );
            }),
        ],
      ),
    );
  }
}
