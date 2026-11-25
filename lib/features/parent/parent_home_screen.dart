import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/auth/session.dart';
import '../../core/errors/app_error_message.dart';
import '../../core/notifications/in_app_notification_banner.dart';
import '../../core/sync/attendance_sync.dart';
import '../../data/api/api_repository.dart';
import '../../data/models/child_link_request.dart';
import '../../data/models/child_student.dart';
import '../../theme/app_colors.dart';
import '../auth/child_link_request_screen.dart';
import '../auth/login_screen.dart';
import 'alert_chat_screen.dart';
import 'bus_status_screen.dart';
import 'bus_trip_simulation.dart';
import 'child_link_request_status_screen.dart';
import 'notification_list_screen.dart';
import 'parent_attendance_screen.dart';
import 'parent_trip_screens.dart';
import 'unread_notification_store.dart';
import 'widgets/absence_request_sheet.dart';

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
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late DateTime _loadedDate;
  late Future<List<ChildStudent>> _children;
  late Future<List<Map<String, dynamic>>> _buses;
  late Future<({int total, List<Map<String, dynamic>> items})> _alerts;
  late Future<int> _unread;
  late Future<List<ChildLinkRequest>> _requests;
  final Set<int> _saving = {};
  Timer? _midnightRefresh;
  Timer? _autoRefresh;
  bool _loggingOut = false;
  int _unreadGeneration = 0;

  // ---------- 홈 안의 AI 채팅 ----------
  // 입력칸을 누르면 채팅 화면이 홈 위로 펼쳐지고, '작게 보기'로 다시 접힌다.
  // 접어도 대화는 남아 있고, 홈을 당겨서 새로고침하면 초기화된다.
  late final AnimationController _chatAnim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  );
  late final CurvedAnimation _chatCurve = CurvedAnimation(
    parent: _chatAnim,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );
  final _chatBarKey = GlobalKey();
  final _stackKey = GlobalKey();
  final _chatFocus = ValueNotifier<int>(0);
  Key _chatKey = UniqueKey();
  bool _chatMounted = false; // 한 번이라도 열었으면 true (대화 유지)
  bool _chatOpen = false;
  Alignment _chatOrigin = Alignment.center;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AttendanceSync.changes.addListener(_onAttendanceChanged);
    _startLoads();
    // 기사가 '승차 완료'·운행 종료를 하면 승하차 시간이 바뀌므로 홈을 보고 있는 동안 30초마다 조용히 갱신
    _autoRefresh = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && widget.active && !_loggingOut && !_chatOpen) {
        _silentRefresh();
      }
    });
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

  // resetChat: 홈을 당겨서 새로고침할 때만 true (탭 이동·자정 갱신 때는 대화 유지)
  Future<void> _refresh({bool resetChat = false}) async {
    final hadChat = _chatMounted;
    setState(() {
      _startLoads();
      if (resetChat) {
        _chatMounted = false;
        _chatOpen = false;
        _chatKey = UniqueKey();
        _chatAnim.value = 0;
      }
    });
    if (resetChat && hadChat) {
      InAppNotificationBanner.showMessage('새로고침해서 AI 채팅 내용이 초기화됐어요.');
    }
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

  // 어느 화면에서든 결석을 바꾸거나 운행 알림이 오면 홈의 자녀 카드·오늘 승하차를 바로 다시 불러온다
  void _onAttendanceChanged() {
    if (mounted && !_loggingOut) _silentRefresh();
  }

  /// 화면을 비우지 않고 자녀·버스 상태만 다시 불러온다 (이전 내용은 새 값이 올 때까지 그대로)
  void _silentRefresh() {
    final api = ApiRepository.instance;
    setState(() {
      _loadedDate = DateUtils.dateOnly(DateTime.now());
      _children = _guard(api.getChildren(date: _loadedDate));
      _buses = api.getParentBusStatus();
      _settled(_buses);
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
    // 다른 탭으로 가면 펼친 채팅은 접어 둔다 (대화 내용은 유지)
    if (oldWidget.active && !widget.active && _chatOpen) {
      _chatOpen = false;
      _chatAnim.value = 0;
      FocusManager.instance.primaryFocus?.unfocus();
    }
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
    AttendanceSync.changes.removeListener(_onAttendanceChanged);
    _midnightRefresh?.cancel();
    _autoRefresh?.cancel();
    _chatCurve.dispose();
    _chatAnim.dispose();
    _chatFocus.dispose();
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
                            style: TextStyle(
                              color: context.appColors.textSecondary,
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
      final label = switch (child.absenceStatus) {
        'CONFIRMED' => '결석 · 확인됨',
        'REJECTED' => '결석 · 반려',
        'REQUESTED' => '결석 · 확인 대기',
        _ => '결석',
      };
      return (label, AppColors.danger.withValues(alpha: 0.1), AppColors.danger);
    }
    if (child.alightingConfirmedAt != null) {
      return (
        '하차 완료',
        AppColors.success.withValues(alpha: 0.12),
        AppColors.success,
      );
    }
    if (child.boardingConfirmedAt != null) {
      return ('탑승 중', AppColors.primary, AppColors.onPrimary);
    }
    return switch (child.busStatus) {
      'IN_PROGRESS' => ('운행 중', AppColors.primary, AppColors.onPrimary),
      'CLOSED' => (
        '운행 종료',
        AppColors.success.withValues(alpha: 0.12),
        AppColors.success,
      ),
      'NOT_ASSIGNED' => ('배정 없음', context.appColors.border, context.appColors.textSecondary),
      _ => ('운행 전', context.appColors.info, context.appColors.textPrimary),
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

  /// 서버가 409 로 알려 주는 이유(예: '결석 신청 마감 시간이 지났습니다')는 그대로 보여 준다
  String _attendanceError(Object error) {
    if (error is DioException && error.response?.statusCode == 409) {
      final data = error.response?.data;
      final detail = data is Map ? data['detail'] : null;
      if (detail is String && detail.trim().isNotEmpty) return detail;
    }
    return AppErrorMessage.from(
      error,
      fallback: '결석 정보를 저장하지 못했습니다. 다시 시도해 주세요.',
    );
  }

  static const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

  String _dateLabel(DateTime date) =>
      '${date.month}월 ${date.day}일(${_weekdays[date.weekday - 1]})';

  /// 오늘 결석 신청(사유·첨부 시트) / 이미 결석이면 취소 확인
  Future<void> _setAttendance(ChildStudent child) async {
    if (_saving.contains(child.id)) return;
    final today = DateUtils.dateOnly(DateTime.now());
    if (child.isAbsent) {
      await _cancelAbsence(child, today, '오늘');
    } else {
      await _requestAbsence(child, today, '오늘');
    }
  }

  /// 사유·첨부를 받는 시트를 띄우고 결석 신청 → 첨부 업로드
  Future<void> _requestAbsence(
    ChildStudent child,
    DateTime date,
    String label,
  ) async {
    final request = await showAbsenceRequestSheet(
      context,
      childName: child.name,
      dateLabel: label,
    );
    if (request == null || !mounted || _saving.contains(child.id)) return;
    setState(() => _saving.add(child.id));
    try {
      final attendanceId = await _guard(
        ApiRepository.instance.saveChildAttendance(
          child: child,
          date: date,
          isAbsent: true,
          reasonType: request.reasonType,
          reasonMemo: request.memo,
        ),
      );
      var failed = 0;
      for (final file in request.files) {
        try {
          await _guard(
            ApiRepository.instance.uploadChildAttendanceFile(
              attendanceId: attendanceId,
              file: file,
            ),
          );
        } catch (error) {
          failed++;
          debugPrint('결석 첨부 업로드 실패: $error');
        }
      }
      AttendanceSync.notifyChanged(); // → 홈 다시 불러오기
      if (!mounted) return;
      InAppNotificationBanner.showMessage(
        failed == 0
            ? '$label 결석을 신청했어요.'
            : '$label 결석은 신청했지만 첨부 $failed개를 올리지 못했어요. 설정 > 출석·결석 관리에서 다시 첨부해 주세요.',
      );
    } catch (error) {
      if (mounted && !_loggingOut) {
        InAppNotificationBanner.showMessage(_attendanceError(error));
      }
    } finally {
      if (mounted) setState(() => _saving.remove(child.id));
    }
  }

  Future<void> _cancelAbsence(
    ChildStudent child,
    DateTime date,
    String label,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('결석을 취소할까요?'),
        content: Text(
          '${child.name} 학생의 $label 결석 신청을 취소합니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('아니요'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('결석 취소'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || _saving.contains(child.id)) return;
    setState(() => _saving.add(child.id));
    try {
      await _guard(
        ApiRepository.instance.setChildAttendance(
          child,
          isAbsent: false,
          date: date,
        ),
      );
      AttendanceSync.notifyChanged();
      if (!mounted) return;
      InAppNotificationBanner.showMessage('$label 결석 신청을 취소했어요.');
    } catch (error) {
      if (mounted && !_loggingOut) {
        InAppNotificationBanner.showMessage(_attendanceError(error));
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
    final info = [
      if (child.className != null) child.className!,
      child.busName ?? bus?['bus_name']?.toString() ?? '버스 미배정',
      ?departureTime,
    ].join(' · ');
    // 자녀가 많아도 한 화면에 보이도록 작게: 이름·상태 한 줄, 반·버스·시간 한 줄, 버튼 한 줄
    return Card(
      color: context.appColors.surface,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: context.appColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    child.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.appColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  height: 24,
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
            const SizedBox(height: 2),
            Text(
              info,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.appColors.textSecondary,
                fontSize: 12,
              ),
            ),
            if (_mainChildButton(
                  child,
                  bus,
                  running: running,
                  tripId: tripId,
                  busLoading: busLoading,
                  canChangeAttendance: canChangeAttendance,
                )
                case final main?) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: main),
                  if (child.busStatus != 'NOT_ASSIGNED') ...[
                    const SizedBox(width: 8),
                    _absenceDateButton(child),
                  ],
                ],
              ),
            ] else if (child.busStatus != 'NOT_ASSIGNED') ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 44,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.appColors.textPrimary,
                    side: BorderSide(color: context.appColors.border, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () => _pickAbsenceDate(child),
                  icon: const Icon(Icons.edit_calendar_rounded, size: 20),
                  label: const Text('다른 날 결석 미리 신청'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 자녀 카드의 큰 버튼: 운행 중이면 '실시간 위치 보기', 아니면 '오늘 결석 신청/취소'
  Widget? _mainChildButton(
    ChildStudent child,
    Map<String, dynamic>? bus, {
    required bool running,
    required int? tripId,
    required bool busLoading,
    required bool canChangeAttendance,
  }) {
    if (running) {
      if (tripId == null && !busLoading) {
        return SizedBox(
          height: 44,
          child: TextButton(
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
        );
      }
      return SizedBox(
        height: 44,
        child: FilledButton(
          style: _childButtonStyle(AppColors.primary),
          onPressed: tripId == null
              ? null
              : () => _open(BusStatusScreen(tripId: tripId)),
          child: const Text('실시간 위치 보기'),
        ),
      );
    }
    if (!canChangeAttendance) return null;
    return SizedBox(
      height: 44,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: child.isAbsent ? context.appColors.surface : AppColors.primary,
          foregroundColor: child.isAbsent
              ? context.appColors.textPrimary
              : AppColors.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: child.isAbsent
                ? const BorderSide(color: AppColors.primaryDark, width: 1.5)
                : BorderSide.none,
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        onPressed: _saving.contains(child.id) ? null : () => _setAttendance(child),
        child: Text(child.isAbsent ? '결석 취소' : '오늘 결석 신청'),
      ),
    );
  }

  /// 결석 버튼 옆 작은 정사각형 버튼: 날짜를 골라 미리 결석 신청(이미 결석이면 취소)
  Widget _absenceDateButton(ChildStudent child) => Tooltip(
    message: '날짜 골라 결석 신청',
    child: SizedBox(
      width: 44,
      height: 44,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          foregroundColor: AppColors.primaryDark,
          side: BorderSide(color: context.appColors.border, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: _saving.contains(child.id)
            ? null
            : () => _pickAbsenceDate(child),
        child: const Icon(Icons.edit_calendar_rounded, size: 20),
      ),
    ),
  );

  Future<void> _pickAbsenceDate(ChildStudent child) async {
    final today = DateUtils.dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: today.add(const Duration(days: 1)),
      firstDate: today,
      lastDate: today.add(const Duration(days: 90)),
      helpText: '결석할 날짜 선택',
      cancelText: '취소',
      confirmText: '선택',
    );
    if (picked == null || !mounted) return;
    final date = DateUtils.dateOnly(picked);
    final label = date == today ? '오늘' : _dateLabel(date);

    setState(() => _saving.add(child.id));
    bool alreadyAbsent;
    try {
      alreadyAbsent = await _guard(
        ApiRepository.instance.getChildAttendance(child, date: date),
      );
    } catch (error) {
      if (mounted) setState(() => _saving.remove(child.id));
      if (mounted && !_loggingOut) {
        InAppNotificationBanner.showMessage(
          AppErrorMessage.from(error, fallback: '결석 정보를 불러오지 못했습니다.'),
        );
      }
      return;
    }
    if (!mounted) return;
    setState(() => _saving.remove(child.id));
    if (alreadyAbsent) {
      await _cancelAbsence(child, date, label);
    } else {
      await _requestAbsence(child, date, label);
    }
  }

  ButtonStyle _childButtonStyle(Color background) => FilledButton.styleFrom(
    backgroundColor: background,
    foregroundColor: AppColors.onPrimary,
    minimumSize: const Size(0, 44),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    textStyle: const TextStyle(fontWeight: FontWeight.bold),
  );

  Widget _loadingCard() => Card(
    color: context.appColors.surface,
    elevation: 0,
    margin: const EdgeInsets.only(bottom: 12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: BorderSide(color: context.appColors.border),
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
      color: context.appColors.border,
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
    color: context.appColors.surface,
    elevation: 0,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: BorderSide(color: context.appColors.border),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '자녀를 연결해 주세요',
            style: TextStyle(
              color: context.appColors.textPrimary,
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
                    Text(
                      '정보를 불러오지 못했어요',
                      style: TextStyle(color: context.appColors.textPrimary),
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

  Widget _sectionTitle(String text, {Widget? trailing}) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: context.appColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ?trailing,
      ],
    ),
  );

  // ---------- 버스 실시간 위치 (가로로 긴 띠) ----------
  // 서버에 버스 GPS 가 없어서 BusStatusScreen 과 같은 테스트 운행(BusTripSimulation) 값을 보여 준다.
  static const _stops = ['출발', '정류장 1', '정류장 2', '유치원'];

  Widget _busStrip() => FutureBuilder<List<Map<String, dynamic>>>(
    future: _buses,
    builder: (context, snapshot) {
      int? tripId;
      for (final bus in snapshot.data ?? const <Map<String, dynamic>>[]) {
        if (bus['status'] == 'IN_PROGRESS' && bus['trip_id'] is int) {
          tripId = bus['trip_id'] as int;
          break;
        }
      }
      return AnimatedBuilder(
        animation: Listenable.merge([
          BusTripSimulation.status,
          BusTripSimulation.progress,
        ]),
        builder: (context, _) {
          final status = BusTripSimulation.status.value;
          final progress = BusTripSimulation.progress.value.clamp(0.0, 1.0);
          final running = status == BusTripStatus.running;
          return Material(
            color: context.appColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: context.appColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _open(BusStatusScreen(tripId: tripId)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: running
                                ? AppColors.success.withValues(alpha: 0.12)
                                : context.appColors.border,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            BusTripSimulation.statusText(status),
                            style: TextStyle(
                              color: running
                                  ? AppColors.success
                                  : context.appColors.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            running
                                ? '유치원까지 ${BusTripSimulation.etaText(status)}'
                                : BusTripSimulation.etaText(status),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: context.appColors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          '지도 보기',
                          style: TextStyle(
                            color: context.appColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: context.appColors.textSecondary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 26,
                      child: LayoutBuilder(
                        builder: (context, box) {
                          const inset = 8.0;
                          final width = box.maxWidth - inset * 2;
                          final busX = inset + width * progress;
                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Positioned(
                                left: inset,
                                right: inset,
                                top: 12,
                                child: Container(
                                  height: 3,
                                  color: context.appColors.border,
                                ),
                              ),
                              Positioned(
                                left: inset,
                                top: 12,
                                child: Container(
                                  width: width * progress,
                                  height: 3,
                                  color: AppColors.primary,
                                ),
                              ),
                              for (var i = 0; i < _stops.length; i++)
                                Positioned(
                                  left: inset +
                                      width * i / (_stops.length - 1) -
                                      5,
                                  top: 8.5,
                                  child: Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: progress >=
                                              i / (_stops.length - 1)
                                          ? AppColors.primaryDark
                                          : context.appColors.surface,
                                      border: Border.all(
                                        color: AppColors.primaryDark,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                ),
                              Positioned(
                                left: busX - 13,
                                top: 0,
                                child: Container(
                                  width: 26,
                                  height: 26,
                                  decoration: const BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.directions_bus_rounded,
                                    size: 16,
                                    color: AppColors.onPrimary,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (final stop in _stops)
                          Text(
                            stop,
                            style: TextStyle(
                              color: context.appColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );

  // ---------- AI 채팅 입력칸 (누르면 채팅 화면으로 펼쳐짐) ----------
  Widget _chatBar() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Material(
        key: _chatBarKey,
        color: context.appColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppColors.primaryDark, width: 1.2),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _openChat,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
            child: Row(
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  size: 18,
                  color: AppColors.primaryDark,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _chatMounted
                        ? '이어서 물어보기'
                        : 'AI에게 물어보기 · 예) 우리 아이 오늘 내렸어요?',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.appColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ),
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_upward_rounded,
                    size: 20,
                    color: AppColors.onPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      if (_chatMounted)
        Padding(
          padding: EdgeInsets.only(top: 6, left: 6),
          child: Text(
            '대화 내용이 남아 있어요 · 홈을 새로고침하면 초기화돼요',
            style: TextStyle(color: context.appColors.textSecondary, fontSize: 11),
          ),
        ),
    ],
  );

  void _openChat() {
    final stackBox = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    final barBox = _chatBarKey.currentContext?.findRenderObject() as RenderBox?;
    if (stackBox != null && barBox != null && stackBox.size.height > 0) {
      final center = barBox.localToGlobal(
        barBox.size.center(Offset.zero),
        ancestor: stackBox,
      );
      _chatOrigin = Alignment(
        0,
        (center.dy / stackBox.size.height * 2 - 1).clamp(-1.0, 1.0),
      );
    }
    setState(() {
      _chatMounted = true;
      _chatOpen = true;
    });
    _chatAnim.forward();
    _chatFocus.value++;
  }

  Future<void> _collapseChat() async {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _chatOpen = false);
    await _chatAnim.reverse();
    if (mounted) setState(() {});
  }

  Widget _chatPanel() {
    final curve = _chatCurve;
    final visible = _chatOpen || !_chatAnim.isDismissed;
    return Positioned.fill(
      child: Offstage(
        offstage: !visible,
        child: TickerMode(
          enabled: visible,
          child: FadeTransition(
            opacity: curve,
            child: ScaleTransition(
              alignment: _chatOrigin,
              scale: Tween(begin: 0.6, end: 1.0).animate(curve),
              child: Material(
                color: context.appColors.surface,
                child: AlertChatScreen(
                  key: _chatKey,
                  onCollapse: _collapseChat,
                  focusRequest: _chatFocus,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------- 오늘 승하차 기록 ----------
  String _hm(DateTime? time) {
    if (time == null) return '--:--';
    final t = time.toLocal();
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  Widget _timeChip(String label, DateTime? time, IconData icon) {
    final done = time != null;
    return Expanded(
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: done
              ? AppColors.success.withValues(alpha: 0.10)
              : context.appColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: done
                ? AppColors.success.withValues(alpha: 0.35)
                : context.appColors.border,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 15,
              color: done ? AppColors.success : context.appColors.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: context.appColors.textSecondary,
                fontSize: 11,
              ),
            ),
            const Spacer(),
            Text(
              _hm(time),
              style: TextStyle(
                color: done ? context.appColors.textPrimary : context.appColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _recordsSection() => FutureBuilder<List<ChildStudent>>(
    future: _children,
    builder: (context, snapshot) {
      final children = snapshot.data;
      if (children == null || children.isEmpty) {
        return const SizedBox.shrink();
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionTitle(
            '오늘 승하차',
            trailing: TextButton(
              style: TextButton.styleFrom(
                foregroundColor: context.appColors.textSecondary,
                visualDensity: VisualDensity.compact,
              ),
              onPressed: () => _open(const ParentTripAttendanceScreen()),
              child: const Text('기록 전체보기 ›'),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: context.appColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.appColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: context.appColors.border),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 64,
                          child: Text(
                            children[i].name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: context.appColors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (children[i].isAbsent)
                          const Expanded(
                            child: Text(
                              '오늘은 결석이에요',
                              style: TextStyle(
                                color: AppColors.danger,
                                fontSize: 13,
                              ),
                            ),
                          )
                        else ...[
                          _timeChip(
                            '승차',
                            children[i].boardingConfirmedAt,
                            Icons.login_rounded,
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4),
                            child: Icon(
                              Icons.arrow_forward_rounded,
                              size: 14,
                              color: context.appColors.textSecondary,
                            ),
                          ),
                          _timeChip(
                            '하차',
                            children[i].alightingConfirmedAt,
                            Icons.logout_rounded,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      );
    },
  );

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
          Expanded(
            child: Text(
              '통학이',
              style: TextStyle(
                color: context.appColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Text(
        '오늘도 안전하게 다녀와요',
        style: TextStyle(color: context.appColors.textSecondary, fontSize: 14),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_chatOpen,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop && _chatOpen) _collapseChat();
    },
    child: Scaffold(
      backgroundColor: context.appColors.background,
      body: SafeArea(
        child: Stack(
          key: _stackKey,
          children: [
            RefreshIndicator(
              onRefresh: () => _refresh(resetChat: true),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                children: [
                  _header(),
                  const SizedBox(height: 16),
                  _alertSection(),
                  _sectionTitle('내 자녀'),
                  _childrenSection(),
                  const SizedBox(height: 8),
                  _sectionTitle('버스 실시간 위치'),
                  _busStrip(),
                  const SizedBox(height: 16),
                  _recordsSection(),
                  const SizedBox(height: 16),
                  _chatBar(),
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
            if (_chatMounted) _chatPanel(),
          ],
        ),
      ),
    ),
  );
}
