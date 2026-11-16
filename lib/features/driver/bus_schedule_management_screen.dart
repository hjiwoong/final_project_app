import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../core/auth/session.dart';
import '../../core/theme/app_theme.dart';
import '../../data/api/api_repository.dart';
import '../auth/login_screen.dart';
import 'bus_schedule_detail_screen.dart';
import 'bus_schedule_time.dart';
import 'widgets/driver_home_cards.dart';

class BusScheduleManagementScreen extends StatefulWidget {
  const BusScheduleManagementScreen({super.key});

  @override
  State<BusScheduleManagementScreen> createState() =>
      _BusScheduleManagementScreenState();
}

class _BusScheduleManagementScreenState
    extends State<BusScheduleManagementScreen> {
  DateTime _serviceDate = DateUtils.dateOnly(DateTime.now());
  List<Map<String, dynamic>> _buses = [];
  List<Map<String, dynamic>>? _schedules;
  bool _isLoadingBuses = true;
  bool _isLoadingSchedules = true;
  String? _busLoadError;
  int _scheduleRequestId = 0;

  @override
  void initState() {
    super.initState();
    _loadBusesAndSchedules();
  }

  // This only gates UI; the server's require_admin check enforces authorization.
  bool get _isAdmin => Session.accountRole?.toUpperCase() == 'ADMIN';

  Future<void> _redirectToLogin() async {
    await Session.clear();
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<List<Map<String, dynamic>>?> _loadSchedules(DateTime date) async {
    try {
      return await ApiRepository.instance.getTripSchedules(serviceDate: date);
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) rethrow;
      debugPrint('출발 시각 목록 조회 실패: $error');
      return null;
    } catch (error) {
      debugPrint('출발 시각 목록 조회 실패: $error');
      return null;
    }
  }

  Future<void> _loadBusesAndSchedules() async {
    final requestId = ++_scheduleRequestId;
    final serviceDate = _serviceDate;
    setState(() {
      _isLoadingBuses = true;
      _isLoadingSchedules = true;
      _busLoadError = null;
    });
    try {
      final results = await Future.wait<Object?>([
        ApiRepository.instance.getBuses(),
        _loadSchedules(serviceDate),
      ]);
      if (!mounted) return;
      setState(() {
        _buses = results[0] as List<Map<String, dynamic>>;
        _isLoadingBuses = false;
        if (requestId == _scheduleRequestId) {
          _schedules = results[1] as List<Map<String, dynamic>>?;
          _isLoadingSchedules = false;
        }
      });
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) {
        await _redirectToLogin();
        return;
      }
      debugPrint('버스 목록 조회 실패: $error');
      if (mounted) {
        setState(() {
          _busLoadError = '버스 목록을 불러오지 못했습니다. 다시 시도해 주세요.';
          _isLoadingBuses = false;
          _isLoadingSchedules = false;
        });
      }
    } catch (error) {
      debugPrint('버스 목록 조회 실패: $error');
      if (mounted) {
        setState(() {
          _busLoadError = '버스 목록을 불러오지 못했습니다. 다시 시도해 주세요.';
          _isLoadingBuses = false;
          _isLoadingSchedules = false;
        });
      }
    }
  }

  Future<void> _loadSchedulesForDate(DateTime date) async {
    final requestId = ++_scheduleRequestId;
    setState(() {
      _serviceDate = DateUtils.dateOnly(date);
      _schedules = null;
      _isLoadingSchedules = true;
    });
    try {
      final schedules = await _loadSchedules(_serviceDate);
      if (!mounted || requestId != _scheduleRequestId) return;
      setState(() {
        _schedules = schedules;
        _isLoadingSchedules = false;
      });
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) {
        await _redirectToLogin();
        return;
      }
      if (mounted && requestId == _scheduleRequestId) {
        setState(() {
          _schedules = null;
          _isLoadingSchedules = false;
        });
      }
    }
  }

  Future<void> _selectDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _serviceDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (selected != null && mounted) {
      await _loadSchedulesForDate(selected);
    }
  }

  Future<void> _openBusDetail(Map<String, dynamic> bus) async {
    final busId = (bus['id'] as num).toInt();
    final schedule = _schedules
        ?.where((item) => (item['bus_id'] as num).toInt() == busId)
        .firstOrNull;
    final result = await Navigator.of(context).push<BusScheduleListResult>(
      MaterialPageRoute(
        builder: (_) => BusScheduleDetailScreen(
          bus: bus,
          serviceDate: _serviceDate,
          scheduledAt: parseScheduledAt(schedule?['scheduled_at']),
          tripId: schedule?['trip_id'] is num
              ? (schedule!['trip_id'] as num).toInt()
              : null,
          scheduleLoadFailed: _schedules == null,
        ),
      ),
    );
    if (result == null || !mounted) return;
    if (DateUtils.isSameDay(result.serviceDate, _serviceDate)) {
      setState(() {
        final schedules = [...?_schedules];
        final index = schedules.indexWhere(
          (item) => (item['bus_id'] as num).toInt() == busId,
        );
        final updated = {
          'bus_id': busId,
          'scheduled_at': result.scheduledAt.toIso8601String(),
          'trip_id': schedule?['trip_id'],
        };
        if (index < 0) {
          schedules.add(updated);
        } else {
          schedules[index] = {...schedules[index], ...updated};
        }
        _schedules = schedules;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('버스 배정 관리')),
        body: Center(child: Text('관리자만 이용할 수 있습니다.')),
      );
    }
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('버스 배정 관리')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                title: const Text('운행 날짜'),
                subtitle: Text(formatServiceDate(_serviceDate)),
                trailing: const Icon(Icons.calendar_today_outlined),
                onTap: _selectDate,
              ),
            ),
          ),
          Expanded(
            child: _isLoadingBuses
                ? const Center(
                    child: CircularProgressIndicator(color: AppTheme.accent),
                  )
                : _busLoadError != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _busLoadError!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: colors.onSurfaceVariant),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _loadBusesAndSchedules,
                          icon: const Icon(Icons.refresh),
                          label: const Text('다시 시도'),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadBusesAndSchedules,
                    child: _buses.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: const [
                              SizedBox(
                                height: 240,
                                child: Center(child: Text('등록된 버스가 없습니다.')),
                              ),
                            ],
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: _buses.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final bus = _buses[index];
                              final busId = (bus['id'] as num).toInt();
                              final schedule = _schedules
                                  ?.where(
                                    (item) =>
                                        (item['bus_id'] as num).toInt() ==
                                        busId,
                                  )
                                  .firstOrNull;
                              final scheduledAt = parseScheduledAt(
                                schedule?['scheduled_at'],
                              );
                              final timeLabel = formatScheduledTime(
                                scheduledAt,
                              );
                              return AssignedBusCard(
                                busName: bus['name']?.toString() ?? '버스',
                                busNumber: bus['plate_no']?.toString() ?? '',
                                departureLabel: _isLoadingSchedules
                                    ? '불러오는 중'
                                    : _schedules == null
                                    ? '불러오기 실패'
                                    : timeLabel == null
                                    ? '미설정'
                                    : '$timeLabel 출발',
                                routeName: '학교 → 종점',
                                studentCount:
                                    (bus['student_count'] as num?)?.toInt() ??
                                    0,
                                isActive: schedule?['trip_id'] != null,
                                isEnabled: !_isLoadingSchedules,
                                onTap: () => _openBusDetail(bus),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}
