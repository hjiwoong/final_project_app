import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/errors/app_error_message.dart';
import '../../data/api/api_repository.dart';
import '../../widgets/fullscreen_image_viewer.dart';
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
                final tripEvents = <Map<String, dynamic>>[];
                final eventIds = <int>{};
                final alertEvent = alert['alert_event'];
                if (alertEvent is Map) {
                  final event = Map<String, dynamic>.from(alertEvent);
                  final eventId = event['id'];
                  if (eventId is num) {
                    tripEvents.add(event);
                    eventIds.add(eventId.toInt());
                  }
                }
                if (alert['trip_events'] is List) {
                  for (final item in alert['trip_events'] as List) {
                    if (item is! Map) continue;
                    final event = Map<String, dynamic>.from(item);
                    final eventId = event['id'];
                    if (eventId is num && eventIds.add(eventId.toInt())) {
                      tripEvents.add(event);
                    }
                  }
                }
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
                  tripEvents: tripEvents,
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
    required List<Map<String, dynamic>> tripEvents,
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
        if (alertId != null) ...[
          const SizedBox(height: 12),
          _buildTripPhotos(alertId, tripEvents),
        ],
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

  Widget _buildTripPhotos(int alertId, List<Map<String, dynamic>> events) {
    final photos =
        events
            .where(
              (event) =>
                  event['event_type'] == 'BOARDING' ||
                  event['event_type'] == 'DROPOFF' ||
                  event['event_type'] == 'MISMATCH',
            )
            .toList()
          ..sort((first, second) {
            final firstTime = DateTime.tryParse(
              (first['captured_at'] ?? first['uploaded_at'])?.toString() ?? '',
            );
            final secondTime = DateTime.tryParse(
              (second['captured_at'] ?? second['uploaded_at'])?.toString() ??
                  '',
            );
            if (firstTime == null || secondTime == null) return 0;
            return firstTime.compareTo(secondTime);
          });

    final groupedPhotos = <String, List<Map<String, dynamic>>>{};
    for (final photo in photos) {
      final time = _eventDateTime(photo);
      final dateLabel = time == null
          ? '날짜 정보 없음'
          : '${time.year}년 ${time.month}월 ${time.day}일';
      groupedPhotos.putIfAbsent(dateLabel, () => []).add(photo);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(8, 8, 8, 8),
          child: Text(
            '승·하차 사진',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        if (photos.isEmpty)
          const Card(
            child: ListTile(
              leading: Icon(Icons.photo_library_outlined),
              title: Text('이 운행의 승차·하차 사진이 없습니다.'),
            ),
          )
        else
          for (final entry in groupedPhotos.entries) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
              child: Text(
                entry.key,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            for (final photo in entry.value)
              _AlertEventPhotoCard(
                key: ValueKey('${photo['id']}-${photo['event_type']}'),
                alertId: alertId,
                event: photo,
              ),
          ],
      ],
    );
  }

  DateTime? _eventDateTime(Map<String, dynamic> event) {
    final value = event['captured_at'] ?? event['uploaded_at'];
    if (value is! String) return null;
    return DateTime.tryParse(value)?.toLocal();
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

class _AlertEventPhotoCard extends StatefulWidget {
  const _AlertEventPhotoCard({
    super.key,
    required this.alertId,
    required this.event,
  });

  final int alertId;
  final Map<String, dynamic> event;

  @override
  State<_AlertEventPhotoCard> createState() => _AlertEventPhotoCardState();
}

class _AlertEventPhotoCardState extends State<_AlertEventPhotoCard> {
  Future<Uint8List>? _image;

  int? get _eventId =>
      widget.event['id'] is num ? (widget.event['id'] as num).toInt() : null;

  void _loadImage() {
    final eventId = _eventId;
    if (eventId == null || widget.event['image_available'] == false) return;
    setState(() {
      _image = ApiRepository.instance.getAlertEventImage(
        widget.alertId,
        eventId,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final eventId = _eventId;
    final eventType = widget.event['event_type'];
    final isBoarding = eventType == 'BOARDING';
    final title = switch (eventType) {
      'BOARDING' => '승차 사진',
      'DROPOFF' => '하차 사진',
      'MISMATCH' => '미하차 감지 사진',
      _ => '운행 사진',
    };
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: Icon(isBoarding ? Icons.login_rounded : Icons.logout_rounded),
        title: Text(title),
        subtitle: Text(_formatTime(widget.event)),
        onExpansionChanged: (expanded) {
          if (expanded && _image == null) _loadImage();
        },
        children: [
          if (eventId == null || widget.event['image_available'] == false)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('사진을 사용할 수 없거나 보관 기간이 만료되었습니다.'),
            )
          else if (_image == null)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            FutureBuilder<Uint8List>(
              future: _image,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError || !snapshot.hasData) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(
                          AppErrorMessage.from(
                            snapshot.error ?? StateError('사진을 불러오지 못했습니다.'),
                            fallback: '사진을 불러오지 못했습니다.',
                          ),
                          textAlign: TextAlign.center,
                        ),
                        TextButton.icon(
                          onPressed: _loadImage,
                          icon: const Icon(Icons.refresh),
                          label: const Text('다시 시도'),
                        ),
                      ],
                    ),
                  );
                }

                final bytes = snapshot.data!;
                final heroTag = 'alert-event-${widget.alertId}-$eventId';
                return Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Semantics(
                    button: true,
                    label: '$title 확대하여 보기',
                    child: InkWell(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => FullscreenImageViewer(
                            heroTag: heroTag,
                            child: Image.memory(bytes, fit: BoxFit.contain),
                          ),
                        ),
                      ),
                      child: Hero(
                        tag: heroTag,
                        child: Image.memory(
                          bytes,
                          width: double.infinity,
                          height: 190,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  String _formatTime(Map<String, dynamic> event) {
    final value = event['captured_at'] ?? event['uploaded_at'];
    if (value is! String) return '시간 정보 없음';
    final time = DateTime.tryParse(value)?.toLocal();
    if (time == null) return '시간 정보 없음';
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
  }
}
