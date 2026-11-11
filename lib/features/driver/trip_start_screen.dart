import 'package:flutter/material.dart';

import '../../core/errors/app_error_message.dart';
import '../../core/auth/session.dart';
import '../../core/auth/trip_progress_storage.dart';
import '../../core/theme/app_theme.dart';
import '../../data/api/api_repository.dart';
import '../../data/models/trip_exit_action.dart';
import '../../data/models/trip_progress.dart';
import 'boarding_capture_screen.dart';
import 'boarding_map_screen.dart';

import '../../core/notifications/in_app_notification_banner.dart';

/// 버스 및 운행(Trip) 정보 모델
class BusTripItem {
  final String tripId;
  final String busNumber;
  final String busName;
  final String routeName;
  final int studentCount;
  final bool isMock;
  final bool simulationMode;

  bool get isSimulationBus =>
      simulationMode ||
      busName == '개발용' ||
      busNumber.toUpperCase().startsWith('TEST-');

  BusTripItem({
    required this.tripId,
    required this.busNumber,
    required this.busName,
    required this.routeName,
    required this.studentCount,
    this.isMock = false,
    this.simulationMode = false,
  });

  factory BusTripItem.fromJson(Map<String, dynamic> json) {
    return BusTripItem(
      tripId: json['tripId'] ?? '',
      busNumber: json['busNumber'] ?? '',
      busName: json['busName'] ?? '',
      routeName: json['routeName'] ?? '',
      studentCount: json['studentCount'] ?? 0,
      isMock: json['is_mock'] == true,
      simulationMode: json['simulation_mode'] == true,
    );
  }
}

class TripStartScreen extends StatefulWidget {
  const TripStartScreen({super.key});

  @override
  State<TripStartScreen> createState() => _TripStartScreenState();
}

class _TripStartScreenState extends State<TripStartScreen> {
  bool _isLoadingTrips = true;
  bool _isStartingTrip = false;
  String? _loadError;
  List<BusTripItem> _trips = [];
  BusTripItem? _activeTrip;
  TripProgress? _activeProgress;
  bool _boardingRecoveryPromptShown = false;

  @override
  void initState() {
    super.initState();
    _fetchTodayTrips();
  }

  /// ① 버스 목록 및 운행 정보 조회 (GET /web/buses)
  Future<void> _fetchTodayTrips({bool showLoading = true}) async {
    setState(() {
      if (showLoading) {
        _isLoadingTrips = true;
        _trips = [];
        _activeTrip = null;
      }
      _loadError = null;
    });

    try {
      final buses = await ApiRepository.instance.getBuses();
      final savedProgress = await TripProgressStorage.read();
      final currentTrip = await ApiRepository.instance.getCurrentTrip();
      final loadedTrips = buses
          .map(
            (b) => BusTripItem(
              tripId: b['id'].toString(),
              busNumber: b['plate_no'] ?? '',
              busName: b['name'] ?? '',
              routeName: '학교 → 종점',
              studentCount: b['student_count'] ?? 0,
              isMock: b['is_mock'] == true,
            ),
          )
          .toList();

      BusTripItem? activeTrip;
      TripProgress? activeProgress;
      if (currentTrip != null) {
        final busId = currentTrip['bus_id'] as int;
        final bus = buses.where((item) => item['id'] == busId).firstOrNull;
        activeTrip = BusTripItem(
          tripId: currentTrip['id'].toString(),
          busNumber:
              bus?['plate_no'] as String? ??
              currentTrip['plate_no'] as String? ??
              '',
          busName:
              bus?['name'] as String? ??
              currentTrip['bus_name'] as String? ??
              '운행 중인 버스',
          routeName: '학교 → 종점',
          studentCount:
              bus?['student_count'] as int? ??
              currentTrip['expected_count'] as int? ??
              0,
          simulationMode: currentTrip['simulation_mode'] as bool? ?? false,
        );
        final TripProgress restoredProgress;
        final simulationMode =
            currentTrip['simulation_mode'] as bool? ??
            savedProgress?.simulationMode ??
            activeTrip.isSimulationBus;
        if (savedProgress != null &&
            savedProgress.tripId == currentTrip['id']) {
          restoredProgress = savedProgress.copyWith(
            simulationMode: simulationMode,
          );
        } else {
          restoredProgress = TripProgress(
            tripId: currentTrip['id'] as int,
            busId: busId,
            busName: activeTrip.busName,
            busNumber: activeTrip.busNumber,
            isMock: false,
            currentStopIndex: 0,
            simulationMode: simulationMode,
          );
        }
        activeProgress = restoredProgress;
        await TripProgressStorage.save(restoredProgress);
      } else if (savedProgress != null && savedProgress.isMock) {
        final mockProgress = savedProgress;
        activeProgress = mockProgress;
        activeTrip = BusTripItem(
          tripId: mockProgress.tripId.toString(),
          busNumber: mockProgress.busNumber,
          busName: mockProgress.busName,
          routeName: '학교 → 종점',
          studentCount: 0,
          isMock: true,
        );
      } else {
        await TripProgressStorage.clear();
      }

      if (!mounted) return;
      setState(() {
        _trips = loadedTrips;
        _activeTrip = activeTrip;
        _activeProgress = activeProgress;
        _isLoadingTrips = false;
      });
      if (activeProgress?.boardingCount != null) {
        await _promptForBoardingRecovery();
      }
    } catch (e) {
      debugPrint('버스 목록 조회 실패: $e');
      if (!mounted) return;
      setState(() {
        _loadError = '버스 목록을 불러오지 못했습니다.\n연결을 확인하고 다시 시도해 주세요.';
        _isLoadingTrips = false;
      });
    }
  }

