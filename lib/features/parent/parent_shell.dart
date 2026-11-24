import 'package:flutter/material.dart';

import '../../core/auth/session.dart';
import '../../widgets/app_bottom_navigation_bar.dart';
import '../auth/login_screen.dart';
import '../auth/parent_terms_gate.dart';
import 'notification_list_screen.dart';
import 'parent_home_screen.dart';
import 'parent_settings_screen.dart';
import 'unread_notification_badge.dart';

// 학부모 하단 탭: 홈 · 알림 · 설정
// (출결 관리 · AI 채팅은 홈의 빠른 메뉴에서 연다)
class ParentShell extends StatefulWidget {
  const ParentShell({super.key});

  @override
  State<ParentShell> createState() => _ParentShellState();
}

class _ParentShellState extends State<ParentShell> {
  int _index = 0;
  int _urgentSelectionRequest = 0;
  final Set<int> _visitedTabs = {0};

  @override
  Widget build(BuildContext context) {
    return ParentTermsGate(
      onLogout: () async {
        await Session.clear();
        if (!context.mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      },
      child: _buildShell(),
    );
  }

  Widget _buildShell() {
    final pages = [
      ParentHomeScreen(
        active: _index == 0,
        onOpenUrgentAlerts: () => setState(() {
          _urgentSelectionRequest++;
          _visitedTabs.add(1);
          _index = 1;
        }),
      ),
      NotificationListScreen(urgentSelectionRequest: _urgentSelectionRequest),
      const ParentSettingsScreen(),
    ];
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          for (var index = 0; index < pages.length; index++)
            _visitedTabs.contains(index)
                ? pages[index]
                : const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: AppBottomNavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() {
          _visitedTabs.add(i);
          _index = i;
        }),
        destinations: [
          // 홈
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home_rounded),
            label: '홈',
          ),
          // 알림
          NavigationDestination(
            icon: const UnreadNotificationBadge(
              icon: Icons.notifications_outlined,
              dot: true,
            ),
            selectedIcon: const UnreadNotificationBadge(
              icon: Icons.notifications,
              dot: true,
            ),
            label: '알림',
          ),
          //설정
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: '설정',
          ),
        ],
      ),
    );
  }
}
