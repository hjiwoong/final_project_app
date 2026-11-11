import 'package:flutter/material.dart';

import '../errors/app_error_message.dart';
import 'app_theme.dart';
import 'theme_controller.dart';

import '../notifications/in_app_notification_banner.dart';

class ThemeModeSettingsTile extends StatelessWidget {
  const ThemeModeSettingsTile({super.key});

  static const _labels = {
    ThemeMode.system: '시스템 설정 따르기',
    ThemeMode.light: '밝게',
    ThemeMode.dark: '어둡게',
  };

  Future<void> _selectThemeMode(BuildContext context) async {
    final controller = ThemeController.instance;
    final selectedMode = await showModalBottomSheet<ThemeMode>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Container(
          margin: AppTheme.sheetMargin,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          decoration: AppTheme.sheetDecoration(sheetContext),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '화면 테마',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 8),
              RadioGroup<ThemeMode>(
                groupValue: controller.themeMode,
                onChanged: (value) {
                  if (value != null) {
                    Navigator.of(sheetContext).pop(value);
                  }
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: ThemeMode.values
                      .map(
                        (mode) => RadioListTile<ThemeMode>(
                          value: mode,
                          title: Text(_labels[mode]!),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selectedMode == null || !context.mounted) return;

    try {
      await controller.setThemeMode(selectedMode);
    } catch (error) {
      if (!context.mounted) return;
      InAppNotificationBanner.showMessage(
        AppErrorMessage.from(error, fallback: '테마 설정을 저장하지 못했습니다. 다시 시도해 주세요.'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        return Card(
          color: Theme.of(context).scaffoldBackgroundColor,
          shape: const RoundedRectangleBorder(
            side: BorderSide.none,
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            minVerticalPadding: 14,
            leading: const Icon(Icons.dark_mode_outlined),
            title: const Text(
              '화면 테마',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(_labels[ThemeController.instance.themeMode]!),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _selectThemeMode(context),
          ),
        );
      },
    );
  }
}
