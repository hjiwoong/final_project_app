import 'package:flutter/material.dart';

import '../../data/mock/mock_repository.dart';
import 'alert_detail_screen.dart';

/// 알림 목록: GET /me/notifications · 읽음 처리
class NotificationListScreen extends StatefulWidget {
  const NotificationListScreen({super.key});

  @override
  State<NotificationListScreen> createState() => _NotificationListScreenState();
}

class _NotificationListScreenState extends State<NotificationListScreen> {
  @override
  Widget build(BuildContext context) {
    final items = MockRepository.instance.notifications;
    return Scaffold(
      appBar: AppBar(title: const Text('알림')),
      body: ListView.separated(
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final n = items[i];
          return ListTile(
            title: Text(
              n.title,
              style: TextStyle(fontWeight: n.read ? FontWeight.normal : FontWeight.bold),
            ),
            subtitle: Text('${n.busName} · ${n.time}'),
            onTap: () {
              setState(() => n.read = true);
              if (n.isAlert) {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AlertDetailScreen()),
                );
              }
            },
          );
        },
      ),
    );
  }
}
