import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

import '../../core/maps/naver_map_status.dart';
import '../../data/api/api_repository.dart';
import '../../data/models/child_student.dart';
import 'bus_trip_simulation.dart';
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

/// 학부모 버스 운행 현황
/// - 버스 위치·도착 예정 시간: 테스트 운행(시뮬레이션). 서버에 버스 실시간 GPS 가 없음
/// - 운행 상태·탑승 예정 자녀: 서버 실제 데이터 (GET /me/bus-status + GET /me/children)
/// - 지도에는 테스트 운행 버스와 학부모가 등록한 자녀 탑승 위치를 함께 표시
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

  Widget _messageCard({required IconData icon, required String text, Widget? action}) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(text),
        trailing: action,
      ),
    );
  }

  Widget _sectionTitle(String text, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }

  // ---------- 테스트 운행 (버스 위치 시뮬레이션) ----------
  Widget _buildTestRunSection() {
    final colors = Theme.of(context).colorScheme;
    return ValueListenableBuilder<BusTripStatus>(
      valueListenable: BusTripSimulation.status,
      builder: (context, status, _) {
        return ValueListenableBuilder<double>(
          valueListenable: BusTripSimulation.progress,
          builder: (context, progress, _) {
            final hasStarted = status != BusTripStatus.before;
            final isRunning = status == BusTripStatus.running;
            final isFinished = status == BusTripStatus.finished;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _sectionTitle(
                  '현재 차량 위치',
                  trailing: Chip(
                    label: const Text('테스트 운행'),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: colors.secondaryContainer,
                  ),
                ),
                _TestRunMap(children: _children, progress: progress),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(value: progress, minHeight: 6),
                ),
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    leading: Icon(Icons.access_time, color: colors.primary),
                    title: const Text('예상 도착 시간'),
                    subtitle: const Text('학교 도착까지'),
                    trailing: Text(
                      BusTripSimulation.etaText(status),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(
                          hasStarted
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: hasStarted
                              ? colors.tertiary
                              : colors.onSurfaceVariant,
                        ),
                        title: const Text('운행 시작'),
                        subtitle: Text(
                          hasStarted && BusTripSimulation.startedAt != null
                              ? '${_formatTime(BusTripSimulation.startedAt)} 출발'
                              : '운행 시작 대기',
                        ),
                      ),
                      const Divider(height: 1),
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
                        title: Text(isFinished ? '운행 완료' : '현재 운행 중'),
                        subtitle: Text(
                          isRunning
                              ? '학교로 이동 중 · ${(progress * 100).round()}%'
                              : isFinished
                              ? '운행이 종료되었습니다'
                              : '운행 시작 대기',
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: Icon(
                          isFinished
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: isFinished
                              ? colors.tertiary
                              : colors.onSurfaceVariant,
                        ),
                        title: const Text('학교 도착'),
                        subtitle: Text(isFinished ? '도착 완료' : '도착 대기'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                if (status == BusTripStatus.before)
                  FilledButton.icon(
                    onPressed: BusTripSimulation.startTrip,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('테스트 운행 시작'),
                  ),
                if (isRunning) ...[
                  FilledButton.icon(
                    onPressed: BusTripSimulation.moveBus,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('버스 위치 이동'),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.tonalIcon(
                    onPressed: BusTripSimulation.finishTrip,
                    icon: const Icon(Icons.stop),
                    label: const Text('테스트 운행 종료'),
                  ),
                ],
                if (hasStarted) ...[
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: BusTripSimulation.resetTrip,
                    child: const Text('테스트 운행 초기화'),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  '※ 차량 위치와 도착 예정 시간은 테스트 운행(시뮬레이션) 데이터입니다. '
                  '아래 운행 상태는 서버의 실제 운행 정보입니다.',
                  style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ---------- 실제 운행 상태 (서버) ----------
  Widget _buildRealStatusSection(AsyncSnapshot<List<_BusStatusItem>> snapshot) {
    final colors = Theme.of(context).colorScheme;
    final children = <Widget>[_sectionTitle('운행 상태')];

    if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
      children.add(
        const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    } else if (snapshot.hasError) {
      children.add(
        _messageCard(
          icon: Icons.error_outline,
          text: '운행 현황을 불러오지 못했습니다.',
          action: IconButton(
            tooltip: '다시 시도',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ),
      );
    } else {
      final buses = snapshot.data ?? const <_BusStatusItem>[];
      if (buses.isEmpty) {
        children.add(
          _messageCard(
            icon: Icons.directions_bus_outlined,
            text: '자녀에게 배정된 버스가 없습니다.',
          ),
        );
      } else {
        children.addAll(buses.map(_buildBusCard));
      }
      if (_updatedAt != null) {
        children.add(
          Text(
            '마지막 업데이트 ${_formatTime(_updatedAt)} · 30초마다 자동 갱신',
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  @override
  Widget build(BuildContext context) {
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
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                _buildTestRunSection(),
                const SizedBox(height: 24),
                _buildRealStatusSection(snapshot),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// 네이버 지도: 테스트 운행 경로·버스 위치 + 등록된 자녀 탑승 위치
class _TestRunMap extends StatefulWidget {
  const _TestRunMap({required this.children, required this.progress});

  final List<ChildStudent> children;
  final double progress;

  @override
  State<_TestRunMap> createState() => _TestRunMapState();
}

class _TestRunMapState extends State<_TestRunMap> {
  NaverMapController? _controller;
  NMarker? _busMarker;

  List<ChildStudent> get _located => widget.children
      .where((child) => child.location?.hasCoordinates ?? false)
      .toList();

  static String _signature(List<ChildStudent> children) => children
      .where((child) => child.location?.hasCoordinates ?? false)
      .map(
        (child) =>
            '${child.id}:${child.location!.latitude}:${child.location!.longitude}',
      )
      .join('|');

  @override
  void didUpdateWidget(covariant _TestRunMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_signature(oldWidget.children) != _signature(widget.children)) {
      _drawOverlays();
    } else if (oldWidget.progress != widget.progress) {
      _busMarker?.setPosition(BusTripSimulation.busPosition(widget.progress));
    }
  }

  Future<void> _drawOverlays() async {
    final controller = _controller;
    if (controller == null) return;

    await controller.clearOverlays();
    if (!mounted || _controller != controller) return;

    final route = BusTripSimulation.route;
    final bus = NMarker(
      id: 'test_bus',
      position: BusTripSimulation.busPosition(widget.progress),
      caption: const NOverlayCaption(text: '버스 (테스트 운행)'),
      iconTintColor: Colors.blue,
    );
    _busMarker = bus;

    await controller.addOverlayAll({
      NPolylineOverlay(
        id: 'test_route',
        coords: route,
        color: Colors.blue,
        width: 5,
      ),
      NMarker(
        id: 'route_start',
        position: route.first,
        caption: const NOverlayCaption(text: '출발지'),
      ),
      NMarker(
        id: 'route_school',
        position: route.last,
        caption: const NOverlayCaption(text: '학교'),
      ),
      for (final child in _located)
        NMarker(
          id: 'child_${child.id}',
          position: NLatLng(
            child.location!.latitude!,
            child.location!.longitude!,
          ),
          caption: NOverlayCaption(text: '${child.name} 탑승 위치'),
          iconTintColor: Colors.green,
        ),
      bus,
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ValueListenableBuilder<String?>(
          valueListenable: naverMapAuthError,
          builder: (context, authError, _) {
            if (authError != null) {
              return const Card(
                child: ListTile(
                  leading: Icon(Icons.map_outlined),
                  title: Text('지도를 불러오지 못했습니다.'),
                  subtitle: Text('네이버 지도 인증 설정을 확인해 주세요.'),
                ),
              );
            }
            return SizedBox(
              height: 260,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: NaverMap(
                  options: const NaverMapViewOptions(
                    initialCameraPosition: NCameraPosition(
                      target: NLatLng(37.5605, 126.9745),
                      zoom: 13.5,
                    ),
                    locationButtonEnable: false,
                  ),
                  onMapReady: (controller) async {
                    _controller = controller;
                    await _drawOverlays();
                  },
                ),
              ),
            );
          },
        ),
        if (_located.isEmpty)
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
    );
  }
}
