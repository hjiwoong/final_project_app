import 'package:flutter/material.dart';

import '../../core/errors/app_error_message.dart';
import '../../data/api/api_repository.dart';
import '../../data/models/child_student.dart';
import '../../widgets/primary_button.dart';

import '../../core/notifications/in_app_notification_banner.dart';

class ParentAttendanceScreen extends StatefulWidget {
  const ParentAttendanceScreen({super.key});

  @override
  State<ParentAttendanceScreen> createState() => _ParentAttendanceScreenState();
}

class _ParentAttendanceScreenState extends State<ParentAttendanceScreen> {
  DateTime _selectedDate = DateTime.now();
  bool _loading = true;
  bool _saving = false;
  String? _error;
  List<ChildStudent> _children = [];
  final Map<int, bool> _apiAbsent = {};

  @override
  void initState() {
    super.initState();
    _loadChildren();
  }

  String _formatDate(DateTime date) {
    return '${date.year}년 ${date.month}월 ${date.day}일';
  }

  void _selectDate(DateTime date) {
    setState(() => _selectedDate = date);
    _loadChildren(date: date);
  }

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final firstDate = DateTime(today.year, today.month, today.day);
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isBefore(firstDate)
          ? firstDate
          : _selectedDate,
      firstDate: firstDate,
      lastDate: DateTime(2100, 12, 31),
      helpText: '신청 날짜 선택',
      cancelText: '취소',
      confirmText: '선택',
    );

    if (selectedDate != null && mounted) {
      _selectDate(selectedDate);
    }
  }

  Future<void> _loadChildren({DateTime? date}) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final children = await ApiRepository.instance.getChildren();
      if (!mounted) return;

      setState(() {
        _children = children;
        _apiAbsent
          ..clear()
          ..addEntries(
            children.map((child) => MapEntry(child.id, child.isAbsent)),
          );
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '자녀 정보를 불러오지 못했습니다. 다시 시도해 주세요.';
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    try {
      for (final child in _children) {
        await ApiRepository.instance.setChildAttendance(
          child,
          isAbsent: _apiAbsent[child.id] ?? false,
          date: _selectedDate,
        );
      }

      await _loadChildren(date: _selectedDate);
      if (!mounted) return;
      InAppNotificationBanner.showMessage('출석 상태를 저장했습니다.');
    } catch (e) {
      if (!mounted) return;
      InAppNotificationBanner.showMessage(
        AppErrorMessage.from(e, fallback: '출석 상태를 저장하지 못했습니다. 다시 시도해 주세요.'),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('출석·결석 관리')),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: ListView(
            children: [
              const SizedBox(height: 16),
              Text(
                '자녀의 출석·결석 관리로 탑승 여부를 설정합니다.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '신청 날짜',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text(_formatDate(_selectedDate)),
              ),
              const Text(
                '자녀별 출석 상태',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else if (_error != null)
                Column(
                  children: [
                    Text(_error!),
                    OutlinedButton(
                      onPressed: _loadChildren,
                      child: const Text('다시 시도'),
                    ),
                  ],
                )
              else if (_children.isEmpty)
                const Text('연결된 자녀가 없습니다.')
              else
                ..._children.map(
                  (child) => SwitchListTile(
                    title: Text(child.name),
                    subtitle: Text(child.className ?? '결석 여부'),
                    value: _apiAbsent[child.id] ?? false,
                    onChanged: (value) =>
                        setState(() => _apiAbsent[child.id] = value),
                  ),
                ),
              const SizedBox(height: 12),
              PrimaryButton(
                label: '저장',
                loading: _saving,
                onPressed:
                    _saving || _loading || _error != null || _children.isEmpty
                    ? null
                    : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
