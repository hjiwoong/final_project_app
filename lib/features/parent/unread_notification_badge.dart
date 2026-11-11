import 'package:flutter/material.dart';

import 'notification_mock_store.dart';
import 'parent_event_mock_store.dart';

class UnreadNotificationBadge extends StatelessWidget {
  const UnreadNotificationBadge({required this.icon, super.key});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: NotificationMockStore.unreadCount,
      builder: (context, notificationCount, child) {
        return ValueListenableBuilder<List<ParentMockEvent>>(
          valueListenable: ParentEventMockStore.events,
          builder: (context, events, child) {
            return ValueListenableBuilder<Set<int>>(
              valueListenable: ParentEventMockStore.readEventIds,
              builder: (context, readIds, child) {
                final eventCount = events
                    .where((event) => !readIds.contains(event.id))
                    .length;
                final count = notificationCount + eventCount;
                return Badge(
                  isLabelVisible: count > 0,
                  label: Text(count > 99 ? '99+' : '$count'),
                  child: Icon(icon),
                );
              },
            );
          },
        );
      },
    );
  }
}
