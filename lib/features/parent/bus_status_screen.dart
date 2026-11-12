import 'package:flutter/material.dart';
import '../../core/auth/session.dart';
import '../../core/config/env.dart';
import '../../data/api/api_repository.dart';
import 'bus_trip_mock_store.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

// 학부모 버스 운행 현황 (Mock 데이터)
class BusStatusScreen extends StatefulWidget {
  const BusStatusScreen({super.key});

  @override
  State<BusStatusScreen> createState() => _BusStatusScreenState();
}

class _BusStatusScreenState extends State<BusStatusScreen> {
  late Future<List<Map<String, dynamic>>> _busStatusFuture;

  @override
  void initState() {
    super.initState();
    _loadBusStatus();
  }

  void _loadBusStatus() {
    _busStatusFuture = ApiRepository.instance.getParentBusStatus();
  }

  void _refreshBusStatus() {
    setState(() {
      _loadBusStatus();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('버스 운행 현황'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshBusStatus,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 버스 운행 상태 (Mock)

          // 학부모에게 배정된 버스 운행 현황 (실제 API)
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _busStatusFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.error_outline),
                    title: const Text('버스 정보를 불러오지 못했습니다'),
                    subtitle: Text('${snapshot.error}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _refreshBusStatus,
                    ),
                  ),
                );
              }

              final buses = snapshot.data ?? [];

              if (buses.isEmpty) {
                return const Card(
                  child: ListTile(
                    leading: Icon(Icons.directions_bus),
                    title: Text('조회된 버스가 없습니다'),
                    subtitle: Text('자녀의 버스 배정 또는 로그인 상태를 확인해 주세요.'),
                  ),
                );
              }

