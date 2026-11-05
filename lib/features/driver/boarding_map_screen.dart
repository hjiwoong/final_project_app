import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

import '../../core/auth/session.dart';
import '../../core/auth/trip_progress_storage.dart';
import '../../core/maps/naver_map_status.dart';
import '../../data/api/api_repository.dart';
import '../../data/models/child_student.dart';
import '../../data/models/guardian_location.dart';
import '../../data/models/trip_exit_action.dart';
import '../../data/models/trip_progress.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/trip_exit_sheet.dart';
import 'boarding_capture_screen.dart';

/// ② 탑승 지도: 네이버 지도 + 정류장 마커 + 학부모 출결 반영 UI (스크린샷 스타일)
class BoardingMapScreen extends StatefulWidget {
  final String tripId;
  final int busId;
  final bool isMock;
  final String busName;
  final String busNumber;
  final int initialStopIndex;
  final Future<void> Function(int index)? onStopChanged;

  const BoardingMapScreen({
    super.key,
    required this.tripId,
    required this.busId,
    required this.busName,
    required this.busNumber,
    this.isMock = false,
    this.initialStopIndex = 0,
    this.onStopChanged,
  });

  @override
  State<BoardingMapScreen> createState() => _BoardingMapScreenState();
}

class _BoardingMapScreenState extends State<BoardingMapScreen> {
  static const _defaultMapPosition = NLatLng(37.5665, 126.9780);

  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  late int _currentStopIndex;
  bool _isSheetCollapsed = false;
  bool _allowPop = false;
  bool _exitDialogOpen = false;
  bool _loadingStops = true;
  bool _mapLoaded = false;
  String? _loadError;
  String? _mapError;
  Timer? _mapLoadTimer;
  double _collapsedSheetSize = 0.12;
  List<Map<String, dynamic>> _stops = [];
  final List<NMarker> _stopMarkers = [];
  final List<int> _stopMarkerStopIndices = [];

  @override
  void initState() {
    super.initState();
    _currentStopIndex = widget.initialStopIndex;
    _sheetController.addListener(_updateSheetState);
    _loadStops();
  }

  @override
  void dispose() {
    _mapLoadTimer?.cancel();
    _sheetController
      ..removeListener(_updateSheetState)
      ..dispose();
    super.dispose();
  }

  void _updateSheetState() {
    if (!_sheetController.isAttached) return;
    final isCollapsed = _sheetController.size <= _collapsedSheetSize + 0.01;
    if (isCollapsed != _isSheetCollapsed) {
      setState(() => _isSheetCollapsed = isCollapsed);
    }
  }

  Future<void> _loadStops() async {
    setState(() {
      _loadingStops = true;
      _loadError = null;
    });
    try {
      final students = await ApiRepository.instance.getTripBoardingMapStudents(
        int.parse(widget.tripId),
        isMock: widget.isMock,
      );
      if (!mounted) return;
      setState(() {
        _stops = _makeStops(students);
        _currentStopIndex = _currentStopIndex
            .clamp(0, _stops.length - 1)
            .toInt();
        _currentStopIndex = _nextAvailableStopIndex(_currentStopIndex);
        _loadingStops = false;
      });
    } catch (e) {
      debugPrint('탑승 지도 학생/보호자 위치 조회 실패: $e');
      if (!mounted) return;
      setState(() {
        _loadError = '탑승 지도 정보를 불러오지 못했습니다. 서버 연결과 위치 설정을 확인해 주세요.';
        _loadingStops = false;
      });
    }
  }

  List<Map<String, dynamic>> _makeStops(List<ChildStudent> students) {
    return [
      for (final (index, student) in students.indexed)
        {
          'title': '📍 ${index + 1}번 정류장 도착',
          'student': '${student.name} · ${student.className ?? '학급 정보 없음'}',
          'status': student.isAbsent ? '결석 · 건너뜀' : '승차 대기',
          'statusColor': student.isAbsent ? Colors.grey : Colors.green,
          'isAbsent': student.isAbsent,
          'studentId': student.id,
          'guardianLocations': student.guardianLocations,
        },
      {
        'title': '🏫 종점 도착 · 마지막 정류장',
        'student': '탑승 예정 ${students.length}명',
        'status': '종점',
        'statusColor': Colors.blue,
        'guardianLocations': const <GuardianLocation>[],
      },
    ];
  }

