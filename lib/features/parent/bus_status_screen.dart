import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

import '../../core/maps/naver_map_status.dart';
import '../../data/api/api_repository.dart';
import '../../data/models/child_student.dart';
import 'child_location_screen.dart';

/// 오늘 기준 버스 하나의 운행 단계
enum _TripStage { notStarted, running, finished }

class _BusStatusItem {
  const _BusStatusItem({
    required this.busId,
    required this.busName,
    required this.plateNo,
    required this.stage,
    required this.startedAt,
    required this.children,
  });

  final int? busId;
  final String busName;
  final String plateNo;
  final _TripStage stage;
  final DateTime? startedAt;
  final List<ChildStudent> children;
}

/// 학부모 버스 운행 현황 (GET /me/bus-status + GET /me/children)
/// 지도에는 학부모가 등록한 자녀 탑승 위치를 표시한다.
/// (서버에 버스 실시간 GPS 데이터가 없으므로 버스 위치는 표시하지 않는다)
class BusStatusScreen extends StatefulWidget {
  const BusStatusScreen({super.key});

  @override
  State<BusStatusScreen> createState() => _BusStatusScreenState();
}

class _BusStatusScreenState extends State<BusStatusScreen> {
  static const _autoRefreshInterval = Duration(seconds: 30);

  late Future<List<_BusStatusItem>> _future;
  List<ChildStudent> _children = const [];
  Timer? _timer;
  DateTime? _updatedAt;

