import 'package:flutter/material.dart';

import '../../data/api/api_repository.dart';
import '../../data/models/child_student.dart';
import '../../widgets/primary_button.dart';

/// 출석·결석 설정: 결석이면 탑승 예정 인원에서 빠져 오경고 감소
class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  bool _loading = true;
  bool _saving = false;
  String? _error;
  List<ChildStudent> _children = [];
  final Map<int, bool> _absent = {};

  @override
  void initState() {
    super.initState();
    _loadChildren();
  }

  Future<void> _loadChildren() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final children = await ApiRepository.instance.getChildren();
      if (!mounted) return;
      setState(() {
        _children = children;
        _absent
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
      final today = DateTime.now();
      for (final child in _children) {
        await ApiRepository.instance.setChildAttendance(
          child,
          isAbsent: _absent[child.id] ?? false,
          date: today,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('출석 상태를 저장했습니다.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('출석 상태를 저장하지 못했습니다. ($e)')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('출석·결석')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _loadChildren,
                      child: const Text('다시 시도'),
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  Expanded(
                    child: _children.isEmpty
                        ? const Center(child: Text('연결된 자녀가 없습니다.'))
                        : ListView(
                            children: _children
                                .map(
                                  (child) => SwitchListTile(
                                    title: Text(child.name),
                                    subtitle: Text(
                                      child.className ?? '오늘 결석 여부',
                                    ),
                                    value: _absent[child.id] ?? false,
                                    onChanged: (value) => setState(
                                      () => _absent[child.id] = value,
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                  ),
                  PrimaryButton(
                    label: '저장',
                    loading: _saving,
                    onPressed: _saving || _children.isEmpty ? null : _save,
                  ),
                ],
              ),
      ),
    );
  }
}