  Future<void> _resumeTrip() async {
    final trip = _activeTrip;
    final progress = _activeProgress;
    if (trip == null || progress == null || _isStartingTrip) return;

    Session.currentTripId = progress.tripId;
    Session.currentTripBusName = progress.busName;
    Session.currentBoardingCount = progress.boardingCount;
    Session.currentTripIsMock = progress.isMock;
    Session.currentTripSimulationMode = progress.simulationMode;
    final result = await Navigator.of(context).push<Object?>(
      MaterialPageRoute(
        builder: (_) => progress.boardingCount != null
            ? BoardingCaptureScreen(
                initialPhotoGuidance: progress.boardingPhotoGuidance,
              )
            : BoardingMapScreen(
                tripId: progress.tripId.toString(),
                busId: progress.busId,
                busName: progress.busName,
                busNumber: progress.busNumber,
                isMock: progress.isMock,
                initialStopIndex: progress.currentStopIndex,
                onStopChanged: (index) {
                  final updated = progress.copyWith(currentStopIndex: index);
                  _activeProgress = updated;
                  return TripProgressStorage.save(updated);
                },
              ),
      ),
    );
    if (!mounted) return;
    await _fetchTodayTrips(showLoading: false);
    if (result == TripExitAction.cancel && mounted) {
      InAppNotificationBanner.showMessage('운행을 취소했습니다.');
    }
  }

  Future<void> _promptForBoardingRecovery() async {
    if (_boardingRecoveryPromptShown || !mounted) return;
    _boardingRecoveryPromptShown = true;
    final colorScheme = Theme.of(context).colorScheme;
    final shouldResume = await showModalBottomSheet<bool>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: false,
      backgroundColor: Colors.transparent,
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
                '운행 복구',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Text(
                '최근에 운행 중이였으나, 앱이 의도치 않게 종료되었습니다. '
                '진행 중인 운행을 재개하시겠습니까?',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        shape: const StadiumBorder(),
                      ),
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('아니요'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        shape: const StadiumBorder(),
                      ),
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
    if (shouldResume == true && mounted) {
      await _resumeTrip();
    }
  }

