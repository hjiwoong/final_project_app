import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/notifications/in_app_notification_banner.dart';

/// 학부모 알림 설정 화면
/// 서버는 자녀 배정 버스의 미하차 의심(긴급) 경고를 푸시로 보낸다. 이 화면은 기기의
/// 푸시 알림 권한 상태를 보여 주고, 꺼져 있으면 다시 켜도록 안내한다.
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen>
    with WidgetsBindingObserver {
  AuthorizationStatus? _status;
  bool _loading = true;

  bool get _enabled =>
      _status == AuthorizationStatus.authorized ||
      _status == AuthorizationStatus.provisional;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // 시스템 설정에서 돌아오면 권한 상태를 다시 읽는다.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadStatus();
  }

  Future<void> _loadStatus() async {
    try {
      final settings = await FirebaseMessaging.instance
          .getNotificationSettings();
      if (!mounted) return;
      setState(() {
        _status = settings.authorizationStatus;
        _loading = false;
      });
    } catch (e) {
      debugPrint('알림 권한 상태 확인 실패: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _enableNotifications() async {
    if (_status == AuthorizationStatus.notDetermined) {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (!mounted) return;
      setState(() => _status = settings.authorizationStatus);
      if (_enabled) {
        InAppNotificationBanner.showMessage('알림이 켜졌습니다.');
        return;
      }
    }
    final opened = await openAppSettings();
    if (!opened && mounted) {
      InAppNotificationBanner.showMessage('기기 설정에서 앱 알림을 허용해 주세요.');
    }
  }

  Widget _alertTypeTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Icon(
        _enabled ? Icons.check_circle : Icons.notifications_off_outlined,
        color: _enabled
            ? Theme.of(context).colorScheme.tertiary
            : Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('알림 설정')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  color: _enabled
                      ? colors.tertiaryContainer
                      : colors.errorContainer,
                  child: ListTile(
                    leading: Icon(
                      _enabled
                          ? Icons.notifications_active
                          : Icons.notifications_off,
                      color: _enabled
                          ? colors.onTertiaryContainer
                          : colors.onErrorContainer,
                    ),
                    title: Text(
                      _enabled ? '푸시 알림 켜짐' : '푸시 알림 꺼짐',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      _enabled
                          ? '미하차 의심 경고를 바로 받을 수 있습니다.'
                          : '알림이 꺼져 있으면 미하차 의심 경고를 놓칠 수 있습니다.',
                    ),
                  ),
                ),
                if (!_enabled) ...[
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _enableNotifications,
                    icon: const Icon(Icons.settings),
                    label: const Text('알림 켜기'),
                  ),
                ],
                const SizedBox(height: 24),
                const Text(
                  '받는 알림',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      _alertTypeTile(
                        icon: Icons.health_and_safety,
                        color: colors.error,
                        title: '미하차 의심 경고',
                        subtitle: '종점 사진에서 잔류 인원이 감지되면 즉시 발송 · 필수 알림',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '미하차 의심 경고는 어린이 안전을 위한 필수 알림이라 앱에서 '
                  '따로 끌 수 없습니다. 자녀가 오늘 버스를 타지 않는다면 '
                  '홈의 출석·결석 설정에서 결석으로 지정하면 그날 그 버스의 '
                  '경고 알림이 오지 않습니다.',
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ),
    );
  }
}
