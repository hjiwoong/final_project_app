import '../../widgets/settings_menu_tile.dart';
import 'package:flutter/material.dart';

import '../../core/auth/session.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_mode_settings_tile.dart';
import '../../data/api/api_repository.dart';
import '../../data/models/user_role.dart';
import '../../widgets/logout_confirmation_dialog.dart';
import '../auth/login_screen.dart';
import '../parent/notification_list_screen.dart';
import '../parent/unread_notification_store.dart';
import '../parent/unread_notification_badge.dart';
import 'trip_start_screen.dart';

/// 기사(관리자) 하단 탭: 운행 · 알림 · 설정
class DriverShell extends StatefulWidget {
  const DriverShell({super.key});

  @override
  State<DriverShell> createState() => _DriverShellState();
}

class _DriverShellState extends State<DriverShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _refreshUnreadCount();
  }

  Future<void> _refreshUnreadCount() async {
    try {
      final count = await ApiRepository.instance.getNotificationUnreadCount();
      UnreadNotificationStore.setCount(count);
    } catch (e) {
      debugPrint('읽지 않은 알림 개수 조회 실패: $e');
    }
  }

  static final List<Widget> _pages = [
    const TripStartScreen(),
    const NotificationListScreen(showSettingsButton: false),
    const DriverSettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_index],
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
          onDestinationSelected: (i) => setState(() => _index = i),
          elevation: 0,
          height: 60,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
          destinations: [
            NavigationDestination(
              icon: Icon(Icons.directions_bus_outlined),
              selectedIcon: Icon(Icons.directions_bus),
              label: '',
            ),
            NavigationDestination(
              icon: const UnreadNotificationBadge(
                icon: Icons.notifications_outlined,
              ),
              selectedIcon: const UnreadNotificationBadge(
                icon: Icons.notifications,
              ),
              label: '',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: '',
            ),
          ],
        ),
      ),
    );
  }
}

class DriverAccountInfoScreen extends StatelessWidget {
  const DriverAccountInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('계정 정보')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              '계정 상세 정보',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          Card(
            margin: const EdgeInsets.all(4),
            shape: const RoundedRectangleBorder(
              side: BorderSide.none,
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            child: Column(
              children: [
                _AccountInfoRow(
                  label: '사용자 이름',
                  value: Session.name?.isNotEmpty == true
                      ? Session.name!
                      : '정보 없음',
                  icon: Icons.badge_outlined,
                ),
                _AccountInfoRow(
                  label: '이메일',
                  value: Session.email?.isNotEmpty == true
                      ? Session.email!
                      : '정보 없음',
                  icon: Icons.email_outlined,
                ),
                _AccountInfoRow(
                  label: '계정 생성일',
                  value: _formatCreatedAt(Session.createdAt),
                  icon: Icons.calendar_today_outlined,
                ),
                _AccountInfoRow(
                  label: '계정 유형',
                  value: _accountRoleLabel(),
                  icon: Icons.admin_panel_settings_outlined,
                ),
                _AccountInfoRow(
                  label: '가입 경로',
                  value: _signupMethodLabel(),
                  icon: Icons.how_to_reg_outlined,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SettingsMenuTile(
            icon: Icons.logout_rounded,
            title: '로그아웃',
            color: AppTheme.danger,
            showChevron: false,
            onTap: () async {
              final shouldLogout = await showLogoutConfirmationDialog(context);
              if (!shouldLogout || !context.mounted) return;
              await Session.clear();
              if (!context.mounted) return;
              Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (_) => false,
              );
            },
          ),        ],
      ),
    );
  }

