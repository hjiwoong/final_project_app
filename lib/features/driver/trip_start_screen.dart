import 'package:flutter/material.dart';

import '../../core/auth/session.dart';
import '../../data/api/api_repository.dart';
import '../../widgets/primary_button.dart';
import 'boarding_map_screen.dart';

/// 버스 및 운행(Trip) 정보 모델
class BusTripItem {
  final String tripId;
  final String busNumber;
  final String busName;
  final String routeName;
  final int studentCount;

  BusTripItem({
    required this.tripId,
    required this.busNumber,
    required this.busName,
    required this.routeName,
    required this.studentCount,
  });

  factory BusTripItem.fromJson(Map<String, dynamic> json) {
    return BusTripItem(
      tripId: json['tripId'] ?? '',
      busNumber: json['busNumber'] ?? '',
      busName: json['busName'] ?? '',
      routeName: json['routeName'] ?? '',
      studentCount: json['studentCount'] ?? 0,
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
  BusTripItem? _selectedTrip;

  @override
  void initState() {
    super.initState();
    _fetchTodayTrips();
  }

  /// ① 버스 목록 및 운행 정보 조회 (GET /web/buses)
  Future<void> _fetchTodayTrips() async {
    setState(() {
      _isLoadingTrips = true;
      _loadError = null;
      _trips = [];
      _selectedTrip = null;
    });

    try {
      final buses = await ApiRepository.instance.getBuses();
      final loadedTrips = buses
          .map(
            (b) => BusTripItem(
              tripId: b['id'].toString(),
              busNumber: b['plate_no'] ?? '',
              busName: b['name'] ?? '',
              routeName: '학교 → 종점',
              studentCount: b['student_count'] ?? 0,
            ),
          )
          .toList();

      if (!mounted) return;
      setState(() {
        _trips = loadedTrips;
        _selectedTrip = loadedTrips.isEmpty ? null : loadedTrips.first;
        _isLoadingTrips = false;
      });
    } catch (e) {
      debugPrint('버스 목록 조회 실패: $e');
      if (!mounted) return;
      setState(() {
        _loadError = '버스 목록을 불러오지 못했습니다. 연결을 확인하고 다시 시도해 주세요.';
        _isLoadingTrips = false;
      });
    }
  }

  /// ② 운행 시작 요청 (POST /trips)
  Future<void> _startTrip() async {
    final selectedTrip = _selectedTrip;
    if (selectedTrip == null || _isStartingTrip || _isLoadingTrips) return;

    final busId = int.tryParse(selectedTrip.tripId);
    if (busId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('선택한 버스 정보가 올바르지 않아 운행을 시작할 수 없습니다.')),
      );
      return;
    }

    setState(() => _isStartingTrip = true);
    try {
      final tripId = await ApiRepository.instance.startTrip(busId);
      Session.currentTripId = tripId;

      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => BoardingMapScreen(tripId: tripId.toString()),
        ),
      );
    } catch (e) {
      debugPrint('운행 시작 실패: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('운행을 시작하지 못했습니다. 다시 시도해 주세요. ($e)')),
      );
    } finally {
      if (mounted) {
        setState(() => _isStartingTrip = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('운행 시작')),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '운행할 버스를 선택해 주세요',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _isLoadingTrips
                  ? const Center(child: CircularProgressIndicator())
                  : _loadError != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.cloud_off,
                            size: 40,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 12),
                          Text(_loadError!, textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _fetchTodayTrips,
                            icon: const Icon(Icons.refresh),
                            label: const Text('다시 시도'),
                          ),
                        ],
                      ),
                    )
                  : _trips.isEmpty
                  ? const Center(child: Text('오늘 배정된 버스가 없습니다.'))
                  : ListView.separated(
                      itemCount: _trips.length,
                      separatorBuilder: (context, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final trip = _trips[index];
                        final isSelected = _selectedTrip?.tripId == trip.tripId;
                        final colorScheme = Theme.of(context).colorScheme;

                        return Material(
                          color: isSelected
                              ? colorScheme.primaryContainer
                              : colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => setState(() => _selectedTrip = trip),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected
                                      ? colorScheme.primary
                                      : colorScheme.outlineVariant,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.directions_bus_rounded,
                                        size: 30,
                                        color: isSelected
                                            ? colorScheme.primary
                                            : colorScheme.onSurfaceVariant,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              trip.busName,
                                              style: const TextStyle(
                                                fontSize: 17,
                                                fontWeight: FontWeight.bold,
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
                                      if (isSelected)
                                        Icon(
                                          Icons.check_circle,
                                          color: colorScheme.primary,
                                        )
                                      else
                                        Icon(
                                          Icons.radio_button_unchecked,
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
                                        color: colorScheme.primary,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(child: Text(trip.routeName)),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.people,
                                        size: 18,
                                        color: colorScheme.primary,
                                      ),
                                      const SizedBox(width: 8),
                                      Text('탑승 예정 학생 ${trip.studentCount}명'),
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
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              top: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ),
          child: PrimaryButton(
            label: _selectedTrip == null
                ? '버스를 선택해 주세요'
                : '${_selectedTrip!.busName} 운행 시작',
            loading: _isStartingTrip,
            onPressed:
                _isLoadingTrips ||
                    _loadError != null ||
                    _trips.isEmpty ||
                    _isStartingTrip
                ? null
                : _startTrip,
          ),
        ),
      ),
    );
  }
}
