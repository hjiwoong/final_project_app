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

  static const _summaryLabels = {
    ThemeMode.system: '시스템',
    ThemeMode.light: '밝게',
    ThemeMode.dark: '어둡게',
  };

  static const _icons = {
    ThemeMode.system: Icons.settings_suggest_outlined,
    ThemeMode.light: Icons.light_mode_outlined,
    ThemeMode.dark: Icons.dark_mode_outlined,
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  '화면 테마',
                  style: Theme.of(
                    sheetContext,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 12),
              for (final mode in ThemeMode.values)
                _ThemeModeOption(
                  label: _labels[mode]!,
                  icon: _icons[mode]!,
                  selected: controller.themeMode == mode,
                  onTap: () => Navigator.of(sheetContext).pop(mode),
                ),
              const SizedBox(height: 4),
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
        final selectedMode = ThemeController.instance.themeMode;
        return Card(
          margin: EdgeInsets.zero,
          color: Theme.of(context).scaffoldBackgroundColor,
          shape: const RoundedRectangleBorder(
            side: BorderSide.none,
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 10),
            minVerticalPadding: 0,
            leading: const Icon(Icons.dark_mode_outlined),
            title: const Text(
              '화면 테마',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _summaryLabels[selectedMode]!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.more_vert_rounded),
              ],
            ),
            onTap: () => _selectThemeMode(context),
          ),
        );
      },
    );
  }
}

class _ThemeModeOption extends StatelessWidget {
  const _ThemeModeOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foregroundColor = selected
        ? colorScheme.primary
        : colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: selected
            ? colorScheme.primary.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Semantics(
            inMutuallyExclusiveGroup: true,
            selected: selected,
            button: true,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                children: [
                  Icon(icon, size: 22, color: foregroundColor),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: foregroundColor,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                  if (selected)
                    Icon(
                      Icons.check_circle_rounded,
                      size: 20,
                      color: colorScheme.primary,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
