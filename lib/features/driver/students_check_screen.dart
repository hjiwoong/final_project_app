import 'package:flutter/material.dart';

import '../../core/errors/app_error_message.dart';
import '../../data/api/api_repository.dart';
import '../../data/models/child_student.dart';

class StudentsCheckScreen extends StatefulWidget {
  const StudentsCheckScreen({super.key});

  @override
  State<StudentsCheckScreen> createState() => _StudentsCheckScreenState();
}

class _StudentsCheckScreenState extends State<StudentsCheckScreen> {
  late DateTime _selectedDate;
  late DateTime _displayedMonth;
  late Future<Map<DateTime, List<_BusAbsences>>> _monthlyAbsences;

  @override
  void initState() {
    super.initState();
    _selectedDate = _dateOnly(DateTime.now());
    _displayedMonth = _monthOnly(_selectedDate);
    _monthlyAbsences = _loadMonth(_selectedDate);
  }

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  DateTime _monthOnly(DateTime date) => DateTime(date.year, date.month);

  bool _isSameMonth(DateTime first, DateTime second) =>
      first.year == second.year && first.month == second.month;

  Future<Map<DateTime, List<_BusAbsences>>> _loadMonth(DateTime date) async {
    final days = await ApiRepository.instance.getAttendanceCalendar(
      year: date.year,
      month: date.month,
    );
    return {
      for (final day in days)
        _dateOnly(DateTime.parse(day['date'] as String)): [
          for (final bus in day['buses'] as List)
            _BusAbsences(
              name: (bus as Map)['bus_name']?.toString() ?? '버스',
              plateNumber: bus['plate_no']?.toString(),
              students: [
                for (final student in bus['students'] as List)
                  ChildStudent.fromJson(
                    Map<String, dynamic>.from(student as Map),
                  ),
              ],
            ),
        ],
    };
  }

  void _selectDate(DateTime date) {
    final selected = _dateOnly(date);
    setState(() {
      _selectedDate = selected;
      if (!_isSameMonth(selected, _displayedMonth)) {
        _displayedMonth = _monthOnly(selected);
        _monthlyAbsences = _loadMonth(selected);
      }
    });
  }

  void _changeMonth(int offset) {
    final month = DateTime(_selectedDate.year, _selectedDate.month + offset);
    final lastDay = DateUtils.getDaysInMonth(month.year, month.month);
    final selected = DateTime(
      month.year,
      month.month,
      _selectedDate.day.clamp(1, lastDay),
    );
    setState(() {
      _selectedDate = selected;
      _displayedMonth = _monthOnly(selected);
      _monthlyAbsences = _loadMonth(selected);
    });
  }

