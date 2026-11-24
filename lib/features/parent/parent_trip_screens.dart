import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../core/auth/session.dart';
import '../../core/errors/app_error_message.dart';
import '../../core/notifications/in_app_notification_banner.dart';
import '../../data/api/api_repository.dart';
import '../../data/models/child_student.dart';
import '../../theme/app_colors.dart';
import '../auth/login_screen.dart';

class ParentTripAttendanceScreen extends StatefulWidget {
  const ParentTripAttendanceScreen({super.key});

  @override
  State<ParentTripAttendanceScreen> createState() =>
      _ParentTripAttendanceScreenState();
}

class _ParentTripAttendanceScreenState
    extends State<ParentTripAttendanceScreen> {
  late Future<List<ChildStudent>> _children;
  final Set<int> _saving = {};
  bool _loggingOut = false;
  DateTime _date = DateUtils.dateOnly(DateTime.now());

  static const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

  bool get _isToday => DateUtils.isSameDay(_date, DateTime.now());

  String get _dateTitle =>
      '${_date.month}월 ${_date.day}일(${_weekdays[_date.weekday - 1]})'
      '${_isToday ? ' · 오늘' : ''}';

  @override
  void initState() {
    super.initState();
    _children = _load();
  }

  Future<void> _logoutIfUnauthorized(Object error) async {
    if (error is DioException &&
        error.response?.statusCode == 401 &&
        !_loggingOut) {
      _loggingOut = true;
      await Session.clear();
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  Future<List<ChildStudent>> _load() async {
    try {
      // 서버 /me/children?date= : 그날 마지막 운행의 승차·하차 확인 시각과 결석 여부
      return await ApiRepository.instance.getChildren(date: _date);
    } catch (error) {
      await _logoutIfUnauthorized(error);
      rethrow;
    }
  }

  void _reload() => setState(() {
    _children = _load();
  });

  void _changeDate(DateTime date) {
    final today = DateUtils.dateOnly(DateTime.now());
    final next = DateUtils.dateOnly(date);
    if (next.isAfter(today)) return;
    setState(() {
      _date = next;
      _children = _load();
    });
  }

  /// 오른쪽 위 달력 버튼: 달력에서 날짜를 고르면 그날 승하차 기록을 보여 준다
  Future<void> _openCalendar() async {
    final today = DateUtils.dateOnly(DateTime.now());
    var focused = _date;
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '날짜를 고르면 그날 승하차 기록을 볼 수 있어요',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                TableCalendar<void>(
                  firstDay: DateTime(today.year - 1, today.month, today.day),
                  lastDay: today,
                  focusedDay: focused,
                  currentDay: today,
                  startingDayOfWeek: StartingDayOfWeek.monday,
                  calendarFormat: CalendarFormat.month,
                  availableGestures: AvailableGestures.horizontalSwipe,
                  selectedDayPredicate: (day) => DateUtils.isSameDay(day, _date),
                  onDaySelected: (selected, _) =>
                      Navigator.pop(context, selected),
                  onPageChanged: (day) => setSheet(() => focused = day),
                  headerStyle: const HeaderStyle(
                    titleCentered: true,
                    formatButtonVisible: false,
                  ),
                  calendarBuilders: CalendarBuilders(
                    headerTitleBuilder: (context, day) => Center(
                      child: Text(
                        '${day.year}년 ${day.month}월',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    dowBuilder: (context, day) => Center(
                      child: Text(
                        _weekdays[day.weekday - 1],
                        style: TextStyle(
                          color: day.weekday == DateTime.sunday
                              ? AppColors.danger
                              : AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  calendarStyle: CalendarStyle(
                    todayDecoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      shape: BoxShape.circle,
                    ),
                    todayTextStyle: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                    selectedDecoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    selectedTextStyle: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, today),
                  child: const Text('오늘로 가기'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (picked != null && mounted) _changeDate(picked);
  }

  String _time(DateTime? value) {
    if (value == null) return '확인 전';
    final time = value.toLocal();
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _confirm(ChildStudent child, String eventType) async {
    final action = eventType == 'BOARDING' ? '승차' : '하차';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$action 완료를 확인할까요?'),
        content: Text(
          '${child.name} 학생의 $action을 기록합니다. 직접 취소할 수 없으므로 실제 $action을 마친 경우에만 확인해 주세요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('$action 완료 확인'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || child.tripId == null || !_isToday) {
      return;
    }
    setState(() => _saving.add(child.id));
    try {
      await ApiRepository.instance.confirmChildTripAttendance(
        tripId: child.tripId!,
        studentId: child.id,
        eventType: eventType,
      );
      if (mounted) _reload();
    } catch (error) {
      await _logoutIfUnauthorized(error);
      if (mounted && !_loggingOut) {
        InAppNotificationBanner.showMessage(
          AppErrorMessage.from(error, fallback: '승하차 확인을 저장하지 못했습니다.'),
        );
      }
    } finally {
      if (mounted) setState(() => _saving.remove(child.id));
    }
  }

  Widget _timeBox(String label, DateTime? time, IconData icon) {
    final done = time != null;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: done
              ? AppColors.success.withValues(alpha: 0.10)
              : AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: done
                ? AppColors.success.withValues(alpha: 0.35)
                : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: done ? AppColors.success : AppColors.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            const Spacer(),
            Text(
              done ? _time(time) : '--:--',
              style: TextStyle(
                color: done ? AppColors.textPrimary : AppColors.textSecondary,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _childRecord(ChildStudent child) {
    final canConfirm =
        _isToday &&
        child.busStatus == 'IN_PROGRESS' &&
        child.tripId != null &&
        !child.isAbsent &&
        child.alightingConfirmedAt == null;
    final noTrip =
        child.boardingConfirmedAt == null &&
        child.alightingConfirmedAt == null &&
        child.tripId == null;
    return Card(
      elevation: 0,
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    [
                      child.name,
                      if (child.className != null) child.className!,
                      ?child.busName,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (canConfirm)
                  TextButton(
                    onPressed: _saving.contains(child.id)
                        ? null
                        : () => _confirm(
                            child,
                            child.boardingConfirmedAt == null
                                ? 'BOARDING'
                                : 'ALIGHTING',
                          ),
                    child: Text(
                      child.boardingConfirmedAt == null ? '승차 완료' : '하차 완료',
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (child.isAbsent)
              const Text(
                '결석한 날이에요',
                style: TextStyle(color: AppColors.danger, fontSize: 13),
              )
            else if (noTrip)
              const Text(
                '이 날은 운행 기록이 없어요',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              )
            else
              Row(
                children: [
                  _timeBox('승차', child.boardingConfirmedAt, Icons.login_rounded),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  _timeBox('하차', child.alightingConfirmedAt, Icons.logout_rounded),
                ],
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(DateTime.now());
    return Scaffold(
      appBar: AppBar(
        title: const Text('승하차 기록'),
        actions: [
          IconButton(
            tooltip: '날짜 선택',
            onPressed: _openCalendar,
            icon: const Icon(Icons.calendar_month_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
            child: Row(
              children: [
                IconButton(
                  tooltip: '전날',
                  onPressed: () =>
                      _changeDate(_date.subtract(const Duration(days: 1))),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _openCalendar,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        _dateTitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '다음날',
                  onPressed: _date.isBefore(today)
                      ? () => _changeDate(_date.add(const Duration(days: 1)))
                      : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<ChildStudent>>(
              future: _children,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: TextButton(
                      onPressed: _reload,
                      child: const Text('불러오지 못했어요 · 다시 시도'),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final children = snapshot.data!;
                return RefreshIndicator(
                  onRefresh: () async {
                    _reload();
                    try {
                      await _children;
                    } catch (_) {
                      // 오류는 화면의 '다시 시도'로 보여 준다
                    }
                  },
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    children: [
                      if (children.isEmpty)
                        const ListTile(title: Text('연결된 자녀가 없습니다.')),
                      for (final child in children) _childRecord(child),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
