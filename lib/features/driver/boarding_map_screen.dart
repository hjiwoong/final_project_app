import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

import '../../core/errors/app_error_message.dart';
import '../../core/auth/session.dart';
import '../../core/auth/trip_progress_storage.dart';
import '../../core/maps/naver_map_status.dart';
import '../../core/theme/app_theme.dart';
import '../../data/api/api_repository.dart';
import '../../data/models/child_student.dart';
import '../../data/models/child_location.dart';
import '../../data/models/trip_exit_action.dart';
import '../../data/models/trip_progress.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/trip_exit_sheet.dart';
import 'boarding_capture_screen.dart';

import '../../core/notifications/in_app_notification_banner.dart';

/// ② 탑승 지도: 네이버 지도 + 정류장 마커 + 학부모 출결 반영 UI (스크린샷 스타일)
class BoardingMapScreen extends StatefulWidget {
  final String tripId;
  final int busId;
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
  double _expandedSheetSize = 0.3;
  List<Map<String, dynamic>> _stops = [];
  final List<NMarker> _stopMarkers = [];
  final List<int> _stopMarkerStopIndices = [];
  final Map<Color, NOverlayImage> _markerIcons = {};

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
    final expandedContentThreshold =
        _collapsedSheetSize + (_expandedSheetSize - _collapsedSheetSize) * 0.8;
    final isCollapsed = _sheetController.size < expandedContentThreshold;
    if (isCollapsed != _isSheetCollapsed) {
      setState(() => _isSheetCollapsed = isCollapsed);
    }
  }

  Future<void> _toggleSheet() async {
    if (!_sheetController.isAttached) return;
    await _animateSheet(expanded: _isSheetCollapsed);
  }

  Future<void> _animateSheet({required bool expanded}) async {
    if (!_sheetController.isAttached) return;
    await _sheetController.animateTo(
      expanded ? _expandedSheetSize : _collapsedSheetSize,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  void _onSheetDragUpdate(DragUpdateDetails details, double availableHeight) {
    if (!_sheetController.isAttached) return;
    final nextSize =
        (_sheetController.size - details.delta.dy / availableHeight)
            .clamp(_collapsedSheetSize, _expandedSheetSize)
            .toDouble();
    _sheetController.jumpTo(nextSize);
  }

  void _onSheetDragEnd(DragEndDetails details) {
    if (!_sheetController.isAttached) return;
    final velocity = details.primaryVelocity ?? 0;
    if (velocity < -250) {
      _animateSheet(expanded: true);
    } else if (velocity > 250) {
      _animateSheet(expanded: false);
    } else {
      final midpoint = (_collapsedSheetSize + _expandedSheetSize) / 2;
      _animateSheet(expanded: _sheetController.size >= midpoint);
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
      );
      if (!mounted) return;
      setState(() {
        _stops = _makeStops(context, students);
        _currentStopIndex = _currentStopIndex
            .clamp(0, _stops.length - 1)
            .toInt();
        _currentStopIndex = _nextAvailableStopIndex(_currentStopIndex);
        _loadingStops = false;
      });
    } catch (e) {
      debugPrint('탑승 지도 학생/자녀 위치 조회 실패: $e');
      if (!mounted) return;
      setState(() {
        _loadError = '탑승 지도 정보를 불러오지 못했습니다. 서버 연결과 위치 설정을 확인해 주세요.';
        _loadingStops = false;
      });
    }
  }

  List<Map<String, dynamic>> _makeStops(
    BuildContext context,
    List<ChildStudent> students,
  ) {
    return [
      for (final (index, student) in students.indexed)
        {
          'title': '${index + 1}번 정류장 도착',
          'student': '${student.name} · ${student.className ?? '학급 정보 없음'}',
          'status': student.isAbsent ? '결석 · 건너뜀' : '승차 대기',
          'statusColor': student.isAbsent
              ? Theme.of(context).colorScheme.onSurfaceVariant
              : Theme.of(context).colorScheme.tertiary,
          'isAbsent': student.isAbsent,
          'studentId': student.id,
          'location': student.location,
        },
      {
        'title': '종점 도착 · 마지막 정류장',
        'student': '탑승 예정 ${students.length}명',
        'status': '종점',
        'statusColor': Theme.of(context).colorScheme.primary,
        'location': null,
      },
    ];
  }

  List<NLatLng> get _stopPositions => [
    for (final stop in _stops)
      if ((stop['location'] as ChildLocation?)?.hasCoordinates == true)
        NLatLng(
          (stop['location'] as ChildLocation).latitude!,
          (stop['location'] as ChildLocation).longitude!,
        ),
  ];

  Color _markerColor(BuildContext context, int index) {
    final colorScheme = Theme.of(context).colorScheme;
    if (_stops[index]['isAbsent'] == true) return colorScheme.onSurfaceVariant;
    if (index == _stops.length - 1) return colorScheme.primary;
    return index < _currentStopIndex ? colorScheme.tertiary : colorScheme.error;
  }

  Future<NOverlayImage> _markerIcon(BuildContext context, int stopIndex) async {
    final color = _markerColor(context, stopIndex);
    final cachedIcon = _markerIcons[color];
    if (cachedIcon != null) return cachedIcon;

    final icon = await NOverlayImage.fromWidget(
      context: context,
      size: const Size(48, 48),
      widget: Stack(
        alignment: Alignment.center,
        children: [
          const Icon(Icons.location_on, size: 48, color: Colors.white),
          Icon(Icons.location_on, size: 38, color: color),
        ],
      ),
    );
    _markerIcons[color] = icon;
    return icon;
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
      final location = stop['location'] as ChildLocation?;
      if (location == null || !location.hasCoordinates) continue;
      _stopMarkers.add(
        NMarker(
          id: 'boarding_stop_${stop['studentId']}',
          position: NLatLng(location.latitude!, location.longitude!),
          icon: await _markerIcon(context, stopIndex),
          caption: NOverlayCaption(text: '${stopIndex + 1}번 정류장'),
        ),
      );
      _stopMarkerStopIndices.add(stopIndex);
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
        marker.setIcon(
          await _markerIcon(context, _stopMarkerStopIndices[index]),
        );
      }
      await widget.onStopChanged?.call(_currentStopIndex);
    } else {
      await _confirmPassengerNavigation();
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
          currentStopIndex: _currentStopIndex,
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
      setState(() => _allowPop = true);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      Navigator.of(context).pop(TripExitAction.cancel);
    } catch (e) {
      if (!mounted) return;
      InAppNotificationBanner.showMessage(
        AppErrorMessage.from(e, fallback: '운행을 취소하지 못했습니다. 다시 시도해 주세요.'),
      );
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
          final collapsedSheetSize = (78 / constraints.maxHeight)
              .clamp(0.1, 0.3)
              .toDouble();
          final expandedSheetSize = (188 / constraints.maxHeight)
              .clamp(collapsedSheetSize + 0.05, 0.5)
              .toDouble();
          _collapsedSheetSize = collapsedSheetSize;
          _expandedSheetSize = expandedSheetSize;
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
                  nightModeEnable:
                      Theme.of(context).brightness == Brightness.dark,
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
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(
                            context,
                          ).colorScheme.shadow.withValues(alpha: 0.1),
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
                            _buildLegendDot(
                              Theme.of(context).colorScheme.error,
                              '출석 대기',
                            ),
                            const SizedBox(width: 14),
                            _buildLegendDot(
                              Theme.of(context).colorScheme.tertiary,
                              '승차 완료',
                            ),
                            const SizedBox(width: 14),
                            _buildLegendDot(
                              Theme.of(context).colorScheme.onSurfaceVariant,
                              '결석',
                            ),
                          ],
                        ),
                        if (stopPositions.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '등록된 자녀 주소 위치',
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        if (stopPositions.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '자녀 좌표가 없어 기본 위치의 지도를 표시합니다.',
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
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
                    color: Theme.of(context).colorScheme.surface,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        _mapError!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
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
                      color: Theme.of(context).colorScheme.surface,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          '네이버 지도 인증에 실패했습니다: $authError\nNCP 콘솔의 Client ID, Dynamic Map 활성화, Android 패키지 등록을 확인해 주세요.',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
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
                builder: (context, _) {
                  return Padding(
                    padding: AppTheme.sheetMargin,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onVerticalDragUpdate: (details) =>
                          _onSheetDragUpdate(details, constraints.maxHeight),
                      onVerticalDragEnd: _onSheetDragEnd,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          decoration: AppTheme.sheetDecoration(
                            context,
                            radius: 20,
                          ),
                          child: Column(
                            children: [
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    18,
                                    12,
                                    18,
                                    8,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Semantics(
                                        button: true,
                                        label: _isSheetCollapsed
                                            ? '정류장 정보 패널 펼치기'
                                            : '정류장 정보 패널 접기',
                                        child: GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onTap: _toggleSheet,
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  if (isLast) ...[
                                                    Icon(
                                                      Icons.school,
                                                      color: Theme.of(
                                                        context,
                                                      ).colorScheme.primary,
                                                      size: 20,
                                                    ),
                                                    const SizedBox(width: 4),
                                                  ] else ...[
                                                    Icon(
                                                      Icons.location_on,
                                                      color: Theme.of(
                                                        context,
                                                      ).colorScheme.error,
                                                      size: 20,
                                                    ),
                                                    const SizedBox(width: 4),
                                                  ],
                                                  Expanded(
                                                    child: Text(
                                                      stop['title'],
                                                      style: const TextStyle(
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 4,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color:
                                                          (stop['statusColor']
                                                                  as Color)
                                                              .withValues(
                                                                alpha: 0.1,
                                                              ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      stop['status'],
                                                      style: TextStyle(
                                                        color:
                                                            stop['statusColor'],
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              Visibility(
                                                visible: !_isSheetCollapsed,
                                                maintainState: true,
                                                maintainAnimation: true,
                                                maintainSize: true,
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      stop['student'],
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .onSurfaceVariant,
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                    if (!isLast) ...[
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        '탑승 버스 : ${widget.busName}',
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          color: Theme.of(context)
                                                              .colorScheme
                                                              .onSurfaceVariant,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (!_isSheetCollapsed)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    18,
                                    0,
                                    18,
                                    10,
                                  ),
                                  child: PrimaryButton(
                                    label: isLast ? '탑승 완료' : '승차 완료',
                                    onPressed: _nextStop,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
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

  Future<void> _confirmPassengerNavigation() async {
    final shouldContinue = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: false,
      isDismissible: false,
      enableDrag: false,
      builder: (context) => SafeArea(
        top: false,
        child: Container(
          margin: AppTheme.sheetMargin,
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          decoration: AppTheme.sheetDecoration(context),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '탑승 완료',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Text(
                '모든 승객이 전부 탑승했는지 확인해 주세요. 예를 터치하면 돌아갈 수 없습니다.',
                style: TextStyle(
                  fontSize: 15,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('아니요'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('예'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (shouldContinue != true || !mounted) return;

    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const BoardingCaptureScreen()));
  }

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
