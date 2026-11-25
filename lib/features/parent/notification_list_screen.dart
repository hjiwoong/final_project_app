import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/auth/session.dart';
import '../../core/notifications/in_app_notification_banner.dart';
import '../../data/models/user_role.dart';
import '../driver/widgets/absence_detail.dart';
import '../../data/api/api_repository.dart';
import '../../data/models/notification_item.dart';
import '../../theme/app_colors.dart';
import 'alert_detail_screen.dart';
import 'notification_settings_screen.dart';
import 'unread_notification_store.dart';

enum _NotificationFilter { all, urgent, check, attendance, trip }

class NotificationListScreen extends StatefulWidget {
  const NotificationListScreen({
    super.key,
    this.showSettingsButton = true,
    this.urgentSelectionRequest = 0,
  });

  final bool showSettingsButton;
  final int urgentSelectionRequest;

  @override
  State<NotificationListScreen> createState() => _NotificationListScreenState();
}

class _NotificationListScreenState extends State<NotificationListScreen> {
  bool _loading = true;
  bool _markingAll = false;
  String? _error;
  List<NotificationItem> _items = [];
  _NotificationFilter _selectedFilter = _NotificationFilter.all;
  late final PageController _pageController;
  int _requestId = 0;

  // 학부모는 '확인 필요' 경고를 받지 않으므로(관리자 전용) 대신 '운행' 알림 탭, 관리자는 '결석' 탭
  late final List<_NotificationFilter> _filters = Session.role == UserRole.parent
      ? const [
          _NotificationFilter.all,
          _NotificationFilter.urgent,
          _NotificationFilter.trip,
          _NotificationFilter.attendance,
        ]
      : const [
          _NotificationFilter.all,
          _NotificationFilter.urgent,
          _NotificationFilter.check,
          _NotificationFilter.attendance,
        ];

  static const _filterLabels = {
    _NotificationFilter.all: '전체',
    _NotificationFilter.urgent: '긴급',
    _NotificationFilter.check: '확인 필요',
    _NotificationFilter.attendance: '결석',
    _NotificationFilter.trip: '운행',
  };

  @override
  void initState() {
    super.initState();
    if (widget.urgentSelectionRequest > 0) {
      _selectedFilter = _NotificationFilter.urgent;
    }
    _pageController = PageController(
      initialPage: _filters.indexOf(_selectedFilter),
    );
    _fetchNotifications();
  }

  @override
  void didUpdateWidget(NotificationListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.urgentSelectionRequest != oldWidget.urgentSelectionRequest) {
      _selectFilter(_NotificationFilter.urgent);
      if (_pageController.hasClients) {
        _pageController.jumpToPage(_filters.indexOf(_NotificationFilter.urgent));
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _fetchNotifications({bool showLoading = true}) async {
    final requestId = ++_requestId;
    final category = switch (_selectedFilter) {
      _NotificationFilter.all => null,
      _NotificationFilter.urgent => 'URGENT',
      _NotificationFilter.check => 'CHECK',
      _NotificationFilter.attendance => 'ATTENDANCE',
      _NotificationFilter.trip => 'TRIP',
    };
    setState(() {
      _loading = showLoading;
      _error = null;
    });
    try {
      final page = await ApiRepository.instance.getNotifications(
        category: category,
      );
      if (!mounted || requestId != _requestId) return;
      UnreadNotificationStore.setCount(page.unreadCount);
      setState(() => _items = page.items);
    } catch (e) {
      if (!mounted || requestId != _requestId) return;
      debugPrint('알림 조회 실패: $e');
      setState(() => _error = '알림을 불러오지 못했어요');
    } finally {
      if (mounted && requestId == _requestId) {
        setState(() => _loading = false);
      }
    }
  }

  void _selectFilter(_NotificationFilter filter) {
    if (_selectedFilter == filter) return;
    setState(() => _selectedFilter = filter);
    _fetchNotifications();
  }

  Future<void> _markAllAsRead() async {
    if (_loading || _markingAll) return;
    setState(() => _markingAll = true);
    try {
      await ApiRepository.instance.readAllNotifications();
      if (!mounted) return;
      await _fetchNotifications();
      if (mounted) {
        InAppNotificationBanner.showMessage('모든 알림을 확인했습니다.');
      }
    } catch (e) {
      debugPrint('모든 알림 읽음 처리 실패: $e');
      if (mounted) {
        InAppNotificationBanner.showMessage('알림 읽음 처리에 실패했어요.');
      }
    } finally {
      if (mounted) setState(() => _markingAll = false);
    }
  }

  Future<void> _openNotification(NotificationItem notification) async {
    if (!notification.isRead) {
      setState(() => notification.isRead = true);
      UnreadNotificationStore.decrement();
    }
    try {
      await ApiRepository.instance.readNotification(notification);
    } catch (e) {
      debugPrint('알림 읽음 처리 실패: $e');
    }
    if (!mounted) return;
    if (notification.alertId != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AlertDetailScreen(alertId: notification.alertId),
        ),
      );
    } else if (notification.category == 'ATTENDANCE' &&
        Session.role != UserRole.parent) {
      if (notification.attendanceId != null) {
        // 학부모가 적은 사유·첨부 파일 확인
        await showAbsenceDetailSheet(
          context,
          attendanceId: notification.attendanceId!,
        );
      } else {
        // 이 기능 전에 온 알림은 결석 기록과 연결돼 있지 않다
        InAppNotificationBanner.showMessage(
          '이전에 온 알림이라 사유를 바로 열 수 없어요. 출결 확인 탭에서 날짜를 눌러 확인해 주세요.',
        );
      }
    }
  }

