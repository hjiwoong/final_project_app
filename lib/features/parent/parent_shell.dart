import 'package:flutter/material.dart';

import '../../data/api/api_repository.dart';
import 'notification_mock_store.dart';
import 'notification_list_screen.dart';
import 'parent_home_screen.dart';
import 'parent_settings_screen.dart';
import 'alert_chat_screen.dart';
import 'unread_notification_badge.dart';

// 학부모 하단 탭: 홈 · 알림 · AI 상담 · 설정
class ParentShell extends StatefulWidget {
  const ParentShell({super.key});

  @override
  State<ParentShell> createState() => _ParentShellState();
}

class _ParentShellState extends State<ParentShell> {
  int _index = 0;
  final Set<int> _visitedTabs = {0};

  @override
  void initState() {
    super.initState();
    _refreshUnreadCount();
  }

  Future<void> _refreshUnreadCount() async {
    try {
      final count = await ApiRepository.instance.getNotificationUnreadCount();
      NotificationMockStore.setNotificationUnreadCount(count);
    } catch (e) {
      debugPrint('읽지 않은 알림 개수 조회 실패: $e');
    }
  }

  static const _pages = [
    ParentHomeScreen(),
    NotificationListScreen(),
    AlertChatScreen(),
    ParentSettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          for (var index = 0; index < _pages.length; index++)
            _visitedTabs.contains(index)
                ? _pages[index]
                : const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() {
            _visitedTabs.add(i);
            _index = i;
          }),
          elevation: 0,
          height: 60,
          destinations: [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: '홈',
            ),
            NavigationDestination(
              icon: const UnreadNotificationBadge(
                icon: Icons.notifications_outlined,
              ),
              selectedIcon: const UnreadNotificationBadge(
                icon: Icons.notifications,
              ),
              label: '알림',
            ),
            NavigationDestination(
              icon: Icon(Icons.auto_awesome_outlined),
              selectedIcon: Icon(Icons.auto_awesome),
              label: 'AI 채팅',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: '설정',
            ),
          ],
        ),
      ),
    );
  }
}
