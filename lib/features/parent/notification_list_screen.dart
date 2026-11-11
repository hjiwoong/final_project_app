import 'package:flutter/material.dart';

import '../../data/api/api_repository.dart';
import '../../data/models/notification_item.dart';
import 'alert_detail_screen.dart';
import 'notification_mock_store.dart';
import 'alert_mock_store.dart';
import 'parent_event_mock_store.dart';
import 'notification_settings_screen.dart';

import '../../core/notifications/in_app_notification_banner.dart';

enum _NotificationFilter { all, urgent, check }

class NotificationListScreen extends StatefulWidget {
  const NotificationListScreen({super.key});

  @override
  State<NotificationListScreen> createState() => _NotificationListScreenState();
}

class _NotificationListScreenState extends State<NotificationListScreen> {
  bool _loading = true;
  String? _error;
  List<NotificationItem> _items = [];
  _NotificationFilter _selectedFilter = _NotificationFilter.all;
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications({bool showLoading = true}) async {
    setState(() {
      if (showLoading) _loading = true;
      _error = null;
    });
    try {
      final items = await ApiRepository.instance.getNotifications();
      if (!mounted) return;

      NotificationMockStore.updateNotifications(
        items.map((n) => n.id).toList(),
        items.where((n) => n.read).map((n) => n.id).toSet(),
      );
      try {
        final unreadCount = await ApiRepository.instance
            .getNotificationUnreadCount();
        NotificationMockStore.setNotificationUnreadCount(unreadCount);
      } catch (e) {
        debugPrint('읽지 않은 알림 개수 조회 실패: $e');
      }
      for (final n in items) {
        n.read = NotificationMockStore.isRead(n.id, n.read);
      }
      setState(() => _items = items);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '알림을 불러오지 못했습니다. 다시 시도해 주세요.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // 모든 알림 읽음 처리
  Future<void> _markAllAsRead() async {
    if (_loading) return;

    // 아직 읽지 않은 일반 알림 ID
    final unreadItems = _items.where((n) => !n.read).toList();

    // 기존 일반 알림과 미하차 테스트 경고 읽음 처리
    NotificationMockStore.markAllAsRead(_items.map((n) => n.id).toList());

    // 승하차 및 이상 상황 Mock 이벤트 읽음 처리
    final events = ParentEventMockStore.events.value;

    for (final event in events) {
      ParentEventMockStore.markEventAsRead(event.id);
    }

    // 화면에 표시된 일반 알림 상태 갱신
    setState(() {
      for (final n in _items) {
        n.read = true;
      }
    });

    // 기존 일반 알림의 읽음 API 호출 유지
    // 실패해도 Mock 화면의 읽음 상태는 유지
    for (final item in unreadItems) {
      try {
        await ApiRepository.instance.readNotification(item);
      } catch (e) {
        debugPrint('알림 읽음 처리 실패: $e');
      }
    }

    if (!mounted) return;

    InAppNotificationBanner.showMessage('모든 알림을 확인했습니다.');
  }

  IconData _getNotificationIcon(NotificationItem n) {
    if (n.isAlert) {
      return switch (n.alertLevel) {
        'URGENT' => Icons.error_rounded,
        'CHECK' => Icons.warning_amber_rounded,
        _ => Icons.warning_amber_rounded,
      };
    }

    if (n.title.contains('하차')) {
      return Icons.check_circle_outline;
    }

    if (n.title.contains('승차') || n.title.contains('탑승')) {
      return Icons.directions_bus;
    }

    return Icons.notifications_none;
  }

  Color _getNotificationColor(NotificationItem n) {
    final colorScheme = Theme.of(context).colorScheme;
    if (n.isAlert) {
      return switch (n.alertLevel) {
        'URGENT' => colorScheme.error,
        'CHECK' => Colors.orange,
        _ => colorScheme.error,
      };
    }

    if (n.title.contains('하차')) {
      return colorScheme.tertiary;
    }

    if (n.title.contains('승차') || n.title.contains('탑승')) {
      return colorScheme.primary;
    }

    return colorScheme.onSurfaceVariant;
  }

  void _showEventDetail(ParentMockEvent event) {
    ParentEventMockStore.markEventAsRead(event.id);

    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(event.title),
          content: Text(event.message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }

  List<NotificationItem> _itemsForFilter(_NotificationFilter filter) {
    return switch (filter) {
      _NotificationFilter.all => _items,
      _NotificationFilter.urgent =>
        _items.where((n) => n.alertLevel == 'URGENT').toList(),
      _NotificationFilter.check =>
        _items.where((n) => n.alertLevel == 'CHECK').toList(),
    };
  }

  Widget _buildNotificationPage(_NotificationFilter filter) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final filteredItems = _itemsForFilter(filter);
    final emptyMessage = filter == _NotificationFilter.all
        ? '새 알림이 없습니다.'
        : '해당 종류의 알림이 없습니다.';

    return RefreshIndicator(
      onRefresh: () => _fetchNotifications(showLoading: false),
      child: _error != null
          ? CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: _fetchNotifications,
                          child: const Text('다시 시도'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            )
          : filteredItems.isEmpty
          ? CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: Text(emptyMessage)),
                ),
              ],
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: filteredItems.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final n = filteredItems[i];
                return ListTile(
                  leading: Icon(
                    _getNotificationIcon(n),
                    color: _getNotificationColor(n),
                  ),
                  title: Text(
                    n.title,
                    style: TextStyle(
                      fontWeight: n.read ? FontWeight.normal : FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    [
                      if (n.body.isNotEmpty) n.body else n.busName,
                      if (n.time.isNotEmpty) n.time,
                    ].join('\n'),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: n.read
                      ? null
                      : Icon(
                          Icons.circle,
                          color: Theme.of(context).colorScheme.primary,
                          size: 10,
                        ),
                  onTap: () async {
                    setState(() => n.read = true);
                    NotificationMockStore.markAsRead(n.id);

                    try {
                      await ApiRepository.instance.readNotification(n);
                    } catch (e) {
                      debugPrint('알림 읽음 처리 실패: $e');
                    }

                    if (!context.mounted) return;

                    if (n.isAlert) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AlertDetailScreen(alertId: n.alertId),
                        ),
                      );
                    }
                  },
                );
              },
            ),
    );
  }

  Widget _buildFilterChip(_NotificationFilter filter, String label) {
    final colorScheme = Theme.of(context).colorScheme;
    final selected = _selectedFilter == filter;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      backgroundColor: colorScheme.surface,
      selectedColor: colorScheme.surfaceContainerHighest,
      side: BorderSide(color: colorScheme.outlineVariant),
      shape: const StadiumBorder(),
      labelStyle: TextStyle(
        color: colorScheme.onSurface,
        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
      ),
      onSelected: (_) {
        setState(() => _selectedFilter = filter);
        _pageController.animateToPage(
          filter.index,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('알림'),

        // 모두 읽음 버튼
        actions: [
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
            onPressed: _loading ? null : _markAllAsRead,
            icon: const Icon(Icons.done_all),
          ),
          const SizedBox(width: 8),
        ],
      ),

      body: ValueListenableBuilder<bool>(
        valueListenable: AlertMockStore.hasAlert,
        builder: (context, hasAlert, child) {
          return Column(
            children: [
              SizedBox(
                height: 58,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  children: [
                    _buildFilterChip(_NotificationFilter.all, '전체'),
                    const SizedBox(width: 8),
                    _buildFilterChip(_NotificationFilter.urgent, '긴급'),
                    const SizedBox(width: 8),
                    _buildFilterChip(_NotificationFilter.check, '확인 필요'),
                  ],
                ),
              ),
              // 미하차 의심 경고 (Mock)
              if (hasAlert && _selectedFilter != _NotificationFilter.check)
                ValueListenableBuilder<int>(
                  valueListenable: NotificationMockStore.unreadCount,
                  builder: (context, count, child) {
                    final isRead = NotificationMockStore.isTestAlertRead;

                    return Card(
                      color: Theme.of(context).colorScheme.errorContainer,
                      margin: const EdgeInsets.all(12),
                      child: ListTile(
                        leading: Icon(
                          Icons.warning_amber_rounded,
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                        title: Text(
                          '미하차 의심 경고 (테스트)',
                          style: TextStyle(
                            fontWeight: isRead
                                ? FontWeight.normal
                                : FontWeight.bold,
                          ),
                        ),
                        subtitle: const Text('1호차 · 차량 내 잔류 인원 1명 가정'),
                        trailing: isRead
                            ? null
                            : Icon(
                                Icons.circle,
                                color: Theme.of(context).colorScheme.error,
                                size: 10,
                              ),
                        onTap: () {
                          NotificationMockStore.readTestAlert();

                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const AlertDetailScreen(),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),

              // 승하차 및 이상 상황 이벤트 알림 (Mock)
              ValueListenableBuilder<List<ParentMockEvent>>(
                valueListenable: ParentEventMockStore.events,
                builder: (context, events, child) {
                  return ValueListenableBuilder<Set<int>>(
                    valueListenable: ParentEventMockStore.readEventIds,
                    builder: (context, readIds, child) {
                      final visibleEvents = switch (_selectedFilter) {
                        _NotificationFilter.all => events,
                        _NotificationFilter.urgent =>
                          events.where((event) => event.isAlert).toList(),
                        _NotificationFilter.check => <ParentMockEvent>[],
                      };
                      if (visibleEvents.isEmpty) {
                        return const SizedBox.shrink();
                      }

                      return ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 280),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: visibleEvents.length,
                          itemBuilder: (context, index) {
                            final event = visibleEvents[index];
                            final isRead = readIds.contains(event.id);

                            return ListTile(
                              leading: Icon(
                                event.isAlert
                                    ? Icons.warning_amber_rounded
                                    : Icons.directions_bus,
                                color: event.isAlert
                                    ? Theme.of(context).colorScheme.error
                                    : Theme.of(context).colorScheme.primary,
                              ),
                              title: Text(
                                event.title,
                                style: TextStyle(
                                  fontWeight: isRead
                                      ? FontWeight.normal
                                      : FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                '${event.message} · ${event.time}',
                              ),
                              trailing: isRead
                                  ? null
                                  : Icon(
                                      Icons.circle,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      size: 10,
                                    ),
                              onTap: () {
                                _showEventDetail(event);
                              },
                            );
                          },
                        ),
                      );
                    },
                  );
                },
              ),

              // 기존 알림 목록
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(
                      () => _selectedFilter = _NotificationFilter.values[index],
                    );
                  },
                  children: _NotificationFilter.values
                      .map(_buildNotificationPage)
                      .toList(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