  Future<void> _jumpToDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date != null && mounted) _selectDate(date);
  }

  String _weekdayLabel(int weekday) =>
      const ['월', '화', '수', '목', '금', '토', '일'][weekday - 1];

  String _fullDate(DateTime date) =>
      '${date.year}년 ${date.month}월 ${date.day}일 (${_weekdayLabel(date.weekday)})';

  Widget _buildMonthHeader() {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        IconButton(
          onPressed: () => _changeMonth(-1),
          tooltip: '이전 달',
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Center(
            child: Text(
              '${_selectedDate.year}년 ${_selectedDate.month}월',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        IconButton(
          onPressed: () => _changeMonth(1),
          tooltip: '다음 달',
          icon: const Icon(Icons.chevron_right),
        ),
        TextButton(
          onPressed: () => _selectDate(DateTime.now()),
          child: Text(
            '오늘',
            style: TextStyle(
              color: colors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMonthGrid(Map<DateTime, List<_BusAbsences>> absencesByDate) {
    final colors = Theme.of(context).colorScheme;
    final firstDay = DateTime(_selectedDate.year, _selectedDate.month, 1);
    final leadingDays = firstDay.weekday - DateTime.monday;
    final dayCount = DateUtils.getDaysInMonth(
      _selectedDate.year,
      _selectedDate.month,
    );
    final cellCount = ((leadingDays + dayCount + 6) ~/ 7) * 7;
    final today = _dateOnly(DateTime.now());

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
        child: Column(
          children: [
            Row(
              children: [
                for (var weekday = 1; weekday <= 7; weekday++)
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          _weekdayLabel(weekday),
                          style: TextStyle(
                            color: weekday == DateTime.sunday
                                ? colors.error
                                : colors.onSurfaceVariant,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: cellCount,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 0.9,
              ),
              itemBuilder: (context, index) {
                final dayNumber = index - leadingDays + 1;
                final isCurrentMonth = dayNumber >= 1 && dayNumber <= dayCount;
                final date = DateTime(
                  _selectedDate.year,
                  _selectedDate.month,
                  dayNumber,
                );
                final selected = date == _selectedDate;
                final isToday = date == today;
                final count = (absencesByDate[date] ?? const []).fold<int>(
                  0,
                  (total, bus) => total + bus.students.length,
                );
                final textColor = !isCurrentMonth
                    ? colors.onSurface.withValues(alpha: 0.25)
                    : selected
                    ? colors.onPrimary
                    : date.weekday == DateTime.sunday
                    ? colors.error
                    : colors.onSurface;

                return InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _selectDate(date),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selected ? colors.primary : null,
                          border: isToday && !selected
                              ? Border.all(color: colors.primary, width: 1.5)
                              : null,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${date.day}',
                          style: TextStyle(
                            color: textColor,
                            fontWeight: selected || isToday
                                ? FontWeight.w700
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      SizedBox(
                        height: 8,
                        child: count > 0 && isCurrentMonth
                            ? Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: selected
                                      ? colors.primary
                                      : colors.error,
                                ),
                              )
                            : null,
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceDetails(List<_BusAbsences> buses) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text(
          _fullDate(_selectedDate),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (buses.isEmpty)
          Card(
            child: ListTile(
              leading: Icon(
                Icons.event_available_outlined,
                color: colors.tertiary,
              ),
              title: const Text('결석으로 신청된 학생이 없습니다.'),
            ),
          )
        else
          for (final bus in buses)
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.directions_bus_outlined),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            bus.plateNumber == null
                                ? bus.name
                                : '${bus.name} · ${bus.plateNumber}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Text('${bus.students.length}명 결석'),
                      ],
                    ),
                    const Divider(height: 20),
                    for (final student in bus.students)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.person_off_outlined,
                          color: colors.error,
                        ),
                        title: Text(student.name),
                        subtitle: Text(student.className ?? '학급 정보 없음'),
                        trailing: const Chip(label: Text('결석')),
                      ),
                  ],
                ),
              ),
            ),
      ],
    );
  }

  Widget _buildCalendarContent(
    Map<DateTime, List<_BusAbsences>> absencesByDate,
  ) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _buildMonthHeader(),
        const SizedBox(height: 8),
        _buildMonthGrid(absencesByDate),
        _buildAttendanceDetails(
          absencesByDate[_selectedDate] ?? const <_BusAbsences>[],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('출결 기록'),
        actions: [
          IconButton(
            tooltip: '날짜로 이동',
            onPressed: _jumpToDate,
            icon: const Icon(Icons.calendar_today),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final future = _loadMonth(_selectedDate);
          setState(() {
            _monthlyAbsences = future;
          });
          await future;
        },
        child: FutureBuilder<Map<DateTime, List<_BusAbsences>>>(
          key: ValueKey('${_displayedMonth.year}-${_displayedMonth.month}'),
          future: _monthlyAbsences,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  _buildMonthHeader(),
                  const SizedBox(height: 32),
                  Text(
                    AppErrorMessage.from(
                      snapshot.error ?? StateError('출결 기록이 없습니다.'),
                      fallback: '학생 출결 정보를 불러오지 못했습니다.',
                    ),
                    textAlign: TextAlign.center,
                  ),
                  Center(
                    child: TextButton(
                      onPressed: () => _changeMonth(0),
                      child: const Text('다시 시도'),
                    ),
                  ),
                ],
              );
            }
            return _buildCalendarContent(snapshot.data!);
          },
        ),
      ),
    );
  }
}

class _BusAbsences {
  const _BusAbsences({
    required this.name,
    required this.plateNumber,
    required this.students,
  });

  final String name;
  final String? plateNumber;
  final List<ChildStudent> students;
}