              return Column(
                children: buses.map((bus) {
                  final isRunning = bus['status'] == 'IN_PROGRESS';

                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.directions_bus, size: 32),
                      title: Text(bus['bus_name']?.toString() ?? '버스'),
                      subtitle: Text('차량번호: ${bus['plate_no'] ?? '-'}'),
                      trailing: Chip(
                        label: Text(isRunning ? '운행 중' : '운행 중 아님'),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),

          const SizedBox(height: 16),

          const Text(
            '현재 차량 위치',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 8),

          // 실제 네이버 지도 + Mock 버스 위치
          ValueListenableBuilder<double>(
            valueListenable: BusTripMockStore.progress,
            builder: (context, progress, child) {
              return _NaverMockBusMap(progress: progress);
            },
          ),

          const SizedBox(height: 16),

          // 예상 도착 시간
          ValueListenableBuilder<double>(
            valueListenable: BusTripMockStore.progress,
            builder: (context, progress, child) {
              return ValueListenableBuilder<BusTripStatus>(
                valueListenable: BusTripMockStore.status,
                builder: (context, status, child) {
                  return Card(
                    child: ListTile(
                      leading: const Icon(
                        Icons.access_time,
                        color: Colors.blue,
                      ),
                      title: const Text('예상 도착 시간'),
                      subtitle: const Text('학교 도착까지'),
                      trailing: Text(
                        BusTripMockStore.getEtaText(status),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),

          const SizedBox(height: 16),

          const Text(
            '운행 진행 상황',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 8),

          // 운행 진행 상황 (Mock)
          if (Env.useMock || Session.isMockAccount)
            ValueListenableBuilder<BusTripStatus>(
              valueListenable: BusTripMockStore.status,
              builder: (context, status, child) {
                final hasStarted = status != BusTripStatus.before;
                final isRunning = status == BusTripStatus.running;
                final isFinished = status == BusTripStatus.finished;

                return Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(
                          hasStarted
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: hasStarted ? Colors.green : Colors.grey,
                        ),
                        title: const Text('운행 시작'),
                        subtitle: Text(
                          hasStarted ? '오전 8:10 (Mock)' : '운행 시작 대기',
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
                              ? Colors.blue
                              : isFinished
                              ? Colors.green
                              : Colors.grey,
                        ),
                        title: Text(isFinished ? '운행 완료' : '현재 운행 중'),
                        subtitle: Text(
                          isRunning
                              ? '학교로 이동 중'
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
                          color: isFinished ? Colors.green : Colors.grey,
                        ),
                        title: const Text('학교 도착'),
                        subtitle: Text(isFinished ? '도착 완료 (Mock)' : '도착 대기'),
                      ),
                    ],
                  ),
                );
              },
            )
          else
            const Card(
              child: ListTile(
                leading: Icon(Icons.directions_bus_outlined),
                title: Text('운행 진행 상황'),
                subtitle: Text('상세 운행 단계 정보는 준비 중입니다.'),
              ),
            ),
          const SizedBox(height: 16),

          // Mock 버스 위치 이동 테스트 버튼
          ValueListenableBuilder<BusTripStatus>(
            valueListenable: BusTripMockStore.status,
            builder: (context, status, child) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (status == BusTripStatus.before)
                    ElevatedButton.icon(
                      onPressed: BusTripMockStore.startTrip,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('운행 시작 테스트'),
                    ),

                  if (status == BusTripStatus.running)
                    ElevatedButton.icon(
                      onPressed: BusTripMockStore.moveBus,
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('버스 위치 이동 테스트'),
                    ),

                  if (status == BusTripStatus.running)
                    const SizedBox(height: 8),

                  if (status == BusTripStatus.running)
                    ElevatedButton.icon(
                      onPressed: BusTripMockStore.finishTrip,
                      icon: const Icon(Icons.stop),
                      label: const Text('운행 종료 테스트'),
                    ),

                  const SizedBox(height: 8),

                  OutlinedButton(
                    onPressed: BusTripMockStore.resetTrip,
                    child: const Text('운행 상태 초기화'),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 16),

          const Text(
            '※ 현재 표시되는 차량 위치와 도착 시간은 테스트 데이터입니다.',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// 네이버 지도 + 테스트용 버스 위치
class _NaverMockBusMap extends StatefulWidget {
  final double progress;

  const _NaverMockBusMap({required this.progress});

  @override
  State<_NaverMockBusMap> createState() => _NaverMockBusMapState();
}

class _NaverMockBusMapState extends State<_NaverMockBusMap> {
  NaverMapController? _controller;

  static const List<NLatLng> _route = [
    NLatLng(37.5547, 126.9707), // 출발지
    NLatLng(37.5598, 126.9753), // 남대문
    NLatLng(37.5640, 126.9770), // 시청역
    NLatLng(37.5663, 126.9784), // 도착지
  ];

  NLatLng _getBusPosition(double progress) {
    final p = progress.clamp(0.0, 1.0).toDouble();
    final scaled = p * (_route.length - 1);
    final index = scaled.floor();

    if (index >= _route.length - 1) {
      return _route.last;
    }

    final ratio = scaled - index;
    final start = _route[index];
    final end = _route[index + 1];

    return NLatLng(
      start.latitude + (end.latitude - start.latitude) * ratio,
      start.longitude + (end.longitude - start.longitude) * ratio,
    );
  }

  Future<void> _updateOverlays() async {
    final controller = _controller;
    if (controller == null) return;

    final busPosition = _getBusPosition(widget.progress);

    await controller.clearOverlays();

    if (!mounted || _controller != controller) return;

    await controller.addOverlayAll({
      NMarker(
        id: 'mock_start',
        position: _route.first,
        caption: const NOverlayCaption(text: '출발지'),
      ),
      NMarker(
        id: 'mock_destination',
        position: _route.last,
        caption: const NOverlayCaption(text: '도착지'),
      ),
      NMarker(
        id: 'mock_bus',
        position: busPosition,
        caption: const NOverlayCaption(text: '버스 (Mock)'),
      ),
      NPolylineOverlay(
        id: 'mock_route',
        coords: _route,
        color: Colors.blue,
        width: 5,
      ),
    });
  }

  @override
  void didUpdateWidget(covariant _NaverMockBusMap oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.progress != widget.progress) {
      _updateOverlays();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 260,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: NaverMap(
          options: const NaverMapViewOptions(
            initialCameraPosition: NCameraPosition(
              target: NLatLng(37.5615, 126.9755),
              zoom: 13.5,
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
  }
}

// 지도 위의 위치 표시

// 지도 배경 도로와 버스 이동 경로 그리기
