import 'package:flutter/material.dart';

/// 브랜드 고정 색상.
///
/// 주의: background / surface / border / textPrimary / textSecondary / info /
/// splashBg 는 **라이트 모드 전용 값**이다. 화면 위젯에서는 이 상수 대신
/// `context.appColors.xxx` 를 써야 다크모드에서도 올바른 색이 나온다.
/// (primary / primaryDark / accent / danger / success 같은 강조색은 그대로 써도 된다.)
class AppColors {
  static const primary = Color(0xFFFFC83D);
  static const primaryDark = Color(0xFFE3A526);
  static const background = Color(0xFFFFFCF4);
  static const splashBg = Color(0xFFFFF6E3);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFF1E5C9);
  static const textPrimary = Color(0xFF263056);
  static const textSecondary = Color(0xFF8A856F);
  static const accent = Color(0xFFF2784B);
  static const info = Color(0xFFD3EBFF);
  static const danger = Color(0xFFE5484D);
  static const success = Color(0xFF2E9E5B);

  /// 노란 primary 배경 위에 올라가는 글자·아이콘 색. 라이트/다크 모두 남색 유지.
  static const onPrimary = textPrimary;

  /// 현재 테마(라이트/다크)에 맞는 중립 색상 묶음.
  /// Theme.of 를 거치므로 테마가 바뀌면 해당 위젯이 다시 그려진다.
  static AppPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? AppPalette.dark
      : AppPalette.light;
}

/// 라이트/다크 모드별 중립 색상.
class AppPalette {
  const AppPalette({
    required this.background,
    required this.surface,
    required this.splashBg,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.info,
  });

  final Color background;
  final Color surface;
  final Color splashBg;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color info;

  static const light = AppPalette(
    background: AppColors.background,
    surface: AppColors.surface,
    splashBg: AppColors.splashBg,
    border: AppColors.border,
    textPrimary: AppColors.textPrimary,
    textSecondary: AppColors.textSecondary,
    info: AppColors.info,
  );

  // lib/theme/app_theme.dart 의 다크 테마 값과 맞춘다.
  static const dark = AppPalette(
    background: Color(0xFF000000),
    surface: Color(0xFF121212),
    splashBg: Color(0xFF1E1E1E),
    border: Color(0xFF333333),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFBDBDBD),
    info: Color(0xFF1E3A5F),
  );
}

extension AppColorsContext on BuildContext {
  /// 현재 테마에 맞는 중립 색상. 예: `context.appColors.textPrimary`
  AppPalette get appColors => AppColors.of(this);
}