  List<NLatLng> get _stopPositions => [
    for (final stop in _stops)
      for (final location
          in stop['guardianLocations'] as List<GuardianLocation>)
        if (location.hasCoordinates)
          NLatLng(location.latitude!, location.longitude!),
  ];

  Color _markerColor(int index) {
    if (_stops[index]['isAbsent'] == true) return Colors.grey;
    if (index == _stops.length - 1) return Colors.blue;
    return index < _currentStopIndex ? Colors.green : Colors.red;
  }

  int _nextAvailableStopIndex(int index) {
    final lastStopIndex = _stops.length - 1;
    while (index < lastStopIndex && _stops[index]['isAbsent'] == true) {
      index++;
    }
    return index;
  }

  Future<void> _addMapOverlays(NaverMapController controller) async {
    _stopMarkers.clear();
    _stopMarkerStopIndices.clear();
    for (final (stopIndex, stop) in _stops.indexed) {
      final locations = stop['guardianLocations'] as List<GuardianLocation>;
      for (final (locationIndex, location) in locations.indexed) {
        if (!location.hasCoordinates) continue;
        _stopMarkers.add(
          NMarker(
            id: 'boarding_stop_${stop['studentId']}_$locationIndex',
            position: NLatLng(location.latitude!, location.longitude!),
            iconTintColor: _markerColor(stopIndex),
            caption: NOverlayCaption(
              text: '${stopIndex + 1}번 정류장 · 보호자 ${locationIndex + 1}',
            ),
          ),
        );
        _stopMarkerStopIndices.add(stopIndex);
      }
    }
    if (_stopMarkers.isNotEmpty) {
      await controller.addOverlayAll(_stopMarkers.toSet());
    }
  }

