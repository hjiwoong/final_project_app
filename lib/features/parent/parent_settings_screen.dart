import 'package:flutter/material.dart';

import '../../core/auth/session.dart';
import '../../core/theme/theme_mode_settings_tile.dart';
import '../../data/models/user_role.dart';
import 'app_info_screen.dart';
import 'attendance_screen.dart';
import 'notification_settings_screen.dart';
import 'parent_attendance_screen.dart';
import 'parent_child_management_screen.dart';

class ParentSettingsScreen extends StatelessWidget {
  const ParentSettingsScreen({super.key});

  void _openAttendanceManagement(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const ParentAttendanceScreen(),
      ),
    );
  }

  void _openChildManagement(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ParentChildManagementScreen()),
    );
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
                    builder: (_) => const ParentAccountInfoScreen(),
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
              leading: const Icon(Icons.child_care_outlined),
              title: const Text(
                '자녀 관리',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              //subtitle: const Text('연결된 자녀 정보를 확인하고 연결을 요청합니다.'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _openChildManagement(context),
            ),
          ),
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
              leading: const Icon(Icons.event_available_outlined),
              title: const Text(
                '출석·결석 관리',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              // subtitle: const Text('날짜별 등교 및 결석 상태를 관리합니다.'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _openAttendanceManagement(context),
            ),
          ),
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
              leading: const Icon(Icons.notifications_none),
              title: const Text(
                '알림 설정',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              // subtitle: const Text('승하차 및 안전 알림을 관리합니다.'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const NotificationSettingsScreen(),
                  ),
                );
              },
            ),
          ),
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
              // subtitle: const Text('서비스 소개 및 테스트 버전 안내를 확인합니다.'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AppInfoScreen()),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
