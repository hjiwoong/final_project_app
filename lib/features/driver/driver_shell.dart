import 'package:flutter/material.dart';

import '../../core/auth/session.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/user_role.dart';
import '../../widgets/logout_confirmation_dialog.dart';
import '../auth/login_screen.dart';
import '../parent/notification_list_screen.dart';
import 'trip_start_screen.dart';

/// 기사(관리자) 하단 탭: 운행 · 알림 · 설정
class DriverShell extends StatefulWidget {
  const DriverShell({super.key});

  @override
  State<DriverShell> createState() => _DriverShellState();
}

class _DriverShellState extends State<DriverShell> {
  int _index = 0;

  static final List<Widget> _pages = [
    const TripStartScreen(),
    const NotificationListScreen(),
    const DriverSettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        elevation: 0,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.directions_bus_outlined),
            selectedIcon: Icon(Icons.directions_bus),
            label: '',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_outlined),
            selectedIcon: Icon(Icons.notifications),
            label: '',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '',
          ),
        ],
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
          const SizedBox(height: 0),
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              '계정 상세 정보',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.primary,
              ),
            ),
          ),
          Card(
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
              ],
            ),
          ),
        ],
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
          Icon(icon, color: AppTheme.accent, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            clipBehavior: Clip.antiAlias,
            child: Container(
              padding: const EdgeInsets.all(16),
              color: const Color(0xFFF1F6FF),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.directions_bus_rounded,
                      size: 28,
                      color: AppTheme.accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          Session.name?.isNotEmpty == true
                              ? Session.name!
                              : '사용자',
                          style: const TextStyle(
                            color: AppTheme.primary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          Session.email?.isNotEmpty == true
                              ? Session.email!
                              : '정보 없음',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              minVerticalPadding: 14,
              leading: const Icon(
                Icons.person_outline_rounded,
                color: AppTheme.accent,
              ),
              title: const Text(
                '계정 정보',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text('이름, 이메일, 계정 생성일 및 유형을 조회합니다.'),
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
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: OutlinedButton.icon(
            onPressed: () async {
              final shouldLogout = await showLogoutConfirmationDialog(context);
              if (!shouldLogout || !context.mounted) return;
              await Session.clear();
              if (!context.mounted) return;
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
            icon: const Icon(Icons.logout_rounded, color: AppTheme.danger),
            label: const Text(
              '로그아웃',
              style: TextStyle(
                color: AppTheme.danger,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
