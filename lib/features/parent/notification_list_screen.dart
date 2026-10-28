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
      setState(() => _items = items);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '알림을 불러오지 못했습니다. 다시 시도해 주세요.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('알림')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? RefreshIndicator(
              onRefresh: () => _fetchNotifications(showLoading: false),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: 260,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
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
                ],
              ),
            )
          : _items.isEmpty
          ? RefreshIndicator(
              onRefresh: () => _fetchNotifications(showLoading: false),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '알림이 없습니다.',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontSize: 26,
                                color: const Color(0xFF202329),
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '새로운 알림이 도착하면 여기서 확인하실 수 있습니다.',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: () => _fetchNotifications(showLoading: false),
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: _items.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final n = _items[i];
                  return ListTile(
                    title: Text(
                      n.title,
                      style: TextStyle(
                        fontWeight: n.read
                            ? FontWeight.normal
                            : FontWeight.bold,
                      ),
                    ),
                    subtitle: Text('${n.busName} · ${n.time}'),
                    onTap: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final navigator = Navigator.of(context);
                      try {
                        await ApiRepository.instance.readNotification(n);
                        if (!mounted) return;
                        setState(() => n.read = true);
                      } catch (e) {
                        if (!mounted) return;
                        messenger.showSnackBar(
                          SnackBar(content: Text('알림을 읽음 처리하지 못했습니다. ($e)')),
                        );
                      }
                      if (!mounted) return;
                      if (n.isAlert) {
                        navigator.push(
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
    );
  }
}
