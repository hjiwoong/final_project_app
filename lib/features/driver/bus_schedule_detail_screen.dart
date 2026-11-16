import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../core/auth/session.dart';
import '../../core/notifications/in_app_notification_banner.dart';
import '../../data/api/api_repository.dart';
import '../auth/login_screen.dart';
import 'bus_schedule_time.dart';

class BusScheduleDetailScreen extends StatefulWidget {
  const BusScheduleDetailScreen({
    super.key,
    required this.bus,
    required this.serviceDate,
    required this.scheduledAt,
    required this.tripId,
    required this.scheduleLoadFailed,
  });

  final Map<String, dynamic> bus;
  final DateTime serviceDate;
  final DateTime? scheduledAt;
  final int? tripId;
  final bool scheduleLoadFailed;

  @override
  State<BusScheduleDetailScreen> createState() =>
      _BusScheduleDetailScreenState();
}

class _BusScheduleDetailScreenState extends State<BusScheduleDetailScreen> {
  late DateTime _serviceDate = DateUtils.dateOnly(widget.serviceDate);
  late DateTime? _scheduledAt = widget.scheduledAt;
  late int? _tripId = widget.tripId;
  late bool _hasStarted = widget.tripId != null;
  late bool _scheduleLoadFailed = widget.scheduleLoadFailed;
  bool _isLoadingSchedule = false;
  bool _isSaving = false;
  int _scheduleRequestId = 0;

  // This only gates UI; the server's require_admin check enforces authorization.
  bool get _isAdmin => Session.accountRole?.toUpperCase() == 'ADMIN';
  int get _busId => widget.bus['id'] as int;

  Future<void> _redirectToLogin() async {
    await Session.clear();
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<void> _selectDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _serviceDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (selected == null || !mounted) return;
    final date = DateUtils.dateOnly(selected);
    setState(() {
      _serviceDate = date;
      _scheduledAt = null;
      _tripId = null;
      _scheduleLoadFailed = false;
      _isLoadingSchedule = true;
    });
    await _loadSchedule(date);
  }

  Future<void> _loadSchedule(DateTime date) async {
    final requestId = ++_scheduleRequestId;
    try {
      final schedules = await ApiRepository.instance.getTripSchedules(
        serviceDate: date,
      );
      final schedule = schedules
          .where((item) => (item['bus_id'] as num).toInt() == _busId)
          .firstOrNull;
      if (!mounted || requestId != _scheduleRequestId) return;
      setState(() {
        _scheduledAt = parseScheduledAt(schedule?['scheduled_at']);
        // TODO: Have the schedule API expose trip_id; rely on HTTP 409 when absent.
        _tripId = schedule?['trip_id'] is num
            ? (schedule!['trip_id'] as num).toInt()
            : null;
        _hasStarted = _tripId != null;
        _scheduleLoadFailed = false;
        _isLoadingSchedule = false;
      });
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) {
        await _redirectToLogin();
        return;
      }
      debugPrint('버스 출발 시각 조회 실패: $error');
      if (mounted && requestId == _scheduleRequestId) {
        setState(() {
          _scheduleLoadFailed = true;
          _isLoadingSchedule = false;
        });
      }
    } catch (error) {
      debugPrint('버스 출발 시각 조회 실패: $error');
      if (mounted && requestId == _scheduleRequestId) {
        setState(() {
          _scheduleLoadFailed = true;
          _isLoadingSchedule = false;
        });
      }
    }
  }

  Future<void> _editDepartureTime() async {
    if (!_isAdmin || _isSaving || _isLoadingSchedule || _hasStarted) return;
    final now = DateTime.now();
    final initialTime = initialScheduleTime(
      serviceDate: _serviceDate,
      scheduledAt: _scheduledAt,
      now: now,
    );
    final selected = await showFiveMinuteTimePicker(
      context: context,
      serviceDate: _serviceDate,
      initialTime: initialTime,
      now: now,
    );
    if (selected == null || !mounted) return;

    final previousValue = _scheduledAt;
    setState(() => _isSaving = true);
    try {
      final response = await ApiRepository.instance.saveTripSchedule(
        busId: _busId,
        serviceDate: _serviceDate,
        startTime: formatScheduleStartTime(selected),
      );
      final savedAt = parseScheduledAt(response['scheduled_at']);
      if (savedAt == null) {
        throw const FormatException('저장 응답에 출발 예정 시각이 없습니다.');
      }
      if (!mounted) return;
      setState(() {
        _scheduledAt = savedAt;
        _scheduleLoadFailed = false;
        _tripId = response['trip_id'] is num
            ? (response['trip_id'] as num).toInt()
            : _tripId;
        _hasStarted = _tripId != null;
      });
      Navigator.of(context).pop(
        BusScheduleListResult(serviceDate: _serviceDate, scheduledAt: savedAt),
      );
      InAppNotificationBanner.showMessage('출발 시각이 저장되었습니다');
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) {
        await _redirectToLogin();
        return;
      }
      if (mounted) {
        setState(() {
          _scheduledAt = previousValue;
          if (error.response?.statusCode == 409) _hasStarted = true;
        });
        InAppNotificationBanner.showMessage(
          switch (error.response?.statusCode) {
            400 => '현재 시각 이후로 설정해주세요',
            403 => '권한이 없습니다',
            404 => '존재하지 않는 버스입니다',
            409 => '이미 운행을 시작해 변경할 수 없습니다',
            _ => '저장에 실패했습니다. 다시 시도해주세요',
          },
        );
      }
    } catch (error) {
      debugPrint('출발 시각 저장 실패: $error');
      if (mounted) {
        setState(() => _scheduledAt = previousValue);
        InAppNotificationBanner.showMessage('저장에 실패했습니다. 다시 시도해주세요');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final busName = widget.bus['name']?.toString() ?? '버스';
    final plateNumber = widget.bus['plate_no']?.toString() ?? '';
    final studentCount = (widget.bus['student_count'] as num?)?.toInt() ?? 0;
    final departureTime = formatScheduledTime(_scheduledAt);
    final canChange =
        _isAdmin &&
        !_hasStarted &&
        !_isSaving &&
        !_isLoadingSchedule &&
        !_scheduleLoadFailed;

    return Scaffold(
      appBar: AppBar(title: const Text('버스 상세')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    busName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    plateNumber,
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                  const Divider(height: 28),
                  _DetailRow(
                    label: '기사 ID',
                    value: widget.bus['driver_id']?.toString() ?? '미지정',
                  ),
                  const SizedBox(height: 12),
                  _DetailRow(label: '탑승 예정 학생', value: '$studentCount명'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              title: const Text('운행 날짜'),
              subtitle: Text(formatServiceDate(_serviceDate)),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: _isAdmin && !_isSaving ? _selectDate : null,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              title: const Text('출발 예정 시각'),
              subtitle: Text(
                _isLoadingSchedule
                    ? '불러오는 중'
                    : _scheduleLoadFailed
                    ? '불러오기 실패'
                    : departureTime ?? '미설정',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              trailing: _isSaving || _isLoadingSchedule
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : canChange
                  ? const Icon(Icons.edit_outlined)
                  : null,
              enabled: canChange,
              onTap: canChange ? _editDepartureTime : null,
            ),
          ),
          if (_hasStarted) ...[
            const SizedBox(height: 8),
            Text(
              '운행 중에는 변경할 수 없습니다',
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        SizedBox(
          width: 112,
          child: Text(label, style: TextStyle(color: colors.onSurfaceVariant)),
        ),
        Expanded(child: Text(value)),
      ],
    );
  }
}
