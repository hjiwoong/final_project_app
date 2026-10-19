import 'package:flutter/material.dart';

import '../../data/api/api_repository.dart';
import '../../data/models/notification_item.dart';
import 'alert_detail_screen.dart';

/// 알림 목록: GET /me/notifications · 읽음 처리
class NotificationListScreen extends StatefulWidget {
  const NotificationListScreen({super.key});

  @override
  State<NotificationListScreen> createState() => _NotificationListScreenState();
}

class _NotificationListScreenState extends State<NotificationListScreen> {
  bool _loading = true;
  List<NotificationItem> _items = [];

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() => _loading = true);
    final items = await ApiRepository.instance.getNotifications();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('알림')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(child: Text('알림이 없습니다.'))
              : ListView.separated(
                  itemCount: _items.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final n = _items[i];
                    return ListTile(
                      title: Text(
                        n.title,
                        style: TextStyle(fontWeight: n.read ? FontWeight.normal : FontWeight.bold),
                      ),
                      subtitle: Text('${n.busName} · ${n.time}'),
                      onTap: () async {
                        setState(() => n.read = true);
                        await ApiRepository.instance.readNotification(n.id);
                        if (!mounted) return;
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
