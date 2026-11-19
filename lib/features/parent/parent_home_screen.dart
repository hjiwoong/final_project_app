import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../core/auth/session.dart';
import '../../core/errors/app_error_message.dart';
import '../../core/notifications/in_app_notification_banner.dart';
import '../../data/api/api_repository.dart';
import '../../data/models/child_link_request.dart';
import '../../data/models/child_student.dart';
import '../../widgets/logout_confirmation_dialog.dart';
import '../auth/child_link_request_screen.dart';
import '../auth/login_screen.dart';
import 'bus_status_screen.dart';
import 'child_link_request_status_screen.dart';
import 'missed_dropoff_alert_screen.dart';
import 'parent_attendance_screen.dart';
import 'parent_trip_screens.dart';
import 'unread_notification_store.dart';

class ParentHomeScreen extends StatefulWidget {
  const ParentHomeScreen({this.active = true, super.key});

  final bool active;

  @override
  State<ParentHomeScreen> createState() => _ParentHomeScreenState();
}

class _ParentHomeScreenState extends State<ParentHomeScreen>
    with WidgetsBindingObserver {
  late DateTime _loadedDate;
  late Future<List<ChildStudent>> _children;
  late Future<List<Map<String, dynamic>>> _buses;
  late Future<int> _alerts;
  late Future<int> _unread;
  late Future<List<ChildLinkRequest>> _requests;
  final Set<int> _saving = {};
  Timer? _midnightRefresh;
  bool _loggingOut = false;
  int _unreadGeneration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startLoads();
    _scheduleMidnightRefresh();
  }

  Future<T> _guard<T>(Future<T> future) {
    final guarded = _handleAuth(future);
    _settled(guarded);
    return guarded;
  }

  Future<T> _handleAuth<T>(Future<T> future) async {
    try {
      return await future;
    } on DioException catch (error) {
      if (error.response?.statusCode == 401 && !_loggingOut) {
        _loggingOut = true;
        await Session.clear();
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (_) => false,
          );
        }
      }
      rethrow;
    }
  }

  void _startLoads() {
    _loadedDate = DateUtils.dateOnly(DateTime.now());
    final api = ApiRepository.instance;
    _children = _guard(api.getChildren(date: _loadedDate));
    _buses = _guard(api.getParentBusStatus());
    _alerts = _guard(api.getOpenParentAlertCount());
    _loadUnread();
    // A request is needed to discover pending requests even with linked children.
    _requests = _guard(api.getChildRequests());
  }

  void _loadUnread() {
    final generation = ++_unreadGeneration;
    _unread = _guard(ApiRepository.instance.getNotificationUnreadCount()).then((
      count,
    ) {
      if (mounted && !_loggingOut && generation == _unreadGeneration) {
        UnreadNotificationStore.setCount(count);
      }
      return count;
    });
    _settled(_unread);
  }

  Future<void> _refresh() async {
    setState(_startLoads);
    await Future.wait<void>([
      _settled(_children),
      _settled(_buses),
      _settled(_alerts),
      _settled(_unread),
      _settled(_requests),
    ]);
  }

  Future<void> _settled<T>(Future<T> future) async {
    try {
      await future;
    } catch (error) {
      debugPrint('학부모 홈 데이터 조회 실패: $error');
    }
  }

  void _reloadChildren() {
    setState(() {
      _loadedDate = DateUtils.dateOnly(DateTime.now());
      _children = _guard(ApiRepository.instance.getChildren(date: _loadedDate));
    });
  }

  void _scheduleMidnightRefresh() {
    _midnightRefresh?.cancel();
    final now = DateTime.now();
    _midnightRefresh = Timer(
      DateTime(now.year, now.month, now.day + 1).difference(now),
      () {
        if (!mounted) return;
        _refresh();
        _scheduleMidnightRefresh();
      },
    );
  }

  @override
  void didUpdateWidget(ParentHomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.active && widget.active) _refresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (DateUtils.dateOnly(DateTime.now()) != _loadedDate) _refresh();
    _scheduleMidnightRefresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _midnightRefresh?.cancel();
    super.dispose();
  }

  Widget _error(String area, VoidCallback retry) => Card(
    child: ListTile(
      title: Text('$area\n불러오지 못했어요 · 다시 시도'),
      trailing: const Icon(Icons.refresh),
      onTap: retry,
    ),
  );

  Future<void> _open(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    if (mounted &&
        (page is ParentTripAttendanceScreen ||
            page is ParentAttendanceScreen)) {
      _reloadChildren();
    }
  }

  Widget _alertSection() => FutureBuilder<int>(
    future: _alerts,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return _error('안전 알림', () {
          setState(() {
            _alerts = _guard(ApiRepository.instance.getOpenParentAlertCount());
          });
        });
      }
      if (!snapshot.hasData || snapshot.data == 0) {
        return const SizedBox.shrink();
      }
      return Card(
        color: Theme.of(context).colorScheme.errorContainer,
        child: ListTile(
          leading: Icon(
            Icons.warning_amber_rounded,
            color: Theme.of(context).colorScheme.error,
          ),
          title: Text('미하차 경고 ${snapshot.data}건'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _open(const MissedDropoffAlertScreen()),
        ),
      );
    },
  );

  String _status(ChildStudent child, Map<String, dynamic>? bus) {
    if (child.busStatus == 'CLOSED') return '오늘 운행 종료';
    if (child.isAbsent) return '오늘 결석';
    if (child.alightingConfirmedAt != null) return '하차 완료';
    if (child.boardingConfirmedAt != null) return '승차 중';
    if (child.busStatus == 'IN_PROGRESS') return '운행 중';
    if (child.busStatus == 'NOT_ASSIGNED') return '배정된 버스 없음';
    final time = DateTime.tryParse(
      bus?['scheduled_at']?.toString() ?? '',
    )?.toLocal();
    if (time == null) return '운행 전';
    return '운행 전 · ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')} 출발 예정';
  }

  Color _statusColor(ChildStudent child) {
    if (child.busStatus == 'CLOSED') return Colors.grey;
    if (child.isAbsent) return Colors.grey;
    if (child.alightingConfirmedAt != null) return Colors.green;
    if (child.boardingConfirmedAt != null || child.busStatus == 'IN_PROGRESS') {
      return Colors.blue;
    }
    return Colors.grey;
  }

  Future<void> _setAttendance(ChildStudent child) async {
    if (_saving.contains(child.id)) return;
    final date = DateUtils.dateOnly(DateTime.now());
    setState(() => _saving.add(child.id));
    try {
      await _guard(
        ApiRepository.instance.setChildAttendance(
          child,
          isAbsent: !child.isAbsent,
          date: date,
        ),
      );
      if (!mounted) return;
      _reloadChildren();
    } catch (error) {
      if (mounted && !_loggingOut) {
        InAppNotificationBanner.showMessage(
          AppErrorMessage.from(
            error,
            fallback: '결석 정보를 저장하지 못했습니다. 다시 시도해 주세요.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving.remove(child.id));
    }
  }

  Widget _childCard(ChildStudent child, Map<String, dynamic>? bus) {
    final running =
        child.busStatus == 'IN_PROGRESS' || bus?['status'] == 'IN_PROGRESS';
    final tripId = bus?['status'] == 'IN_PROGRESS'
        ? (bus?['trip_id'] as int?)
        : child.tripId;
    final canChangeAttendance =
        child.busStatus != 'CLOSED' &&
        !running &&
        child.boardingConfirmedAt == null &&
        child.alightingConfirmedAt == null &&
        (child.isAbsent ||
            child.busStatus == 'NOT_STARTED' ||
            child.busStatus == 'NOT_ASSIGNED');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(child.name, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              [
                if (child.className != null) child.className!,
                child.busName ?? bus?['bus_name']?.toString() ?? '버스 미배정',
              ].join(' · '),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.circle, size: 10, color: _statusColor(child)),
                const SizedBox(width: 8),
                Expanded(child: Text(_status(child, bus))),
              ],
            ),
            if (child.busStatus != 'CLOSED' && running && tripId != null) ...[
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => _open(BusStatusScreen(tripId: tripId)),
                child: const Text('실시간 위치 보기'),
              ),
            ] else if (canChangeAttendance) ...[
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: _saving.contains(child.id)
                    ? null
                    : () => _setAttendance(child),
                child: Text(child.isAbsent ? '결석 취소' : '오늘 결석 신청'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _childrenSection() => FutureBuilder<List<Map<String, dynamic>>>(
    future: _buses,
    builder: (context, busSnapshot) {
      return FutureBuilder<List<ChildStudent>>(
        future: _children,
        builder: (context, childrenSnapshot) {
          final buses = {
            for (final bus in busSnapshot.data ?? <Map<String, dynamic>>[])
              bus['bus_id']: bus,
          };
          return Column(
            children: [
              if (busSnapshot.hasError)
                _error(
                  '버스 운행 정보',
                  () => setState(() {
                    _buses = _guard(
                      ApiRepository.instance.getParentBusStatus(),
                    );
                  }),
                ),
              if (childrenSnapshot.hasError)
                _error('자녀 정보', _reloadChildren)
              else if (!childrenSnapshot.hasData)
                const Center(child: CircularProgressIndicator())
              else if (childrenSnapshot.data!.isEmpty)
                const Card(child: ListTile(title: Text('연결된 자녀가 없습니다.')))
              else
                for (final child in childrenSnapshot.data!)
                  _childCard(child, buses[child.busId]),
            ],
          );
        },
      );
    },
  );

  Widget _requestSection() => FutureBuilder<List<ChildLinkRequest>>(
    future: _requests,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return _error(
          '자녀 연결 요청',
          () => setState(() {
            _requests = _guard(ApiRepository.instance.getChildRequests());
          }),
        );
      }
      if (!snapshot.hasData) return const SizedBox.shrink();
      return FutureBuilder<List<ChildStudent>>(
        future: _children,
        builder: (context, childrenSnapshot) {
          final pending = snapshot.data!.any(
            (request) => request.status == 'PENDING',
          );
          if (!pending &&
              (!childrenSnapshot.hasData ||
                  childrenSnapshot.data!.isNotEmpty)) {
            return const SizedBox.shrink();
          }
          return Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: ListTile(
              leading: const Icon(Icons.family_restroom),
              title: Text(pending ? '자녀 연결 요청 승인 대기' : '자녀 연결 요청'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                if (pending) {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ChildLinkRequestStatusScreen(),
                    ),
                  );
                } else {
                  final email = Session.email;
                  if (email == null || email.isEmpty) {
                    InAppNotificationBanner.showMessage(
                      '로그인한 계정 정보를 확인할 수 없습니다.',
                    );
                    return;
                  }
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ChildLinkRequestScreen(email: email),
                    ),
                  );
                }
                if (mounted) _refresh();
              },
            ),
          );
        },
      );
    },
  );

  Widget _quickMenu() {
    final items = <(String, IconData, Widget)>[
      ('버스 위치', Icons.directions_bus_outlined, const BusStatusScreen()),
      ('승하차 기록', Icons.fact_check_outlined, const ParentTripAttendanceScreen()),
      ('안전 알림', Icons.warning_amber_rounded, const MissedDropoffAlertScreen()),
      ('결석·일정', Icons.event_available_outlined, const ParentAttendanceScreen()),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.2,
      children: [
        for (final item in items)
          Card(
            child: InkWell(
              onTap: () => _open(item.$3),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(item.$2),
                  const SizedBox(height: 6),
                  Text(item.$1),
                ],
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      automaticallyImplyLeading: false,
      title: const Text('학부모 홈'),
      actions: [
        IconButton(
          icon: const Icon(Icons.logout),
          tooltip: '로그아웃',
          onPressed: () async {
            if (!await showLogoutConfirmationDialog(context) ||
                !context.mounted) {
              return;
            }
            await Session.clear();
            if (!context.mounted) return;
            Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (_) => false,
            );
          },
        ),
      ],
    ),
    body: RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _alertSection(),
          const Text(
            '오늘의 자녀',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _childrenSection(),
          const SizedBox(height: 24),
          const Text(
            '빠른 메뉴',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _quickMenu(),
          const SizedBox(height: 16),
          _requestSection(),
          FutureBuilder<int>(
            future: _unread,
            builder: (context, snapshot) => snapshot.hasError
                ? _error('읽지 않은 알림', () => setState(_loadUnread))
                : const SizedBox.shrink(),
          ),
        ],
      ),
    ),
  );
}
