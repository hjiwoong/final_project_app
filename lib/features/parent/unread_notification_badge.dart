import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'unread_notification_store.dart';

class UnreadNotificationBadge extends StatelessWidget {
  const UnreadNotificationBadge({
    required this.icon,
    this.dot = false,
    super.key,
  });

  final IconData icon;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: UnreadNotificationStore.unreadCount,
      builder: (context, count, child) {
        return Badge(
          backgroundColor: AppColors.danger,
          isLabelVisible: count > 0,
          label: dot ? null : Text(count > 99 ? '99+' : '$count'),
          child: Icon(icon),
        );
      },
    );
  }
}