  /// ② 운행 시작 요청 (POST /trips)
  Future<void> _startTrip(BusTripItem selectedTrip) async {
    if (_activeTrip != null || _isStartingTrip || _isLoadingTrips) return;

    final colorScheme = Theme.of(context).colorScheme;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
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
                '운행 시작',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Text(
                '${selectedTrip.busName} 운행을 시작하시겠습니까?',
                style: TextStyle(
                  fontSize: 15,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${selectedTrip.busNumber} · 탑승 예정 학생 ${selectedTrip.studentCount}명'
                '${selectedTrip.isSimulationBus ? ' · 테스트 운행' : ''}',
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          shape: const StadiumBorder(),
                        ),
                        child: const Text('아니요'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: FilledButton.styleFrom(
                          shape: const StadiumBorder(),
                        ),
                        child: const Text('예'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    final busId = int.tryParse(selectedTrip.tripId);
    if (busId == null) {
      InAppNotificationBanner.showMessage('선택한 버스 정보가 올바르지 않아 운행을 시작할 수 없습니다.');
      return;
    }

    setState(() => _isStartingTrip = true);
    try {
      final tripId = await ApiRepository.instance.startTrip(
        busId,
        isMock: selectedTrip.isMock,
        simulationMode: selectedTrip.isSimulationBus,
      );
      Session.currentTripId = tripId;
      Session.currentTripBusName = selectedTrip.busName;
      Session.currentBoardingCount = null;
      Session.currentTripIsMock = selectedTrip.isMock;
      Session.currentTripSimulationMode = selectedTrip.isSimulationBus;
      final progress = TripProgress(
        tripId: tripId,
        busId: busId,
        busName: selectedTrip.busName,
        busNumber: selectedTrip.busNumber,
        isMock: selectedTrip.isMock,
        currentStopIndex: 0,
        simulationMode: selectedTrip.isSimulationBus,
      );
      await TripProgressStorage.save(progress);
      if (!mounted) return;
      setState(() {
        _activeTrip = selectedTrip;
        _activeProgress = progress;
      });

      final result = await Navigator.of(context).push<Object?>(
        MaterialPageRoute(
          builder: (_) => BoardingMapScreen(
            tripId: tripId.toString(),
            busId: busId,
            busName: selectedTrip.busName,
            busNumber: selectedTrip.busNumber,
            isMock: selectedTrip.isMock,
            initialStopIndex: 0,
            onStopChanged: (index) {
              final updated = progress.copyWith(currentStopIndex: index);
              _activeProgress = updated;
              return TripProgressStorage.save(updated);
            },
          ),
        ),
      );
      if (!mounted) return;
      await _fetchTodayTrips(showLoading: false);
      if (result == TripExitAction.cancel && mounted) {
        InAppNotificationBanner.showMessage('운행을 취소했습니다.');
      }
    } catch (e) {
      debugPrint('운행 시작 실패: $e');
      if (!mounted) return;
      InAppNotificationBanner.showMessage(
        AppErrorMessage.from(e, fallback: '운행을 시작하지 못했습니다. 다시 시도해 주세요.'),
      );
    } finally {
      if (mounted) {
        setState(() => _isStartingTrip = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      //운행 홈
      appBar: AppBar(title: const Text('홈')),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.darkCard
                    : colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppTheme.darkSubtleSurface
                          : colorScheme.surface,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(
                      Icons.directions_bus_rounded,
                      color: colorScheme.onSurface,
                      size: 29,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '안전한 운행을 시작하세요',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '버스를 배정받으면 아래에 목록이 표시됩니다.',
                          style: TextStyle(
                            color: isDark
                                ? colorScheme.onSurfaceVariant
                                : colorScheme.onPrimaryContainer.withValues(
                                    alpha: 0.75,
                                  ),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_activeTrip != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppTheme.darkSubtleSurface
                      : colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colorScheme.primary),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '진행 중인 운행',
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${_activeTrip!.busName} · ${_activeTrip!.busNumber}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '현재 운행을 재개하거나 종료한 뒤 새 운행을 시작할 수 있습니다.',
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _isStartingTrip ? null : _resumeTrip,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('운행 재개'),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '배정된 버스',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                if (!_isLoadingTrips && _loadError == null)
                  Text(
                    '${_trips.length}대',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _isLoadingTrips
                  ? const Center(
                      child: CircularProgressIndicator(color: AppTheme.accent),
                    )
                  : RefreshIndicator(
                      onRefresh: () => _fetchTodayTrips(showLoading: false),
                      child: _loadError != null
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                SizedBox(
                                  height: 260,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.cloud_off,
                                        size: 40,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        _loadError!,
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 12),
                                      OutlinedButton.icon(
                                        onPressed: _fetchTodayTrips,
                                        icon: const Icon(Icons.refresh),
                                        label: const Text('다시 시도'),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          : _trips.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: const [
                                SizedBox(
                                  height: 260,
                                  child: Center(
                                    child: Text('오늘 배정된 버스가 없습니다.'),
                                  ),
                                ),
                              ],
                            )
                          : ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemCount: _trips.length,
                              separatorBuilder: (context, _) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final trip = _trips[index];
                                final colorScheme = Theme.of(
                                  context,
                                ).colorScheme;

                                return Material(
                                  color: colorScheme.surface,
                                  borderRadius: BorderRadius.circular(14),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(14),
                                    onTap: _activeTrip != null || _isStartingTrip
                                        ? null
                                        : () => _startTrip(trip),
                                    child: Container(
                                      padding: const EdgeInsets.all(17),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: colorScheme.outlineVariant,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.directions_bus_rounded,
                                                size: 30,
                                                color: colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      trip.busName,
                                                      style: TextStyle(
                                                        fontSize: 17,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: colorScheme
                                                            .onSurface,
                                                      ),
                                                    ),
                                                    Text(
                                                      trip.busNumber,
                                                      style: TextStyle(
                                                        color: colorScheme
                                                            .onSurfaceVariant,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Icon(
                                                Icons.chevron_right_rounded,
                                                color: colorScheme.outline,
                                              ),
                                            ],
                                          ),
                                          const Divider(height: 24),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.route,
                                                size: 18,
                                                color: isDark
                                                    ? colorScheme.onSurface
                                                    : AppTheme.accent,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(trip.routeName),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.people,
                                                size: 18,
                                                color: isDark
                                                    ? colorScheme.onSurface
                                                    : AppTheme.accent,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                '탑승 예정 학생 ${trip.studentCount}명',
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