  @override
  void initState() {
    super.initState();
    _future = _load();
    _timer = Timer.periodic(_autoRefreshInterval, (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<List<_BusStatusItem>> _load() async {
    final results = await Future.wait([
      ApiRepository.instance.getParentBusStatus(),
      ApiRepository.instance.getChildren(),
    ]);
    final statuses = results[0] as List<Map<String, dynamic>>;
    final children = results[1] as List<ChildStudent>;
    _children = children;

    final items = statuses.map((bus) {
      final busId = bus['bus_id'] as int?;
      final busName = bus['bus_name']?.toString() ?? '버스';
      final riders = children
          .where(
            (child) => busId != null
                ? child.busId == busId
                : child.busName == busName,
          )
          .toList();

      final _TripStage stage;
      if (bus['status'] == 'IN_PROGRESS') {
        stage = _TripStage.running;
      } else if (riders.any((child) => child.busStatus == 'CLOSED')) {
        // /me/children 의 bus_status 는 오늘 가장 최근 운행 상태
        stage = _TripStage.finished;
      } else {
        stage = _TripStage.notStarted;
      }

      return _BusStatusItem(
        busId: busId,
        busName: busName,
        plateNo: bus['plate_no']?.toString() ?? '-',
        stage: stage,
        startedAt: DateTime.tryParse(bus['started_at']?.toString() ?? ''),
        children: riders,
      );
    }).toList();

    _updatedAt = DateTime.now();
    return items;
  }

  Future<void> _refresh() async {
    final future = _load();
    if (!mounted) return;
    setState(() => _future = future);
    try {
      await future;
    } catch (_) {
      // FutureBuilder 에서 오류 메시지를 표시합니다.
    }
  }

  String _stageText(_TripStage stage) => switch (stage) {
    _TripStage.notStarted => '운행 전',
    _TripStage.running => '운행 중',
    _TripStage.finished => '오늘 운행 완료',
  };

  Color _stageColor(BuildContext context, _TripStage stage) {
    final colors = Theme.of(context).colorScheme;
    return switch (stage) {
      _TripStage.notStarted => colors.surfaceContainerHighest,
      _TripStage.running => colors.primaryContainer,
      _TripStage.finished => colors.tertiaryContainer,
    };
  }

  String _formatTime(DateTime? value) {
    if (value == null) return '';
    final local = value.toLocal();
    final period = local.hour < 12 ? '오전' : '오후';
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    return '$period $hour:${local.minute.toString().padLeft(2, '0')}';
  }

  String _elapsed(DateTime? startedAt) {
    if (startedAt == null) return '';
    final minutes = DateTime.now().difference(startedAt.toLocal()).inMinutes;
    if (minutes < 1) return '방금 출발';
    if (minutes < 60) return '$minutes분째 운행 중';
    return '${minutes ~/ 60}시간 ${minutes % 60}분째 운행 중';
  }

  Widget _buildBusCard(_BusStatusItem bus) {
    final colors = Theme.of(context).colorScheme;
    final hasStarted = bus.stage != _TripStage.notStarted;
    final isRunning = bus.stage == _TripStage.running;
    final isFinished = bus.stage == _TripStage.finished;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: const Icon(Icons.directions_bus, size: 32),
            title: Text(
              bus.busName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('차량번호: ${bus.plateNo}'),
            trailing: Chip(
              label: Text(_stageText(bus.stage)),
              backgroundColor: _stageColor(context, bus.stage),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(
              hasStarted ? Icons.check_circle : Icons.radio_button_unchecked,
              color: hasStarted ? colors.tertiary : colors.onSurfaceVariant,
            ),
            title: const Text('운행 시작'),
            subtitle: Text(
              isRunning && bus.startedAt != null
                  ? '${_formatTime(bus.startedAt)} 출발'
                  : hasStarted
                  ? '출발 완료'
                  : '운행 시작 대기',
            ),
          ),
          ListTile(
            leading: Icon(
              isRunning
                  ? Icons.directions_bus
                  : isFinished
                  ? Icons.check_circle
                  : Icons.radio_button_unchecked,
              color: isRunning
                  ? colors.primary
                  : isFinished
                  ? colors.tertiary
                  : colors.onSurfaceVariant,
            ),
            title: Text(isFinished ? '운행 완료' : '운행 중'),
            subtitle: Text(
              isRunning
                  ? _elapsed(bus.startedAt)
                  : isFinished
                  ? '하차 확인 후 운행이 종료되었습니다'
                  : '운행 시작 대기',
            ),
          ),
          if (bus.children.isNotEmpty) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                '탑승 예정 자녀',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
            for (final child in bus.children)
              ListTile(
                dense: true,
                leading: const Icon(Icons.child_care),
                title: Text(child.name),
                subtitle: child.className == null
                    ? null
                    : Text(child.className!),
                trailing: Text(
                  child.isAbsent ? '오늘 결석' : '탑승 예정',
                  style: TextStyle(
                    color: child.isAbsent ? colors.error : colors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _scrollableMessage(Widget child) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [const SizedBox(height: 160), Center(child: child)],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('버스 운행 현황'),
        actions: [
          IconButton(
            tooltip: '새로고침',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<_BusStatusItem>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _scrollableMessage(
                Column(
                  children: [
                    const Text('운행 현황을 불러오지 못했습니다.'),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _refresh,
                      child: const Text('다시 시도'),
                    ),
                  ],
                ),
              );
            }

            final buses = snapshot.data ?? const <_BusStatusItem>[];
            if (buses.isEmpty) {
              return _scrollableMessage(
                const Text('자녀에게 배정된 버스가 없습니다.'),
              );
            }

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                _ChildLocationMap(children: _children),
                const SizedBox(height: 16),
                ...buses.map(_buildBusCard),
                if (_updatedAt != null)
                  Text(
                    '마지막 업데이트 ${_formatTime(_updatedAt)} · 30초마다 자동 갱신',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// 네이버 지도: 등록된 자녀 탑승 위치 마커
class _ChildLocationMap extends StatefulWidget {
  const _ChildLocationMap({required this.children});

  final List<ChildStudent> children;

  @override
  State<_ChildLocationMap> createState() => _ChildLocationMapState();
}

class _ChildLocationMapState extends State<_ChildLocationMap> {
  static const _defaultPosition = NLatLng(37.5665, 126.9780);

  NaverMapController? _controller;

  List<ChildStudent> get _located => widget.children
      .where((child) => child.location?.hasCoordinates ?? false)
      .toList();

  // 자동 갱신 때마다 카메라가 되돌아가지 않도록 위치가 바뀐 경우에만 다시 그린다.
  static String _signature(List<ChildStudent> children) => children
      .where((child) => child.location?.hasCoordinates ?? false)
      .map(
        (child) =>
            '${child.id}:${child.location!.latitude}:${child.location!.longitude}',
      )
      .join('|');

  @override
  void didUpdateWidget(covariant _ChildLocationMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_signature(oldWidget.children) != _signature(widget.children)) {
      _updateOverlays();
    }
  }

  Future<void> _updateOverlays() async {
    final controller = _controller;
    if (controller == null) return;
    final located = _located;

    await controller.clearOverlays();
    if (!mounted || _controller != controller || located.isEmpty) return;

    await controller.addOverlayAll({
      for (final child in located)
        NMarker(
          id: 'child_${child.id}',
          position: NLatLng(
            child.location!.latitude!,
            child.location!.longitude!,
          ),
          caption: NOverlayCaption(text: '${child.name} 탑승 위치'),
        ),
    });

    final first = located.first.location!;
    await controller.updateCamera(
      NCameraUpdate.scrollAndZoomTo(
        target: NLatLng(first.latitude!, first.longitude!),
        zoom: 15,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final located = _located;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '자녀 탑승 위치',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ValueListenableBuilder<String?>(
          valueListenable: naverMapAuthError,
          builder: (context, authError, _) {
            if (authError != null) {
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.map_outlined),
                  title: const Text('지도를 불러오지 못했습니다.'),
                  subtitle: const Text('네이버 지도 인증 설정을 확인해 주세요.'),
                ),
              );
            }
            return SizedBox(
              height: 240,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: NaverMap(
                  options: NaverMapViewOptions(
                    initialCameraPosition: NCameraPosition(
                      target: located.isEmpty
                          ? _defaultPosition
                          : NLatLng(
                              located.first.location!.latitude!,
                              located.first.location!.longitude!,
                            ),
                      zoom: located.isEmpty ? 11 : 15,
                    ),
                    locationButtonEnable: false,
                  ),
                  onMapReady: (controller) async {
                    _controller = controller;
                    await _updateOverlays();
                  },
                ),
              ),
            );
          },
        ),
        if (located.isEmpty) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  '등록된 자녀 탑승 위치가 없습니다.',
                  style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ChildLocationScreen(),
                  ),
                ),
                child: const Text('위치 등록'),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
