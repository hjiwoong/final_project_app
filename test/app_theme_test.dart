import 'package:flutter/foundation.dart';
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
}
