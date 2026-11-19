import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:final_project_app/core/theme/app_theme.dart';

void main() {
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
