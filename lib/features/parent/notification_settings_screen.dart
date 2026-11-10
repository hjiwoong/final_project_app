import 'package:flutter/material.dart';

import '../../widgets/primary_button.dart';
import 'notification_settings_mock_store.dart';

import '../../core/notifications/in_app_notification_banner.dart';

// 학부모 알림 설정 화면 (Mock)
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  late bool _boardingEnabled;
  late bool _safetyEnabled;

  @override
  void initState() {
    super.initState();

    // 기존에 저장한 알림 설정값 불러오기
    _boardingEnabled = NotificationSettingsMockStore.boardingEnabled.value;

    _safetyEnabled = NotificationSettingsMockStore.safetyEnabled.value;
  }

  // 알림 설정 저장
  void _saveSettings() {
    NotificationSettingsMockStore.save(
      boarding: _boardingEnabled,
      safety: _safetyEnabled,
    );

    InAppNotificationBanner.showMessage('알림 설정이 저장되었습니다');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('알림 설정')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                children: [
                  Text(
                    '알림 수신 설정',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    '수신받을 알림을 설정합니다.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),

                  const SizedBox(height: 16),

                  Card(
                    child: Column(
                      children: [
                        // 승하차 알림
                        SwitchListTile(
                          secondary: Icon(
                            Icons.directions_bus,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          title: const Text('승하차 알림'),
                          subtitle: const Text('자녀 승차 및 하차 상태 알림'),
                          value: _boardingEnabled,
                          onChanged: (value) {
                            setState(() {
                              _boardingEnabled = value;
                            });
                          },
                        ),

                        const Divider(height: 1),

                        // 이상 상황 알림
                        SwitchListTile(
                          secondary: Icon(
                            Icons.warning_amber_rounded,
                            color: Theme.of(context).colorScheme.tertiary,
                          ),
                          title: const Text('이상 상황 알림'),
                          subtitle: const Text('급정거 · 과속 · 경로 이탈 알림'),
                          value: _safetyEnabled,
                          onChanged: (value) {
                            setState(() {
                              _safetyEnabled = value;
                            });
                          },
                        ),

                        const Divider(height: 1),

                        // 미하차 의심 경고 (필수)
                        SwitchListTile(
                          secondary: Icon(
                            Icons.health_and_safety,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          title: Text('미하차 의심 경고'),
                          subtitle: Text('필수 안전 알림 · 항상 활성화'),
                          value: NotificationSettingsMockStore
                              .leftBehindAlertEnabled,
                          onChanged: null,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),

                          SizedBox(width: 12),

                          Expanded(
                            child: Text(
                              '미하차 의심 경고는 어린이 안전을 위한 '
                              '필수 알림으로 해제할 수 없습니다.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  Text(
                    '승하차 및 일반 이상 상황 알림 설정은 아직 서버와 연결되지 않았습니다. '
                    '미하차 의심 경고는 필수 안전 알림으로 별도 푸시 발송됩니다.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            PrimaryButton(label: '저장', onPressed: _saveSettings),
          ],
        ),
      ),
    );
  }
}
