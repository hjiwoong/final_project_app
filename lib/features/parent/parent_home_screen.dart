import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/auth/session.dart';
import '../../core/errors/app_error_message.dart';
import '../../core/notifications/in_app_notification_banner.dart';
import '../../data/api/api_repository.dart';
import '../../data/models/child_link_request.dart';
import '../../data/models/child_student.dart';
import '../../theme/app_colors.dart';
import '../auth/child_link_request_screen.dart';
import '../auth/login_screen.dart';
import 'bus_status_screen.dart';
import 'child_link_request_status_screen.dart';
import 'missed_dropoff_alert_screen.dart';
import 'notification_settings_screen.dart';
import 'notification_list_screen.dart';
import 'parent_attendance_screen.dart';
import 'parent_trip_screens.dart';
import 'unread_notification_store.dart';

class ParentHomeScreen extends StatefulWidget {
  const ParentHomeScreen({
    this.active = true,
    this.onOpenUrgentAlerts,
    super.key,
  });

  final bool active;
  final VoidCallback? onOpenUrgentAlerts;

  @override
  State<ParentHomeScreen> createState() => _ParentHomeScreenState();
}

class _ParentHomeScreenState extends State<ParentHomeScreen>
    with WidgetsBindingObserver {
  late DateTime _loadedDate;
  late Future<List<ChildStudent>> _children;
  late Future<List<Map<String, dynamic>>> _buses;
  late Future<({int total, List<Map<String, dynamic>> items})> _alerts;
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
    _children = _guard(
      api.getChildren(date: _loadedDate, debugLogResponse: true),
    );
    _buses = api.getParentBusStatus(debugLogResponse: true);
    _settled(_buses);
    _alerts = _loadAlerts();
    _settled(_alerts);
    _loadUnread();
    // A request is needed to discover pending requests even with linked children.
    _requests = _guard(api.getChildRequests());
  }

  Future<({int total, List<Map<String, dynamic>> items})> _loadAlerts() async {
    final page = await ApiRepository.instance.getParentAlertsPage(
      status: 'OPEN',
      limit: 1,
    );
    if (page.total > 0 &&
        (page.items.isEmpty || page.items.first['title'] is! String)) {
      throw const FormatException('OPEN 알림의 제목을 확인할 수 없습니다.');
    }
    return page;
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
      _children = _guard(
        ApiRepository.instance.getChildren(
          date: _loadedDate,
          debugLogResponse: true,
        ),
      );
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

  Widget _alertSection() =>
      FutureBuilder<({int total, List<Map<String, dynamic>> items})>(
        future: _alerts,
        builder: (context, snapshot) {
          final page = snapshot.data;
          if (snapshot.hasError ||
              page == null ||
              page.total == 0 ||
              page.items.isEmpty) {
            return const SizedBox.shrink();
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Material(
              color: AppColors.danger.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap:
                    widget.onOpenUrgentAlerts ??
                    () => _open(
                      const NotificationListScreen(urgentSelectionRequest: 1),
                    ),
                child: IntrinsicHeight(
                  child: Row(
                    children: [
                      Expanded(
                        child: ListTile(
                          leading: const Icon(
                            Icons.warning_amber_rounded,
                            color: AppColors.danger,
                          ),
                          title: Text(
                            '확인이 필요한 알림 ${page.total}건',
                            style: const TextStyle(
                              color: AppColors.danger,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            page.items.first['title'] as String,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );

  (String, Color, Color) _status(ChildStudent child) {
    if (child.isAbsent) {
      return ('결석', AppColors.danger.withValues(alpha: 0.1), AppColors.danger);
    }
    return switch (child.busStatus) {
      'IN_PROGRESS' => ('운행 중', AppColors.primary, AppColors.textPrimary),
      'CLOSED' => (
        '운행 종료',
        AppColors.success.withValues(alpha: 0.12),
        AppColors.success,
      ),
      'NOT_ASSIGNED' => ('배정 없음', AppColors.border, AppColors.textSecondary),
      _ => ('운행 전', AppColors.info, AppColors.textPrimary),
    };
  }

  Map<String, dynamic>? _matchingBus(
    ChildStudent child,
    List<Map<String, dynamic>> buses,
  ) {
    if (child.tripId != null) {
      for (final bus in buses) {
        if (bus['trip_id'] == child.tripId) return bus;
      }
    }
    if (child.busId != null) {
      for (final bus in buses) {
        if (bus['bus_id'] == child.busId) return bus;
      }
    }
    return null;
  }

  String? _departureTime(ChildStudent child, Map<String, dynamic>? bus) {
    if (bus == null ||
        child.busStatus == 'CLOSED' ||
        bus['status'] == 'CLOSED') {
      return null;
    }
    if (child.busStatus == 'IN_PROGRESS' || bus['status'] == 'IN_PROGRESS') {
      return '운행 중';
    }
    final time = DateTime.tryParse(
      bus['scheduled_at']?.toString() ?? '',
    )?.toLocal();
    if (time == null) return null;
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute 출발 예정';
  }

  Future<void> _setAttendance(ChildStudent child) async {
    if (_saving.contains(child.id)) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(child.isAbsent ? '결석을 취소할까요?' : '오늘 결석을 신청할까요?'),
        content: Text(
          child.isAbsent
              ? '${child.name} 학생의 오늘 결석 신청을 취소합니다.'
              : '${child.name} 학생의 오늘 결석을 신청합니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('확인'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || _saving.contains(child.id)) return;
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

  Widget _childCard(
    ChildStudent child,
    Map<String, dynamic>? bus, {
    required bool busLoading,
    required String? departureTime,
  }) {
    final running =
        !child.isAbsent &&
        child.alightingConfirmedAt == null &&
        (child.boardingConfirmedAt != null || child.busStatus == 'IN_PROGRESS');
    final tripId = (bus?['trip_id'] as int?) ?? child.tripId;
    final canChangeAttendance =
        child.isAbsent ||
        (!running &&
            child.alightingConfirmedAt == null &&
            child.busStatus != 'CLOSED' &&
            child.busStatus != 'NOT_ASSIGNED');
    final status = _status(child);
    return Card(
      color: AppColors.surface,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    child.name,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  height: 28,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: status.$2,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    widthFactor: 1,
                    child: Text(
                      status.$1,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: status.$3,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              [
                if (child.className != null) child.className!,
                child.busName ?? bus?['bus_name']?.toString() ?? '버스 미배정',
              ].join(' · '),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            if (departureTime != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.access_time,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      departureTime,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (running) ...[
              const SizedBox(height: 12),
              Tooltip(
                message: tripId == null && !busLoading
                    ? '운행 정보를 불러오지 못했습니다.'
                    : '',
                child: SizedBox(
                  height: 48,
                  child: FilledButton(
                    style: _childButtonStyle(AppColors.primary),
                    onPressed: tripId == null
                        ? null
                        : () => _open(BusStatusScreen(tripId: tripId)),
                    child: const Text('실시간 위치 보기'),
                  ),
                ),
              ),
              if (tripId == null && !busLoading)
                TextButton(
                  onPressed: () => setState(() {
                    _buses = ApiRepository.instance.getParentBusStatus(
                      debugLogResponse: true,
                    );
                    _settled(_buses);
                    _children = _guard(
                      ApiRepository.instance.getChildren(
                        date: _loadedDate,
                        debugLogResponse: true,
                      ),
                    );
                  }),
                  child: const Text('운행 정보를 불러오지 못했어요 · 다시 시도'),
                ),
            ] else if (canChangeAttendance) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: child.isAbsent
                        ? AppColors.surface
                        : AppColors.primary,
                    foregroundColor: AppColors.textPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: child.isAbsent
                          ? const BorderSide(
                              color: AppColors.primaryDark,
                              width: 1.5,
                            )
                          : BorderSide.none,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onPressed: _saving.contains(child.id)
                      ? null
                      : () => _setAttendance(child),
                  child: Text(child.isAbsent ? '결석 취소' : '오늘 결석 신청'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  ButtonStyle _childButtonStyle(Color background) => FilledButton.styleFrom(
    backgroundColor: background,
    foregroundColor: AppColors.textPrimary,
    minimumSize: const Size(0, 48),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    textStyle: const TextStyle(fontWeight: FontWeight.bold),
  );

  Widget _loadingCard() => Card(
    color: AppColors.surface,
    elevation: 0,
    margin: const EdgeInsets.only(bottom: 12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: const BorderSide(color: AppColors.border),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _skeletonBar(110, 16),
          const SizedBox(height: 12),
          _skeletonBar(160, 12),
          const SizedBox(height: 16),
          _skeletonBar(double.infinity, 48),
        ],
      ),
    ),
  );

  Widget _skeletonBar(double width, double height) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: AppColors.border,
      borderRadius: BorderRadius.circular(8),
    ),
  );

  Future<void> _openChildRequest() async {
    final email = Session.email;
    if (email == null || email.isEmpty) {
      InAppNotificationBanner.showMessage('로그인한 계정 정보를 확인할 수 없습니다.');
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ChildLinkRequestScreen(email: email)),
    );
    if (mounted) _refresh();
  }

  Widget _emptyChildren() => Card(
    color: AppColors.surface,
    elevation: 0,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: const BorderSide(color: AppColors.border),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '자녀를 연결해 주세요',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            child: FilledButton(
              style: _childButtonStyle(AppColors.primary),
              onPressed: _openChildRequest,
              child: const Text('자녀 연결 요청'),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _childrenSection() => FutureBuilder<List<Map<String, dynamic>>>(
    future: _buses,
    builder: (context, busSnapshot) {
      return FutureBuilder<List<ChildStudent>>(
        future: _children,
        builder: (context, childrenSnapshot) {
          final buses = busSnapshot.hasError
              ? <Map<String, dynamic>>[]
              : busSnapshot.data ?? <Map<String, dynamic>>[];
          return Column(
            children: [
              if (childrenSnapshot.hasError)
                Column(
                  children: [
                    const Text(
                      '정보를 불러오지 못했어요',
                      style: TextStyle(color: AppColors.textPrimary),
                    ),
                    TextButton(
                      onPressed: _reloadChildren,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primaryDark,
                      ),
                      child: const Text('다시 시도'),
                    ),
                  ],
                )
              else if (!childrenSnapshot.hasData)
                _loadingCard()
              else if (childrenSnapshot.data!.isEmpty)
                _emptyChildren()
              else
                for (final child in childrenSnapshot.data!)
                  _childCard(
                    child,
                    _matchingBus(child, buses),
                    busLoading:
                        busSnapshot.connectionState != ConnectionState.done,
                    departureTime: _departureTime(
                      child,
                      _matchingBus(child, buses),
                    ),
                  ),
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
      final pending = snapshot.data!.any(
        (request) => request.status == 'PENDING',
      );
      if (!pending) return const SizedBox.shrink();
      return Card(
        color: Theme.of(context).colorScheme.primaryContainer,
        child: ListTile(
          leading: const Icon(Icons.family_restroom),
          title: const Text('자녀 연결 요청 승인 대기'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const ChildLinkRequestStatusScreen(),
              ),
            );
            if (mounted) _refresh();
          },
        ),
      );
    },
  );

  Widget _quickMenu() {
    final items = <(String, IconData, Widget)>[
      ('버스 위치', Icons.directions_bus_outlined, const BusStatusScreen()),
      ('승하차 기록', Icons.fact_check_outlined, const ParentTripAttendanceScreen()),
      ('안전 알림', Icons.warning_amber_rounded, const MissedDropoffAlertScreen()),
      (
        '알림 설정',
        Icons.notifications_outlined,
        const NotificationSettingsScreen(),
      ),
    ];
    final scaledLabelSize = MediaQuery.textScalerOf(context).scale(14);
    final tileHeight =
        96.0 + (scaledLabelSize > 14 ? (scaledLabelSize - 14) * 3 : 0);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        mainAxisExtent: tileHeight,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Card(
          margin: EdgeInsets.zero,
          color: AppColors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _open(item.$3),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(item.$2, color: AppColors.primaryDark, size: 22),
                ),
                const SizedBox(height: 6),
                Text(
                  item.$1,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _header() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          SvgPicture.asset(
            'assets/images/tonghaki_bus.svg',
            width: 28,
            height: 28,
            semanticsLabel: '통학이 버스',
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              '통학이',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      const Text(
        '오늘도 안전하게 다녀와요',
        style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    body: SafeArea(
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          children: [
            _header(),
            const SizedBox(height: 16),
            _alertSection(),
            const Text(
              '오늘의 자녀',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            _childrenSection(),
            const SizedBox(height: 12),
            const Text(
              '빠른 메뉴',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
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
    ),
  );
}
