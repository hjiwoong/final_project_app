import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../core/auth/session.dart';
import '../../core/errors/app_error_message.dart';
import '../../core/notifications/in_app_notification_banner.dart';
import '../../data/api/api_repository.dart';
import '../../data/models/child_student.dart';
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
      return await ApiRepository.instance.getChildren(
        date: DateUtils.dateOnly(DateTime.now()),
      );
    } catch (error) {
      await _logoutIfUnauthorized(error);
      rethrow;
    }
  }

  void _reload() => setState(() {
    _children = _load();
  });

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
    if (confirmed != true || !mounted || child.tripId == null) return;
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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('승하차 기록')),
    body: FutureBuilder<List<ChildStudent>>(
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
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('오늘의 승하차 확인 기록'),
            if (children.isEmpty) const ListTile(title: Text('연결된 자녀가 없습니다.')),
            for (final child in children)
              Card(
                child: ListTile(
                  title: Text(child.name),
                  subtitle: Text(
                    '승차 ${_time(child.boardingConfirmedAt)} · 하차 ${_time(child.alightingConfirmedAt)}',
                  ),
                  trailing:
                      child.busStatus == 'IN_PROGRESS' &&
                          child.tripId != null &&
                          !child.isAbsent &&
                          child.alightingConfirmedAt == null
                      ? TextButton(
                          onPressed: _saving.contains(child.id)
                              ? null
                              : () => _confirm(
                                  child,
                                  child.boardingConfirmedAt == null
                                      ? 'BOARDING'
                                      : 'ALIGHTING',
                                ),
                          child: Text(
                            child.boardingConfirmedAt == null
                                ? '승차 완료'
                                : '하차 완료',
                          ),
                        )
                      : null,
                ),
              ),
          ],
        );
      },
    ),
  );
}