  String _dateLabel(DateTime date, DateTime now) {
    if (DateUtils.isSameDay(date, now)) return '오늘';
    if (DateUtils.isSameDay(date, DateTime(now.year, now.month, now.day - 1))) {
      return '어제';
    }
    return DateFormat('M월 d일').format(date);
  }

  String _timeLabel(DateTime date, DateTime now) {
    final time = DateFormat('HH:mm').format(date);
    if (DateUtils.isSameDay(date, now)) return time;
    if (DateUtils.isSameDay(date, DateTime(now.year, now.month, now.day - 1))) {
      return '어제 $time';
    }
    return '${DateFormat('M월 d일').format(date)} $time';
  }

  bool _isPinned(NotificationItem item, DateTime now) {
    final age = now.difference(item.sentAt);
    return _selectedFilter == _NotificationFilter.all &&
        item.category == 'URGENT' &&
        !item.isRead &&
        !age.isNegative &&
        age <= const Duration(hours: 24);
  }

  Widget _buildNotificationCard(NotificationItem item, DateTime now) {
    final urgent = item.category == 'URGENT';
    final icon = switch (item.category) {
      'URGENT' => Icons.error_rounded,
      'CHECK' => Icons.warning_amber_rounded,
      'ATTENDANCE' => Icons.event_busy_rounded,
      _ => Icons.notifications_none,
    };
    final color = switch (item.category) {
      'URGENT' => AppColors.danger,
      'CHECK' => AppColors.accent,
      'ATTENDANCE' => AppColors.primaryDark,
      _ => context.appColors.textSecondary,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: urgent
            ? AppColors.danger.withValues(alpha: 0.08)
            : context.appColors.surface,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _openNotification(item),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(icon, color: color),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: context.appColors.textPrimary,
                                  fontWeight: item.isRead
                                      ? FontWeight.normal
                                      : FontWeight.bold,
                                ),
                              ),
                              if (item.body.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  item.body,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: context.appColors.textSecondary,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 6),
                              Text(
                                _timeLabel(item.sentAt, now),
                                style: TextStyle(
                                  color: context.appColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (!item.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSkeleton() {
    return ListView.builder(
      itemCount: 3,
      itemBuilder: (context, index) => Container(
        height: 96,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.appColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(radius: 12, backgroundColor: context.appColors.border),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(width: 140, height: 12, color: context.appColors.border),
                  const SizedBox(height: 12),
                  Container(height: 10, color: context.appColors.border),
                  const SizedBox(height: 8),
                  Container(width: 100, height: 10, color: context.appColors.border),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationPage() {
    if (_loading) return _buildSkeleton();
    final now = DateTime.now();
    final items = List<NotificationItem>.of(_items)
      ..sort((a, b) {
        final pinnedOrder =
            (_isPinned(b, now) ? 1 : 0) - (_isPinned(a, now) ? 1 : 0);
        return pinnedOrder != 0 ? pinnedOrder : b.sentAt.compareTo(a.sentAt);
      });
    final children = <Widget>[];
    DateTime? previousDate;
    for (final item in items) {
      if (previousDate == null ||
          !DateUtils.isSameDay(previousDate, item.sentAt)) {
        children.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
            child: Text(
              _dateLabel(item.sentAt, now),
              style: TextStyle(
                color: context.appColors.textSecondary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
        previousDate = item.sentAt;
      }
      children.add(_buildNotificationCard(item, now));
    }
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => _fetchNotifications(showLoading: false),
      child: _error != null || items.isEmpty
          ? CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _error ?? '새 알림이 없어요',
                          style: TextStyle(
                            color: context.appColors.textSecondary,
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: _fetchNotifications,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: context.appColors.textPrimary,
                              side: BorderSide(color: context.appColors.border),
                            ),
                            child: const Text('다시 시도'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            )
          : ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: children,
            ),
    );
  }

  Widget _buildFilterChip(_NotificationFilter filter, String label) {
    final selected = _selectedFilter == filter;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      backgroundColor: context.appColors.surface,
      selectedColor: AppColors.primary,
      side: BorderSide(color: context.appColors.border),
      shape: const StadiumBorder(),
      labelStyle: TextStyle(
        color: selected ? AppColors.onPrimary : context.appColors.textSecondary,
        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
      ),
      onSelected: (_) {
        _selectFilter(filter);
        _pageController.jumpToPage(_filters.indexOf(filter));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appColors.background,
      appBar: AppBar(
        backgroundColor: context.appColors.background,
        foregroundColor: context.appColors.textPrimary,
        title: const Text('알림'),
        actions: [
          if (widget.showSettingsButton)
            IconButton(
              tooltip: '알림 설정',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const NotificationSettingsScreen(),
                ),
              ),
              icon: const Icon(Icons.settings_outlined),
            ),
          IconButton(
            tooltip: '모두 읽음 처리',
            onPressed: _loading || _markingAll ? null : _markAllAsRead,
            icon: const Icon(Icons.done_all),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 58,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                for (final (i, filter) in _filters.indexed) ...[
                  if (i > 0) const SizedBox(width: 8),
                  _buildFilterChip(filter, _filterLabels[filter]!),
                ],
              ],
            ),
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) =>
                  _selectFilter(_filters[index]),
              children: _filters
                  .map(
                    (filter) => filter == _selectedFilter
                        ? _buildNotificationPage()
                        : const SizedBox.shrink(),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}
