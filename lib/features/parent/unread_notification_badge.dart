import 'package:flutter/material.dart';

import 'unread_notification_store.dart';

class UnreadNotificationBadge extends StatelessWidget {
  const UnreadNotificationBadge({required this.icon, super.key});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: UnreadNotificationStore.unreadCount,
      builder: (context, count, child) {
        return Badge(
          isLabelVisible: count > 0,
          label: Text(count > 99 ? '99+' : '$count'),
          child: Icon(icon),
        );
      },
    );
  }
}
