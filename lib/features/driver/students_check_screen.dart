import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/errors/app_error_message.dart';
import '../../core/sync/attendance_sync.dart';
import '../../data/api/api_repository.dart';
import '../../data/models/child_student.dart';
import 'widgets/absence_detail.dart';

class StudentsCheckScreen extends StatefulWidget {
  const StudentsCheckScreen({super.key});

  @override
  State<StudentsCheckScreen> createState() => _StudentsCheckScreenState();
}

class _StudentsCheckScreenState extends State<StudentsCheckScreen> {
  late DateTime _selectedDate;
  late DateTime _displayedMonth;
  late Future<Map<DateTime, List<_BusAbsences>>> _monthlyAbsences;
  Timer? _autoRefresh;
  bool _silentLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = _dateOnly(DateTime.now());
    _displayedMonth = _monthOnly(_selectedDate);
    _monthlyAbsences = _loadMonth(_selectedDate);
    // 학부모가 결석을 바꾸면: 푸시를 받는 즉시 + 푸시가 없어도 30초마다 조용히 다시 불러온다
    AttendanceSync.changes.addListener(_silentReload);
    _autoRefresh = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _silentReload(),
    );
  }

  @override
  void dispose() {
    AttendanceSync.changes.removeListener(_silentReload);
    _autoRefresh?.cancel();
    super.dispose();
  }

  /// 화면을 비우지 않고 보이는 달의 결석 목록만 바꿔 끼운다 (실패하면 기존 화면 유지)
  Future<void> _silentReload() async {
    if (_silentLoading || !mounted) return;
    _silentLoading = true;
    final month = _displayedMonth;
    try {
      final data = await _loadMonth(month);
      if (!mounted || month != _displayedMonth) return;
      setState(() => _monthlyAbsences = Future.value(data));
    } catch (_) {
      // 다음 주기에 다시 시도
    } finally {
      _silentLoading = false;
    }
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
              details: [
                for (final student in bus['students'] as List)
                  _AbsenceDetail.fromJson(
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
                    for (var i = 0; i < bus.students.length; i++) ...[
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.person_off_outlined,
                          color: colors.error,
                        ),
                        title: Text(bus.students[i].name),
                        subtitle: Text(
                          [
                            bus.students[i].className ?? '학급 정보 없음',
                            if (bus.details[i].reasonText case final reason?)
                              '사유: $reason',
                          ].join('\n'),
                        ),
                        isThreeLine: bus.details[i].reasonText != null,
                        trailing: Chip(
                          label: Text(bus.details[i].statusLabel),
                        ),
                        // 눌러서 사유·첨부 보고 확인/반려
                        onTap: bus.details[i].attendanceId == null
                            ? null
                            : () async {
                                await showAbsenceDetailSheet(
                                  context,
                                  attendanceId: bus.details[i].attendanceId!,
                                );
                                _silentReload();
                              },
                      ),
                      if (bus.details[i].files.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 40, bottom: 8),
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final file in bus.details[i].files)
                                ActionChip(
                                  avatar: Icon(
                                    file.isPdf
                                        ? Icons.picture_as_pdf_outlined
                                        : Icons.image_outlined,
                                    size: 18,
                                  ),
                                  label: Text(
                                    file.name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  onPressed: () => _openFile(file),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
      ],
    );
  }

  /// 결석 사유 첨부 파일 보기 (이미지·PDF) — 알림 상세와 같은 뷰어
  Future<void> _openFile(_AbsenceFile file) => openAbsenceFile(
    context,
    AbsenceFile(id: file.id, name: file.name, contentType: file.contentType),
  );

  Widget _buildCalendarContent(
    Map<DateTime, List<_BusAbsences>> absencesByDate, {
    bool loading = false,
    Object? error,
  }) {
    final colors = Theme.of(context).colorScheme;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _buildMonthHeader(),
        const SizedBox(height: 8),
        // 달력은 결석 목록을 불러오는 중이거나 실패해도 항상 보여 준다
        _buildMonthGrid(absencesByDate),
        if (loading)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (error != null)
          Card(
            margin: const EdgeInsets.only(top: 16),
            color: colors.errorContainer,
            child: ListTile(
              leading: Icon(Icons.error_outline, color: colors.onErrorContainer),
              title: Text(
                AppErrorMessage.from(
                  error,
                  fallback: '결석 정보를 불러오지 못했습니다.',
                ),
                style: TextStyle(color: colors.onErrorContainer),
              ),
              trailing: TextButton(
                onPressed: () => _changeMonth(0),
                child: const Text('다시 시도'),
              ),
            ),
          )
        else
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
        title: const Text('출결 확인'),
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
          try {
            await future;
          } catch (_) {
            // 오류는 달력 아래 카드로 보여 준다
          }
        },
        child: FutureBuilder<Map<DateTime, List<_BusAbsences>>>(
          key: ValueKey('${_displayedMonth.year}-${_displayedMonth.month}'),
          future: _monthlyAbsences,
          builder: (context, snapshot) => _buildCalendarContent(
            snapshot.data ?? const {},
            loading:
                snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData,
            error: snapshot.hasData ? null : snapshot.error,
          ),
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
    this.details = const [],
  });

  final String name;
  final String? plateNumber;
  final List<ChildStudent> students;

  /// students 와 같은 순서의 결석 사유·첨부 파일
  final List<_AbsenceDetail> details;
}

class _AbsenceDetail {
  const _AbsenceDetail({
    this.reasonText,
    this.files = const [],
    this.attendanceId,
    this.status,
  });

  final String? reasonText;
  final List<_AbsenceFile> files;
  final int? attendanceId;
  final String? status;

  String get statusLabel => switch (status) {
    'CONFIRMED' => '확인됨',
    'REJECTED' => '반려',
    'REQUESTED' => '확인 대기',
    _ => '결석',
  };

  factory _AbsenceDetail.fromJson(Map<String, dynamic> json) {
    final files = json['files'];
    final reason = json['reason_text'] as String?;
    return _AbsenceDetail(
      attendanceId: json['attendance_id'] as int?,
      status: json['status'] as String?,
      reasonText: reason == null || reason.trim().isEmpty ? null : reason,
      files: files is List
          ? [
              for (final file in files)
                _AbsenceFile.fromJson(Map<String, dynamic>.from(file as Map)),
            ]
          : const [],
    );
  }
}

class _AbsenceFile {
  const _AbsenceFile({
    required this.id,
    required this.name,
    this.contentType,
  });

  final int id;
  final String name;
  final String? contentType;

  bool get isPdf =>
      contentType == 'application/pdf' || name.toLowerCase().endsWith('.pdf');
  bool get isImage =>
      contentType?.startsWith('image/') == true ||
      RegExp(r'\.(png|jpe?g|gif|webp)$', caseSensitive: false).hasMatch(name);

  factory _AbsenceFile.fromJson(Map<String, dynamic> json) {
    final id = json['file_id'] ?? json['id'];
    return _AbsenceFile(
      id: id is int ? id : int.parse(id.toString()),
      name: json['file_name'] as String? ?? '첨부 파일',
      contentType: json['content_type'] as String?,
    );
  }
}
