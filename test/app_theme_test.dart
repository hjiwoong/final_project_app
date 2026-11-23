import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:final_project_app/core/theme/app_theme.dart';
import 'package:final_project_app/theme/app_colors.dart';
import 'package:final_project_app/features/auth/splash_screen.dart';
import 'package:final_project_app/features/auth/email_login_screen.dart';

void main() {
  test('light theme uses the specified yellow palette', () {
    final theme = AppTheme.light;
    final colors = theme.colorScheme;
    expect(colors.primary, AppColors.primary);
    expect(colors.onPrimary, AppColors.textPrimary);
    expect(colors.secondary, AppColors.accent);
    expect(colors.onSecondary, Colors.white);
    expect(colors.surface, AppColors.surface);
    expect(colors.onSurface, AppColors.textPrimary);
    expect(colors.error, AppColors.danger);
    expect(colors.onError, Colors.white);
    expect(colors.tertiary, AppColors.success);
    expect(theme.scaffoldBackgroundColor, AppColors.background);
    expect(theme.appBarTheme.backgroundColor, AppColors.background);
    expect(theme.dividerTheme.color, AppColors.border);
    expect(theme.inputDecorationTheme.fillColor, AppColors.surface);
    expect(
      (theme.inputDecorationTheme.focusedBorder as OutlineInputBorder)
          .borderSide
          .color,
      AppColors.primaryDark,
    );
    for (final style in [
      theme.filledButtonTheme.style!,
      theme.elevatedButtonTheme.style!,
    ]) {
      expect(style.backgroundColor!.resolve({}), AppColors.primary);
      expect(style.foregroundColor!.resolve({}), AppColors.textPrimary);
      expect(style.minimumSize!.resolve({})!.height, 52);
      expect(
        (style.shape!.resolve({})! as RoundedRectangleBorder).borderRadius,
        BorderRadius.circular(12),
      );
    }
    expect(
      theme.segmentedButtonTheme.style!.backgroundColor!.resolve({
        WidgetState.selected,
      }),
      AppColors.primary,
    );
    expect(
      theme.segmentedButtonTheme.style!.foregroundColor!.resolve({
        WidgetState.selected,
      }),
      AppColors.textPrimary,
    );
    expect(AppTheme.dark.colorScheme.onPrimary, AppColors.textPrimary);
  });

  testWidgets('splash uses the requested background and bus asset', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SplashScreen(
          duration: const Duration(days: 1),
          onFinished: () {},
        ),
      ),
    );
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, AppColors.splashBg);
    final image = tester.widget<Image>(find.byType(Image));
    expect(
      (image.image as AssetImage).assetName,
      'assets/images/splash_bus.png',
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(days: 1));
  });

  testWidgets('email login keeps yellow button and outlined input borders', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const EmailLoginScreen()),
    );
    final inputs = tester.widgetList<TextField>(find.byType(TextField));
    for (final input in inputs) {
      final decoration = input.decoration!;
      expect(decoration.enabledBorder, isA<OutlineInputBorder>());
      expect(
        (decoration.enabledBorder! as OutlineInputBorder).borderSide.color,
        AppColors.border,
      );
      expect(
        (decoration.focusedBorder! as OutlineInputBorder).borderSide.color,
        AppColors.primaryDark,
      );
    }
    await tester.enterText(
      find.byType(TextFormField).first,
      'test@example.com',
    );
    await tester.enterText(find.byType(TextFormField).last, 'password123');
    await tester.pump();
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '로그인'),
    );
    expect(button.onPressed, isNotNull);
    final style = button.style ?? AppTheme.light.filledButtonTheme.style!;
    expect(style.backgroundColor!.resolve({}), AppColors.primary);
    expect(style.foregroundColor!.resolve({}), AppColors.textPrimary);
  });

  test('Android themes use the operating system sans-serif font', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    expect(AppTheme.light.textTheme.bodyMedium?.fontFamily, 'sans-serif');
    expect(AppTheme.dark.textTheme.bodyMedium?.fontFamily, 'sans-serif');
    expect(AppTheme.light.appBarTheme.titleTextStyle?.fontFamily, 'sans-serif');
    expect(AppTheme.dark.dialogTheme.titleTextStyle?.fontFamily, 'sans-serif');
  });

  testWidgets('navigation labels remain visible in both themes', (
    tester,
  ) async {
    for (final theme in [AppTheme.light, AppTheme.dark]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            bottomNavigationBar: NavigationBar(
              selectedIndex: 0,
              destinations: const [
                NavigationDestination(icon: Icon(Icons.home), label: '홈'),
                NavigationDestination(icon: Icon(Icons.settings), label: '설정'),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('홈'), findsOneWidget);
      expect(find.text('설정'), findsOneWidget);
      expect(
        theme.navigationBarTheme.labelBehavior,
        NavigationDestinationLabelBehavior.alwaysShow,
      );
      expect(tester.takeException(), isNull);
    }
  });
}
