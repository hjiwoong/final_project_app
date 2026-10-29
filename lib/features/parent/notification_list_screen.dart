
import 'package:flutter/material.dart';

import '../../data/api/api_repository.dart';
import '../../data/models/notification_item.dart';
import 'alert_detail_screen.dart';
import 'notification_mock_store.dart';
import 'alert_mock_store.dart';
import 'parent_event_mock_store.dart';

class NotificationListScreen extends StatefulWidget {
  const NotificationListScreen({super.key});

  @override
  State<NotificationListScreen> createState() =>
      _NotificationListScreenState();
}

class _NotificationListScreenState
    extends State<NotificationListScreen> {
  bool _loading = true;
  String? _error;
  List<NotificationItem> _items = [];

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
    NotificationMockStore.markAllAsRead(
      _items.map((n) => n.id).toList(),
    );

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

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('모든 알림을 확인했습니다.'),
      ),
    );
  }

  IconData _getNotificationIcon(NotificationItem n) {
    if (n.isAlert) {
      return Icons.warning_amber_rounded;
    }

    if (n.title.contains('하차')) {
      return Icons.check_circle_outline;
    }

    if (n.title.contains('승차') ||
        n.title.contains('탑승')) {
      return Icons.directions_bus;
    }

    return Icons.notifications_none;
  }

  Color _getNotificationColor(NotificationItem n) {
    if (n.isAlert) {
      return Colors.red;
    }

    if (n.title.contains('하차')) {
      return Colors.green;
    }

    if (n.title.contains('승차') ||
        n.title.contains('탑승')) {
      return Colors.blue;
    }

    return Colors.grey;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('알림'),

        // 모두 읽음 버튼
        actions: [
          TextButton.icon(
            onPressed: _loading ? null : _markAllAsRead,
            icon: const Icon(
              Icons.done_all,
              size: 20,
            ),
            label: const Text('모두 읽음'),
          ),
          const SizedBox(width: 8),
        ],
      ),

      body: ValueListenableBuilder<bool>(
        valueListenable: AlertMockStore.hasAlert,
        builder: (context, hasAlert, child) {
          return Column(
            children: [
              // 미하차 의심 경고 (Mock)
              if (hasAlert)
                ValueListenableBuilder<int>(
                  valueListenable:
                  NotificationMockStore.unreadCount,
                  builder: (context, count, child) {
                    final isRead =
                        NotificationMockStore.isTestAlertRead;

                    return Card(
                      color: Colors.red.shade50,
                      margin: const EdgeInsets.all(12),
                      child: ListTile(
                        leading: const Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.red,
                        ),
                        title: Text(
                          '미하차 의심 경고 (테스트)',
                          style: TextStyle(
                            fontWeight: isRead
                                ? FontWeight.normal
                                : FontWeight.bold,
                          ),
                        ),
                        subtitle: const Text(
                          '1호차 · 차량 내 잔류 인원 1명 가정',
                        ),
                        trailing: isRead
                            ? null
                            : const Icon(
                          Icons.circle,
                          color: Colors.red,
                          size: 10,
                        ),
                        onTap: () {
                          NotificationMockStore.readTestAlert();

                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                              const AlertDetailScreen(),
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
                    valueListenable:
                    ParentEventMockStore.readEventIds,
                    builder: (context, readIds, child) {
                      if (events.isEmpty) {
                        return const SizedBox.shrink();
                      }

                      return ConstrainedBox(
                        constraints:
                        const BoxConstraints(maxHeight: 280),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: events.length,
                          itemBuilder: (context, index) {
                            final event = events[index];
                            final isRead =
                            readIds.contains(event.id);

                            return ListTile(
                              leading: Icon(
                                event.isAlert
                                    ? Icons.warning_amber_rounded
                                    : Icons.directions_bus,
                                color: event.isAlert
                                    ? Colors.red
                                    : Colors.blue,
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
                                  : const Icon(
                                Icons.circle,
                                color: Colors.blue,
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
                child: _loading
                    ? const Center(
                  child: CircularProgressIndicator(),
                )
                    : _error != null
                    ? Center(
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
                )
                    : _items.isEmpty
                    ? const Center(
                  child: Text('기존 알림이 없습니다.'),
                )
                    : ListView.separated(
                  itemCount: _items.length,
                  separatorBuilder: (context, index) =>
                  const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final n = _items[i];

                    return ListTile(
                      leading: Icon(
                        _getNotificationIcon(n),
                        color: _getNotificationColor(n),
                      ),
                      title: Text(
                        n.title,
                        style: TextStyle(
                          fontWeight: n.read
                              ? FontWeight.normal
                              : FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        '${n.busName} · ${n.time}',
                      ),
                      trailing: n.read
                          ? null
                          : const Icon(
                        Icons.circle,
                        color: Colors.blue,
                        size: 10,
                      ),
                      onTap: () async {
                        setState(() {
                          n.read = true;
                        });

                        NotificationMockStore.markAsRead(
                          n.id,
                        );

                        try {
                          await ApiRepository.instance.readNotification(n);
                        } catch (e) {
                          debugPrint('알림 읽음 처리 실패: $e');
                        }

                        if (!mounted) return;

                        if (n.isAlert) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  AlertDetailScreen(alertId: n.alertId),
                            ),
                          );
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