  Future<void> _nextStop() async {
    if (_currentStopIndex < _stops.length - 1) {
      setState(() {
        _currentStopIndex = _nextAvailableStopIndex(_currentStopIndex + 1);
      });
      for (final (index, marker) in _stopMarkers.indexed) {
        marker.setIconTintColor(_markerColor(_stopMarkerStopIndices[index]));
      }
      await widget.onStopChanged?.call(_currentStopIndex);
    } else {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const BoardingCaptureScreen()));
    }
  }

  Future<void> _requestExit() async {
    if (_exitDialogOpen) return;
    _exitDialogOpen = true;
    final action = await showTripExitSheet(context);
    _exitDialogOpen = false;
    if (!mounted || action == null) return;

    if (action == TripExitAction.wait) {
      await TripProgressStorage.save(
        TripProgress(
          tripId: int.parse(widget.tripId),
          busId: widget.busId,
          busName: widget.busName,
          busNumber: widget.busNumber,
          isMock: widget.isMock,
          currentStopIndex: _currentStopIndex,
          simulationMode: Session.currentTripSimulationMode,
        ),
      );
      setState(() => _allowPop = true);
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) Navigator.of(context).pop(TripExitAction.wait);
      return;
    }

    try {
      await ApiRepository.instance.cancelTrip(int.parse(widget.tripId));
      await TripProgressStorage.clear();
      if (!mounted) return;
      Session.currentTripId = null;
      Session.currentTripBusName = null;
      Session.currentBoardingCount = null;
      Session.currentTripIsMock = false;
      Session.currentTripSimulationMode = false;
      setState(() => _allowPop = true);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      Navigator.of(context).pop(TripExitAction.cancel);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('운행을 취소하지 못했습니다. ($e)')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _requestExit();
      },
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_loadingStops || _loadError != null || _stops.isEmpty) {
      return Scaffold(
        appBar: _buildAppBar(),
        body: Center(
          child: _loadingStops
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_loadError ?? '학생 정보가 없습니다.'),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _loadStops,
                      child: const Text('다시 시도'),
                    ),
                  ],
                ),
        ),
      );
    }

    final stop = _stops[_currentStopIndex];
    final isLast = _currentStopIndex == _stops.length - 1;

    return Scaffold(
      appBar: _buildAppBar(),
      body: LayoutBuilder(
        builder: (context, constraints) {
          //상한 설정값 - 접었을 때
          final collapsedSheetSize = (107 / constraints.maxHeight)
              .clamp(0.1, 0.3)
              .toDouble();
          //올렸을 때
          final expandedSheetSize = (172 / constraints.maxHeight)
              .clamp(collapsedSheetSize + 0.05, 0.5)
              .toDouble();
          _collapsedSheetSize = collapsedSheetSize;
          final stopPositions = _stopPositions;

          return Stack(
            children: [
              NaverMap(
                options: NaverMapViewOptions(
                  initialCameraPosition: NCameraPosition(
                    target: stopPositions.isNotEmpty
                        ? stopPositions.first
                        : _defaultMapPosition,
                    zoom: stopPositions.isNotEmpty ? 14.5 : 11.5,
                  ),
                  locationButtonEnable: true,
                ),
                onMapReady: (controller) async {
                  debugPrint('네이버 지도 로딩 완료');
                  _mapLoadTimer?.cancel();
                  _mapLoadTimer = Timer(const Duration(seconds: 15), () {
                    if (!mounted || _mapLoaded) return;
                    setState(() {
                      _mapError =
                          '지도를 불러오지 못했습니다. 네이버 지도 Client ID와 앱 패키지 등록, 네트워크 연결을 확인해 주세요.';
                    });
                  });
                  try {
                    await _addMapOverlays(controller);
                  } catch (error) {
                    debugPrint('탑승 지도 마커 표시 실패: $error');
                    if (mounted) {
                      setState(() => _mapError = '정류장 위치를 지도에 표시하지 못했습니다.');
                    }
                  }
                },
                onMapLoaded: () {
                  _mapLoadTimer?.cancel();
                  if (!mounted) return;
                  setState(() {
                    _mapLoaded = true;
                    _mapError = null;
                  });
                },
              ),
              Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildLegendDot(Colors.red, '출석 대기'),
                            const SizedBox(width: 14),
                            _buildLegendDot(Colors.green, '승차 완료'),
                            const SizedBox(width: 14),
                            _buildLegendDot(Colors.grey, '결석'),
                          ],
                        ),
                        if (stopPositions.isNotEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Text(
                              '보호자가 저장한 실제 위치',
                              style: TextStyle(
                                color: Colors.black54,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        if (stopPositions.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Text(
                              '보호자 좌표가 없어 기본 위치의 지도를 표시합니다.',
                              style: TextStyle(
                                color: Colors.black54,
                                fontSize: 11,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              if (_mapError != null)
                Positioned(
                  top: 76,
                  left: 16,
                  right: 16,
                  child: Card(
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        _mapError!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ValueListenableBuilder<String?>(
                valueListenable: naverMapAuthError,
                builder: (context, authError, child) {
                  if (authError == null) return const SizedBox.shrink();
                  return Positioned(
                    top: 76,
                    left: 16,
                    right: 16,
                    child: Card(
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          '네이버 지도 인증에 실패했습니다: $authError\nNCP 콘솔의 Client ID, Dynamic Map 활성화, Android 패키지 등록을 확인해 주세요.',
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  );
                },
              ),
              DraggableScrollableSheet(
                controller: _sheetController,
                initialChildSize: expandedSheetSize,
                minChildSize: collapsedSheetSize,
                maxChildSize: expandedSheetSize,
                snap: true,
                snapSizes: [collapsedSheetSize, expandedSheetSize],
                builder: (context, scrollController) {
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 10,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
                      children: [
                        Center(
                          child: Semantics(
                            label: '정류장 정보 패널을 위아래로 밀어 지도 보기',
                            child: Container(
                              width: 40,
                              height: 5,
                              decoration: BoxDecoration(
                                color: Colors.blueGrey.shade200,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      stop['title'],
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: (stop['statusColor'] as Color)
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      stop['status'],
                                      style: TextStyle(
                                        color: stop['statusColor'],
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                stop['student'],
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (!isLast) ...[
                                const SizedBox(height: 4),
                                Text(
                                  '탑승 버스 : ${widget.busName}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade700,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              if (!_isSheetCollapsed) ...[
                                const SizedBox(height: 10),
                                PrimaryButton(
                                  label: isLast ? '탑승 완료' : '승차 완료',
                                  onPressed: _nextStop,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  AppBar _buildAppBar() => AppBar(
    leading: TextButton(onPressed: _requestExit, child: const Text('취소')),
    title: const Text('탑승 지도'),
    elevation: 0,
  );

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