  String _formatCreatedAt(DateTime? createdAt) {
    if (createdAt == null) return '정보 없음';
    final date = createdAt.toLocal();
    return '${date.year}년 ${date.month}월 ${date.day}일 '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  String _accountRoleLabel() {
    final code = Session.accountRole?.toUpperCase();
    return switch (code) {
      'ADMIN' => '관리자',
      'DRIVER' => '기사',
      'PARENT' => '학부모',
      _ => switch (Session.role) {
        UserRole.driver => '기사',
        UserRole.parent => '학부모',
        null => '정보 없음',
      },
    };
  }

  String _signupMethodLabel() {
    return switch (Session.signupMethod?.toUpperCase()) {
      'APP' => 'App',
      'GOOGLE' => 'Google Account',
      'ADMIN' => 'Web',
      'LEGACY' => '기존 계정 (가입 경로 미기록)',
      _ => '정보 없음',
    };
  }
}

class DriverAppInfoScreen extends StatelessWidget {
  const DriverAppInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('앱 정보')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              '서비스 소개',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Icon(
                    Icons.directions_bus_rounded,
                    color: AppTheme.accent,
                    size: 40,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'AI 통학버스 안전관리 서비스',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '어린이의 안전한 통학을 위한 운행 및 승하차 관리 서비스입니다.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              '앱 상세 정보',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          const Card(
            child: Column(
              children: [
                _AccountInfoRow(
                  label: '서비스 유형',
                  value: '기사용 앱',
                  icon: Icons.badge_outlined,
                ),
                _AccountInfoRow(
                  label: '주요 기능',
                  value: '운행 시작 및 종료, 승하차 확인, 알림 조회',
                  icon: Icons.checklist_rounded,
                ),
                _AccountInfoRow(
                  label: '앱 버전',
                  value: 'Dev',
                  icon: Icons.info_outline_rounded,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountInfoRow extends StatelessWidget {
  const _AccountInfoRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DriverSettingsScreen extends StatelessWidget {
  const DriverSettingsScreen({super.key});

  String _accountRoleLabel() {
    final code = Session.accountRole?.toUpperCase();
    return switch (code) {
      'ADMIN' => '관리자',
      'DRIVER' => '기사',
      'PARENT' => '학부모',
      _ => switch (Session.role) {
        UserRole.driver => '기사',
        UserRole.parent => '학부모',
        null => '정보 없음',
      },
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = isDark
        ? theme.colorScheme.surfaceContainerHigh
        : const Color(0xFFFAFAFA);
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            margin: EdgeInsets.zero,
            color: cardColor,
            clipBehavior: Clip.antiAlias,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    cardColor,
                    cardColor,
                    isDark
                        ? const Color(0xFFFFF8E6).withValues(alpha: 0.18)
                        : const Color(0xFFFFF8E6),
                  ],
                  stops: const [0.0, 0.65, 1.0],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white.withValues(
                      alpha: isDark ? 0.08 : 0.9,
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      size: 32,
                      color: Color(0xFFFF8A00),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          Session.name?.isNotEmpty == true
                              ? Session.name!
                              : '사용자',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          Session.email?.isNotEmpty == true
                              ? Session.email!
                              : '이메일 정보 없음',
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFFF8A00,
                            ).withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            _accountRoleLabel(),
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Card(
            margin: EdgeInsets.zero,
            color: Theme.of(context).scaffoldBackgroundColor,
            shape: const RoundedRectangleBorder(
              side: BorderSide.none,
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 10),
              minVerticalPadding: 0,
              leading: const Icon(Icons.person_outline_rounded),
              title: const Text(
                '계정 정보',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              // subtitle: const Text('이름, 이메일, 계정 생성일 및 유형을 조회합니다.'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const DriverAccountInfoScreen(),
                  ),
                );
              },
            ),
          ),
          const ThemeModeSettingsTile(),
          Card(
            margin: EdgeInsets.zero,
            color: Theme.of(context).scaffoldBackgroundColor,
            shape: const RoundedRectangleBorder(
              side: BorderSide.none,
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 10),
              minVerticalPadding: 0,
              leading: const Icon(Icons.info_outline_rounded),
              title: const Text(
                '앱 정보',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              // subtitle: const Text('서비스 소개, 앱 유형 및 주요 기능을 확인합니다.'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const DriverAppInfoScreen(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: const SizedBox.shrink(),
    );
  }
}
