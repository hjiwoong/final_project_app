import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../core/errors/app_error_message.dart';
import '../../core/notifications/in_app_notification_banner.dart';
import '../../core/sync/attendance_sync.dart';
import '../../data/api/api_repository.dart';
import '../../data/models/child_attendance.dart';
import '../../data/models/child_student.dart';
import '../../theme/app_colors.dart';
import '../../widgets/primary_button.dart';

class ParentAttendanceScreen extends StatefulWidget {
  const ParentAttendanceScreen({this.active = true, super.key});

  final bool active;

  @override
  State<ParentAttendanceScreen> createState() => _ParentAttendanceScreenState();
}

class _ParentAttendanceScreenState extends State<ParentAttendanceScreen> {
  static const _reasonTypes = <String, String>{
    'SICK': '질병',
    'FIELD_TRIP': '현장체험',
    'FAMILY': '가족 사유',
    'OTHER': '기타',
  };

  DateTime _selectedDate = DateUtils.dateOnly(DateTime.now());
  DateTime _focusedDay = DateUtils.dateOnly(DateTime.now());
  bool _childrenLoading = true;
  bool _attendanceLoading = false;
  // 달별로 불러오는 중/실패 상태를 따로 둔다. 달을 빠르게 넘겨도 이전 달 응답이
  // 지금 보고 있는 달의 로딩 표시를 끄거나 오류를 띄우지 않게 하려는 것.
  final Set<String> _loadingMonths = {};
  String? _calendarErrorMonth;
  bool _saving = false;
  String? _childrenError;
  String? _calendarError;
  List<ChildStudent> _children = [];
  ChildStudent? _selectedChild;
  ChildAttendance? _attendance;
  bool _isAbsent = false;
  String? _reasonType;
  final _reasonMemoController = TextEditingController();
  final List<XFile> _newFiles = [];
  final Map<String, List<ChildAttendance>> _attendanceByMonth = {};
  Timer? _deadlineTimer;
  Timer? _deadlineAccentTimer;
  DateTime? _scheduledDeadline;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _loadChildren();
  }

  @override
  void didUpdateWidget(ParentAttendanceScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.active && widget.active) _loadChildren();
  }

  @override
  void dispose() {
    _deadlineTimer?.cancel();
    _deadlineAccentTimer?.cancel();
    _reasonMemoController.dispose();
    super.dispose();
  }

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  String _monthKey(DateTime date) => '${date.year}-${date.month}';

  bool get _isPastSelected => DateUtils.dateOnly(
    _selectedDate,
  ).isBefore(DateUtils.dateOnly(DateTime.now()));

  bool get _canEdit =>
      !_isPastSelected && _attendance?.editable == true && !_attendanceLoading;

  Future<void> _loadChildren() async {
    if (mounted) {
      setState(() {
        _childrenLoading = true;
        _childrenError = null;
      });
    }

    try {
      final children = await ApiRepository.instance.getChildren();
      if (!mounted) return;
      setState(() {
        _children = children;
        _selectedChild = children.isEmpty ? null : children.first;
        _attendance = null;
        _recentAttendance = null;
        _newFiles.clear();
        _childrenLoading = false;
        _attendanceByMonth.clear();
        _loadingMonths.clear();
        _calendarError = null;
        _calendarErrorMonth = null;
      });
      if (_selectedChild != null) {
        await Future.wait([_loadMonth(_focusedDay), _loadAttendance()]);
      }
    } catch (error) {
      if (!mounted) return;
      if (error is DioException &&
          (error.response?.statusCode == 403 ||
              error.response?.statusCode == 404)) {
        InAppNotificationBanner.showMessage('자녀 정보를 찾을 수 없어요');
        await Navigator.of(context).maybePop();
        return;
      }
      setState(() {
        _childrenError = AppErrorMessage.from(
          error,
          fallback: '자녀 정보를 불러오지 못했습니다. 다시 시도해 주세요.',
        );
        _childrenLoading = false;
      });
    }
  }

  Future<void> _selectChild(ChildStudent? child) async {
    if (child == null || child.id == _selectedChild?.id) return;
    _scheduledDeadline = null;
    setState(() {
      _selectedChild = child;
      _attendance = null;
      _recentAttendance = null;
      _isAbsent = false;
      _reasonType = null;
      _reasonMemoController.clear();
      _newFiles.clear();
      _attendanceByMonth.clear();
      _calendarError = null;
      _calendarErrorMonth = null;
      _loadingMonths.clear();
    });
    await Future.wait([_loadMonth(_focusedDay), _loadAttendance()]);
  }

  Future<void> _selectDate(DateTime date) async {
    final selected = DateUtils.dateOnly(date);
    final monthChanged = _monthKey(selected) != _monthKey(_focusedDay);
    _scheduledDeadline = null;
    setState(() {
      _selectedDate = selected;
      _focusedDay = selected;
      _attendance = null;
      _isAbsent = false;
      _reasonType = null;
      _reasonMemoController.clear();
      _newFiles.clear();
      _recentAttendance = null;
    });
    await Future.wait([
      _loadAttendance(),
      if (monthChanged) _loadMonth(selected),
    ]);
  }

  Future<void> _loadMonth(DateTime month, {bool retry = false}) async {
    final child = _selectedChild;
    if (child == null) return;
    final key = _monthKey(month);
    if (!retry && _attendanceByMonth.containsKey(key)) {
      if (mounted && _calendarErrorMonth == key) {
        setState(() {
          _calendarError = null;
          _calendarErrorMonth = null;
        });
      }
      return;
    }
    if (_loadingMonths.contains(key)) return;

    if (mounted) {
      setState(() {
        _loadingMonths.add(key);
        if (_calendarErrorMonth == key) {
          _calendarError = null;
          _calendarErrorMonth = null;
        }
      });
    }

    final from = DateTime(month.year, month.month);
    final to = DateTime(month.year, month.month + 1, 0);
    try {
      final records = await ApiRepository.instance.getChildAttendances(
        child: child,
        from: from,
        to: to,
      );
      if (!mounted || child.id != _selectedChild?.id) return;
      setState(() {
        _attendanceByMonth[key] = records;
        _loadingMonths.remove(key);
      });
    } catch (error) {
      if (!mounted || child.id != _selectedChild?.id) return;
      setState(() {
        _loadingMonths.remove(key);
        _calendarError = '출결 기록을 불러오지 못했어요.';
        _calendarErrorMonth = key;
      });
    }
  }

  Future<void> _loadAttendance() async {
    final child = _selectedChild;
    if (child == null) return;
    final generation = ++_loadGeneration;
    _deadlineTimer?.cancel();
    _deadlineAccentTimer?.cancel();
    setState(() {
      _attendanceLoading = true;
    });

    try {
      final attendance = await ApiRepository.instance.getChildAttendanceRecord(
        child,
        date: _selectedDate,
      );
      if (!mounted ||
          generation != _loadGeneration ||
          child.id != _selectedChild?.id) {
        return;
      }
      final previousDeadline = _attendance?.deadlineAt;
      if (previousDeadline != attendance.deadlineAt) _scheduledDeadline = null;
      setState(() {
        _attendance = attendance;
        _isAbsent = attendance.isAbsent;
        _reasonType = attendance.reasonType;
        _reasonMemoController.text = attendance.reasonMemo ?? '';
        _newFiles.clear();
        _attendanceLoading = false;
      });
      _scheduleDeadlineRefresh(attendance);
      if (attendance.isAbsent && attendance.editable && !_isPastSelected) {
        unawaited(_loadRecentReason());
      }
    } catch (error) {
      if (!mounted ||
          generation != _loadGeneration ||
          child.id != _selectedChild?.id) {
        return;
      }
      if (error is DioException &&
          (error.response?.statusCode == 403 ||
              error.response?.statusCode == 404)) {
        InAppNotificationBanner.showMessage('자녀 정보를 찾을 수 없어요');
        await Navigator.of(context).maybePop();
        return;
      }
      setState(() => _attendanceLoading = false);
      InAppNotificationBanner.showMessage(
        AppErrorMessage.from(error, fallback: '출결 정보를 불러오지 못했습니다. 다시 시도해 주세요.'),
      );
    }
  }

  void _scheduleDeadlineRefresh(ChildAttendance attendance) {
    final deadline = attendance.deadlineAt;
    if (deadline == null ||
        !attendance.editable ||
        _isPastSelected ||
        _scheduledDeadline == deadline) {
      return;
    }

    final delay = deadline.difference(DateTime.now());
    _scheduledDeadline = deadline;
    _deadlineTimer = Timer(delay.isNegative ? Duration.zero : delay, () {
      if (mounted && _selectedDate == attendance.date) {
        _loadAttendance();
      }
    });
    final accentDelay = deadline
        .subtract(const Duration(minutes: 30))
        .difference(DateTime.now());
    if (accentDelay > Duration.zero) {
      _deadlineAccentTimer = Timer(accentDelay, () {
        if (mounted) setState(() {});
      });
    }
  }

  Future<void> _save() async {
    final child = _selectedChild;
    if (child == null || !_canEdit || _saving) return;
    setState(() => _saving = true);
    try {
      final files = _isAbsent ? List<XFile>.of(_newFiles) : const <XFile>[];
      final attendanceId = await ApiRepository.instance.saveChildAttendance(
        child: child,
        date: _selectedDate,
        isAbsent: _isAbsent,
        reasonType: _isAbsent ? _reasonType : null,
        reasonMemo: _isAbsent ? _reasonMemoController.text.trim() : null,
      );
      final uploadErrors = <String>[];
      for (final file in files) {
        try {
          await ApiRepository.instance.uploadChildAttendanceFile(
            attendanceId: attendanceId,
            file: file,
          );
        } on DioException catch (error) {
          uploadErrors.add(
            '${file.name}: ${_attendanceErrorMessage(error, fallback: '파일을 첨부하지 못했습니다.')}',
          );
        } catch (error) {
          uploadErrors.add(
            '${file.name}: ${AppErrorMessage.from(error, fallback: '파일을 첨부하지 못했습니다.')}',
          );
        }
      }

      AttendanceSync.notifyChanged(); // 홈 등 다른 화면도 바로 반영
      if (mounted && files.isNotEmpty) {
        setState(() => _newFiles.clear());
      }
      await Future.wait([
        _loadAttendance(),
        _loadMonth(_selectedDate, retry: true),
      ]);
      if (!mounted) return;
      InAppNotificationBanner.showMessage(
        uploadErrors.isEmpty ? '출결 정보를 저장했습니다.' : uploadErrors.join('\n'),
      );
    } on DioException catch (error) {
      if (!mounted) return;
      if (error.response?.statusCode == 409) {
        InAppNotificationBanner.showMessage(
          _attendanceErrorMessage(error, fallback: '변경 마감 시간이 지났어요'),
        );
        await _loadAttendance();
      } else {
        InAppNotificationBanner.showMessage(
          _attendanceErrorMessage(
            error,
            fallback: '출결 정보를 저장하지 못했습니다. 다시 시도해 주세요.',
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      InAppNotificationBanner.showMessage(
        AppErrorMessage.from(error, fallback: '출결 정보를 저장하지 못했습니다. 다시 시도해 주세요.'),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _loadRecentReason() async {
    final child = _selectedChild;
    if (child == null) return;

    Future<List<ChildAttendance>> recordsFor(DateTime month) async {
      final key = _monthKey(month);
      final cached = _attendanceByMonth[key];
      if (cached != null) return cached;
      final records = await ApiRepository.instance.getChildAttendances(
        child: child,
        from: DateTime(month.year, month.month),
        to: DateTime(month.year, month.month + 1, 0),
      );
      if (mounted && child.id == _selectedChild?.id) {
        setState(() => _attendanceByMonth[key] = records);
      }
      return records;
    }

    try {
      final now = DateUtils.dateOnly(DateTime.now());
      final currentMonth = await recordsFor(now);
      var previousAbsences = currentMonth
          .where((record) => record.isAbsent && record.date.isBefore(now))
          .toList();
      if (previousAbsences.isEmpty) {
        final previousMonth = DateTime(now.year, now.month - 1);
        final previousRecords = await recordsFor(previousMonth);
        previousAbsences = previousRecords
            .where((record) => record.isAbsent)
            .toList();
      }
      if (!mounted || child.id != _selectedChild?.id) return;
      previousAbsences.sort((a, b) => b.date.compareTo(a.date));
      setState(() {
        _recentAttendance = previousAbsences.isEmpty
            ? null
            : previousAbsences.first;
      });
    } catch (error) {
      if (mounted) {
        InAppNotificationBanner.showMessage(
          AppErrorMessage.from(error, fallback: '지난 출결 사유를 불러오지 못했습니다.'),
        );
      }
    }
  }

  String _attendanceErrorMessage(
    DioException error, {
    required String fallback,
  }) {
    if ([409, 413, 415].contains(error.response?.statusCode)) {
      final response = error.response?.data;
      final detail = response is Map ? response['detail'] : null;
      if (detail is String && detail.trim().isNotEmpty) return detail;
    }
    return AppErrorMessage.from(error, fallback: fallback);
  }

  ChildAttendance? _recentAttendance;

  Future<void> _reuseRecentReason() async {
    final recent = _recentAttendance;
    if (recent == null) {
      await _loadRecentReason();
      return;
    }
    setState(() {
      _reasonType = recent.reasonType;
      _reasonMemoController.text = recent.reasonMemo ?? '';
    });
  }

  Future<void> _pickAttachments() async {
    if (!_canEdit) return;
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );
      if (result == null || !mounted) return;
      final files = result.files;
      if (files.any((file) => file.path == null)) {
        throw StateError('선택한 파일을 읽을 수 없습니다.');
      }
      setState(() {
        _newFiles.addAll(
          files.map((file) => XFile(file.path!, name: file.name)),
        );
      });
    } catch (error) {
      if (!mounted) return;
      InAppNotificationBanner.showMessage(
        AppErrorMessage.from(error, fallback: '첨부 파일을 선택하지 못했습니다.'),
      );
    }
  }

  Future<void> _openAttachment(ChildAttendanceFile attachment) async {
    final child = _selectedChild;
    if (child == null) return;
    File? cachedFile;
    try {
      final bytes = await ApiRepository.instance.getChildAttendanceFile(
        child,
        fileId: attachment.id,
      );
      final cacheDirectory = await getTemporaryDirectory();
      final safeName = attachment.name.replaceAll(RegExp(r'[^\w.\-]'), '_');
      cachedFile = File(
        '${cacheDirectory.path}${Platform.pathSeparator}'
        'attendance_${child.id}_${attachment.id}_$safeName',
      );
      await cachedFile.writeAsBytes(bytes, flush: true);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: context.appColors.surface,
          child: SizedBox(
            width: 520,
            height: 600,
            child: Column(
              children: [
                ListTile(
                  title: Text(
                    attachment.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: context.appColors.textPrimary),
                  ),
                  trailing: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.close,
                      color: context.appColors.textSecondary,
                    ),
                  ),
                ),
                Expanded(
                  child: _isImage(attachment)
                      ? InteractiveViewer(
                          child: Image.file(cachedFile!, fit: BoxFit.contain),
                        )
                      : _isPdf(attachment)
                      ? SfPdfViewer.file(cachedFile!)
                      : Center(
                          child: Text(
                            '이 파일 형식은 앱에서 미리볼 수 없습니다.',
                            style: TextStyle(color: context.appColors.textSecondary),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        InAppNotificationBanner.showMessage(
          AppErrorMessage.from(error, fallback: '첨부 파일을 열지 못했습니다.'),
        );
      }
    } finally {
      if (cachedFile != null && await cachedFile.exists()) {
        await cachedFile.delete();
      }
    }
  }

  bool _isImage(ChildAttendanceFile file) =>
      file.contentType?.startsWith('image/') == true ||
      RegExp(
        r'\.(png|jpe?g|gif|webp)$',
        caseSensitive: false,
      ).hasMatch(file.name);

  bool _isPdf(ChildAttendanceFile file) =>
      file.contentType == 'application/pdf' ||
      file.name.toLowerCase().endsWith('.pdf');

  Color _statusColor(String? status) => switch (status) {
    'REQUESTED' => context.appColors.textPrimary,
    'CONFIRMED' => AppColors.success,
    'REJECTED' => AppColors.danger,
    _ => context.appColors.textSecondary,
  };

  Color _statusBackground(String? status) => switch (status) {
    'REQUESTED' => context.appColors.info,
    'CONFIRMED' => AppColors.success.withValues(alpha: 0.12),
    'REJECTED' => AppColors.danger.withValues(alpha: 0.10),
    _ => context.appColors.border,
  };

  String _statusLabel(String? status) => switch (status) {
    'REQUESTED' => '확인 대기',
    'CONFIRMED' => '확인됨',
    'REJECTED' => '반려됨',
    _ => '처리 상태 없음',
  };

  Widget _statusChip(String? status) => Container(
    constraints: const BoxConstraints(minHeight: 26),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: _statusBackground(status),
      borderRadius: BorderRadius.circular(13),
    ),
    alignment: Alignment.center,
    child: Text(
      _statusLabel(status),
      style: TextStyle(
        color: _statusColor(status),
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  Widget _buildCalendar() {
    final focusedKey = _monthKey(_focusedDay);
    final monthLoading = _loadingMonths.contains(focusedKey);
    final monthError = _calendarErrorMonth == focusedKey
        ? _calendarError
        : null;

    final records = _attendanceByMonth[_monthKey(_focusedDay)] ?? const [];
    final recordsByDate = <String, ChildAttendance>{
      for (final record in records) _dateKey(record.date): record,
    };

    final calendar = TableCalendar<ChildAttendance>(
      firstDay: DateTime(2020),
      lastDay: DateTime(2100, 12, 31),
      focusedDay: _focusedDay,
      startingDayOfWeek: StartingDayOfWeek.monday,
      calendarFormat: CalendarFormat.month,
      // 달마다 4~6주로 줄 수가 달라 아래 내용이 오르내리지 않게 항상 6줄로 그린다.
      sixWeekMonthsEnforced: true,
      headerStyle: HeaderStyle(
        titleCentered: true,
        formatButtonVisible: false,
        titleTextStyle: TextStyle(
          color: context.appColors.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        leftChevronIcon: Icon(Icons.chevron_left, color: context.appColors.textPrimary),
        rightChevronIcon: Icon(
          Icons.chevron_right,
          color: context.appColors.textPrimary,
        ),
      ),
      daysOfWeekStyle: DaysOfWeekStyle(
        weekdayStyle: TextStyle(color: context.appColors.textSecondary),
        weekendStyle: TextStyle(color: context.appColors.textSecondary),
      ),
      calendarStyle: CalendarStyle(
        defaultTextStyle: TextStyle(color: context.appColors.textPrimary),
        weekendTextStyle: TextStyle(color: context.appColors.textPrimary),
        outsideTextStyle: TextStyle(
          color: context.appColors.textSecondary.withValues(alpha: 0.55),
        ),
        todayDecoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.35),
          shape: BoxShape.circle,
        ),
        selectedDecoration: const BoxDecoration(
          color: AppColors.primaryDark,
          shape: BoxShape.circle,
        ),
      ),
      selectedDayPredicate: (day) => isSameDay(day, _selectedDate),
      eventLoader: (day) {
        final record = recordsByDate[_dateKey(day)];
        return record == null || !record.isAbsent ? const [] : [record];
      },
      onDaySelected: (selectedDay, focusedDay) {
        setState(() => _focusedDay = focusedDay);
        _selectDate(selectedDay);
      },
      onPageChanged: (focusedDay) {
        setState(() => _focusedDay = focusedDay);
        _loadMonth(focusedDay);
      },
      calendarBuilders: CalendarBuilders<ChildAttendance>(
        headerTitleBuilder: (context, date) => Text(
          '${date.year}년 ${date.month}월',
          style: TextStyle(
            color: context.appColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        dowBuilder: (context, day) => Center(
          child: Text(
            const ['월', '화', '수', '목', '금', '토', '일'][day.weekday - 1],
            style: TextStyle(color: context.appColors.textSecondary),
          ),
        ),
        markerBuilder: (context, date, events) {
          if (events.isEmpty) return null;
          final status = events.first.status;
          final dotColor = switch (status) {
            'REQUESTED' => AppColors.primaryDark,
            'CONFIRMED' => AppColors.success,
            'REJECTED' => AppColors.danger,
            _ => AppColors.primaryDark,
          };
          return Positioned(
            bottom: 3,
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
          );
        },
      ),
    );

    // 예전에는 처음 보는 달을 불러오는 동안 달력 자체를 로딩 표시로 바꿔서
    // 화면이 줄었다 늘어나고 넘기던 달력이 새로 만들어졌다.
    // 이제 달력은 그대로 두고 위에 얇은 진행 막대·오류 줄만 보여 준다.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 3,
          child: monthLoading
              ? const LinearProgressIndicator(color: AppColors.primaryDark)
              : null,
        ),
        if (monthError != null)
          Row(
            children: [
              Expanded(
                child: Text(
                  monthError,
                  style: TextStyle(color: context.appColors.textSecondary),
                ),
              ),
              TextButton(
                onPressed: monthLoading
                    ? null
                    : () => _loadMonth(_focusedDay, retry: true),
                child: const Text('다시 시도'),
              ),
            ],
          ),
        calendar,
      ],
    );
  }

  Widget _buildDeadlineNotice() {
    final deadline = _attendance?.deadlineAt;
    if (deadline == null) return const SizedBox.shrink();
    final color = !_attendance!.editable
        ? context.appColors.textSecondary
        : DateTime.now().isAfter(deadline.subtract(const Duration(minutes: 30)))
        ? AppColors.accent
        : context.appColors.textSecondary;
    final text = !_attendance!.editable
        ? '변경 마감됨'
        : '${deadline.hour.toString().padLeft(2, '0')}:'
              '${deadline.minute.toString().padLeft(2, '0')}까지 변경 가능';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(Icons.schedule, size: 16, color: color),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(color: color, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildReasonChips() => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: _reasonTypes.entries.map((entry) {
      final selected = entry.key == _reasonType;
      return ChoiceChip(
        label: Text(entry.value),
        selected: selected,
        onSelected: _canEdit
            ? (value) => setState(() => _reasonType = value ? entry.key : null)
            : null,
        selectedColor: AppColors.primary.withValues(alpha: 0.35),
        backgroundColor: context.appColors.surface,
        checkmarkColor: context.appColors.textPrimary,
        side: BorderSide(color: context.appColors.border),
        labelStyle: TextStyle(color: context.appColors.textPrimary),
      );
    }).toList(),
  );

  Widget _buildAttachmentButton({required bool prominent}) {
    return OutlinedButton.icon(
      onPressed: _canEdit ? _pickAttachments : null,
      style: OutlinedButton.styleFrom(
        foregroundColor: context.appColors.textPrimary,
        side: BorderSide(
          color: prominent ? AppColors.primaryDark : context.appColors.border,
          width: prominent ? 1.5 : 1,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: prominent ? 18 : 12,
          vertical: prominent ? 15 : 8,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: const Icon(Icons.attach_file),
      label: const Text('사진·파일 첨부'),
    );
  }

  Widget _buildAttachmentList() {
    final existing = _attendance?.files ?? const <ChildAttendanceFile>[];
    if (existing.isEmpty && _newFiles.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final file in existing)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.insert_drive_file,
              color: context.appColors.textSecondary,
            ),
            title: Text(
              file.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: context.appColors.textPrimary),
            ),
            trailing: Icon(
              Icons.open_in_new,
              color: context.appColors.textSecondary,
            ),
            onTap: () => _openAttachment(file),
          ),
        for (var index = 0; index < _newFiles.length; index++)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.attach_file,
              color: context.appColors.textSecondary,
            ),
            title: Text(
              _newFiles[index].name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: context.appColors.textPrimary),
            ),
            trailing: IconButton(
              onPressed: _canEdit
                  ? () => setState(() => _newFiles.removeAt(index))
                  : null,
              icon: Icon(Icons.close, color: context.appColors.textSecondary),
            ),
          ),
      ],
    );
  }

  Widget _buildPastDetails() {
    final attendance = _attendance;
    if (attendance == null) {
      return Text(
        '이 날짜의 출결 기록이 없습니다.',
        style: TextStyle(color: context.appColors.textSecondary),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (attendance.isAbsent) ...[
          Text(
            '사유: ${_reasonTypes[attendance.reasonType] ?? '미입력'}',
            style: TextStyle(color: context.appColors.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            '메모: ${attendance.reasonMemo?.isNotEmpty == true ? attendance.reasonMemo : '없음'}',
            style: TextStyle(color: context.appColors.textSecondary),
          ),
          const SizedBox(height: 8),
          _buildAttachmentList(),
        ] else
          Text(
            '결석 신청 없음',
            style: TextStyle(color: context.appColors.textSecondary),
          ),
      ],
    );
  }

  Widget _buildSelectedDay() {
    final attendance = _attendance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${_selectedDate.year}년 ${_selectedDate.month}월 ${_selectedDate.day}일',
                style: TextStyle(
                  color: context.appColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (attendance?.isAbsent == true) _statusChip(attendance?.status),
          ],
        ),
        if (attendance?.status == 'REJECTED') ...[
          const SizedBox(height: 6),
          Text(
            attendance?.rejectReason?.trim().isNotEmpty == true
                ? attendance!.rejectReason!.trim()
                : '관리자에게 문의해 주세요',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.danger, fontSize: 13),
          ),
        ],
        const SizedBox(height: 12),
        if (_attendanceLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(color: AppColors.primaryDark),
            ),
          )
        else if (_isPastSelected)
          _buildPastDetails()
        else if (attendance != null) ...[
          _buildDeadlineNotice(),
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Text('탑승'),
                  selected: !_isAbsent,
                  onSelected: _canEdit
                      ? (_) => setState(() => _isAbsent = false)
                      : null,
                  selectedColor: AppColors.primary.withValues(alpha: 0.35),
                  backgroundColor: context.appColors.surface,
                  side: BorderSide(color: context.appColors.border),
                  labelStyle: TextStyle(color: context.appColors.textPrimary),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ChoiceChip(
                  label: const Text('결석'),
                  selected: _isAbsent,
                  onSelected: _canEdit
                      ? (_) {
                          setState(() => _isAbsent = true);
                          _loadRecentReason();
                        }
                      : null,
                  selectedColor: AppColors.primary.withValues(alpha: 0.35),
                  backgroundColor: context.appColors.surface,
                  side: BorderSide(color: context.appColors.border),
                  labelStyle: TextStyle(color: context.appColors.textPrimary),
                ),
              ),
            ],
          ),
          if (_isAbsent) ...[
            const SizedBox(height: 12),
            if (_recentAttendance != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ActionChip(
                  label: const Text('지난번과 같은 사유'),
                  onPressed: _canEdit ? _reuseRecentReason : null,
                  backgroundColor: context.appColors.info,
                  labelStyle: TextStyle(color: context.appColors.textPrimary),
                  side: BorderSide.none,
                ),
              ),
            _buildReasonChips(),
            const SizedBox(height: 8),
            if (_reasonType == 'SICK' || _reasonType == 'FIELD_TRIP')
              _buildAttachmentButton(prominent: true)
            else
              _buildAttachmentButton(prominent: false),
            const SizedBox(height: 8),
            TextField(
              controller: _reasonMemoController,
              enabled: _canEdit,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: '사유 메모',
                labelStyle: TextStyle(color: context.appColors.textSecondary),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: context.appColors.border),
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: AppColors.primaryDark),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            _buildAttachmentList(),
          ],
          const SizedBox(height: 16),
          PrimaryButton(
            label: '저장',
            loading: _saving,
            onPressed: _canEdit && !_saving ? _save : null,
            color: AppColors.primary,
            foregroundColor: AppColors.onPrimary,
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appColors.background,
      appBar: AppBar(
        title: const Text('출석·결석 관리'),
        backgroundColor: context.appColors.background,
        foregroundColor: context.appColors.textPrimary,
      ),
      body: SafeArea(
        top: false,
        child: _childrenLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primaryDark),
              )
            : _childrenError != null
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _childrenError!,
                      style: TextStyle(color: context.appColors.textSecondary),
                    ),
                    TextButton(
                      onPressed: _loadChildren,
                      child: const Text('다시 시도'),
                    ),
                  ],
                ),
              )
            : _children.isEmpty
            ? Center(
                child: Text(
                  '연결된 자녀가 없습니다.',
                  style: TextStyle(color: context.appColors.textSecondary),
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  if (_children.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: DropdownButtonFormField<int>(
                        initialValue: _selectedChild?.id,
                        decoration: InputDecoration(
                          labelText: '자녀 선택',
                          labelStyle: TextStyle(color: context.appColors.textSecondary),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: context.appColors.border),
                          ),
                        ),
                        items: _children
                            .map(
                              (child) => DropdownMenuItem(
                                value: child.id,
                                child: Text(
                                  child.name,
                                  style: TextStyle(
                                    color: context.appColors.textPrimary,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (id) => _selectChild(
                          _children
                              .where((child) => child.id == id)
                              .firstOrNull,
                        ),
                      ),
                    ),
                  if (_children.length == 1)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        _selectedChild!.name,
                        style: TextStyle(
                          color: context.appColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  Text(
                    '월간 출결',
                    style: TextStyle(
                      color: context.appColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _buildCalendar(),
                  Divider(color: context.appColors.border, height: 24),
                  _buildSelectedDay(),
                ],
              ),
      ),
    );
  }
}
