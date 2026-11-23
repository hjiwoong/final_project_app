import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';

class AppTheme {
  static const Color primary = AppColors.primary;
  static const Color accent = AppColors.accent;
  static const Color surface = AppColors.surface;
  static const Color splashBackground = AppColors.splashBg;
  static const Color subtleSurface = AppColors.background;
  static const Color border = AppColors.border;
  static const Color danger = AppColors.danger;
  static const Color ok = AppColors.success;
  static const Color darkSurface = Color(0xFF000000);
  static const Color darkCard = Color(0xFF121212);
  static const Color darkSubtleSurface = Color(0xFF1E1E1E);
  static const Color darkBorder = Color(0xFF333333);
  static const Color darkPrimary = AppColors.primary;
  static const Color darkOnPrimary = AppColors.textPrimary;
  static const Color lightContainer = AppColors.splashBg;
  static const Color lightContainerVariant = AppColors.background;
  static const Color lightOutline = AppColors.border;
  static const Color lightOutlineVariant = AppColors.border;
  static const Color lightMutedSurface = AppColors.background;
  static const Color darkContainer = Color(0xFF2A2A2A);
  static const Color darkContainerVariant = Color(0xFF383838);
  static const Color darkSecondary = AppColors.accent;
  static const Color darkOutline = Color(0xFF757575);
  static const Color darkMutedSurface = Color(0xFF1A1A1A);
  static const Color darkHighestSurface = Color(0xFF303030);
  static const Color darkOnSurfaceVariant = Color(0xFFBDBDBD);
  static const EdgeInsets sheetMargin = EdgeInsets.fromLTRB(12, 8, 12, 12);
  static const SystemUiOverlayStyle imageViewerSystemUiOverlayStyle =
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarContrastEnforced: false,
      );

  static BoxDecoration sheetDecoration(
    BuildContext context, {
    double radius = 24,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: isDark ? darkCard : subtleSurface,
      borderRadius: BorderRadius.all(Radius.circular(radius)),
      border: Border.all(color: isDark ? darkBorder : border),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
          blurRadius: 18,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  static List<String>? get systemCjkFontFallback =>
      defaultTargetPlatform == TargetPlatform.android
      ? const ['sans-serif']
      : null;

  static String? get systemFontFamily =>
      defaultTargetPlatform == TargetPlatform.android ? 'sans-serif' : null;

  static const SystemUiOverlayStyle systemOverlayStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: surface,
    systemNavigationBarDividerColor: surface,
    systemNavigationBarIconBrightness: Brightness.dark,
    systemNavigationBarContrastEnforced: false,
  );

  static SystemUiOverlayStyle systemOverlayStyleFor(
    Brightness brightness, {
    Color? modalBarrierColor,
  }) {
    final isDark = brightness == Brightness.dark;
    final baseNavigationBarColor = isDark ? darkSurface : surface;
    final navigationBarColor = modalBarrierColor == null
        ? baseNavigationBarColor
        : Color.alphaBlend(modalBarrierColor, baseNavigationBarColor);
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: navigationBarColor,
      systemNavigationBarDividerColor: navigationBarColor,
      systemNavigationBarIconBrightness: modalBarrierColor != null || isDark
          ? Brightness.light
          : Brightness.dark,
      systemNavigationBarContrastEnforced: false,
    );
  }

  static final ThemeData light = ThemeData(
    useMaterial3: true,
    fontFamily: systemFontFamily,
    fontFamilyFallback: systemCjkFontFallback,
    colorScheme: ColorScheme.light(
      primary: primary,
      onPrimary: AppColors.textPrimary,
      secondary: accent,
      onSecondary: Colors.white,
      tertiary: ok,
      primaryContainer: lightContainer,
      onPrimaryContainer: AppColors.textPrimary,
      secondaryContainer: lightContainerVariant,
      onSecondaryContainer: AppColors.textPrimary,
      tertiaryContainer: lightContainerVariant,
      onTertiaryContainer: AppColors.textPrimary,
      surfaceDim: AppColors.border,
      surfaceBright: surface,
      surfaceContainerLowest: surface,
      surfaceContainerLow: subtleSurface,
      surfaceContainer: lightMutedSurface,
      surfaceContainerHigh: lightContainer,
      surfaceContainerHighest: lightContainerVariant,
      surfaceTint: Colors.transparent,
      onSurface: AppColors.textPrimary,
      onSurfaceVariant: AppColors.textSecondary,
      outline: lightOutline,
      outlineVariant: lightOutlineVariant,
      surface: surface,
      error: danger,
      onError: Colors.white,
    ),
    scaffoldBackgroundColor: AppColors.background,
    dividerColor: lightOutlineVariant,
    dividerTheme: const DividerThemeData(color: border),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.primaryDark,
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.textPrimary,
      contentTextStyle: TextStyle(color: Colors.white),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 24,
        fontWeight: FontWeight.w500,
        fontFamily: systemFontFamily,
        fontFamilyFallback: systemCjkFontFallback,
      ),
      contentTextStyle: TextStyle(
        color: AppColors.textPrimary,
        fontFamily: systemFontFamily,
        fontFamilyFallback: systemCjkFontFallback,
      ),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? primary : lightOutline,
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.textPrimary,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      systemOverlayStyle: systemOverlayStyle,
      titleTextStyle: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        fontFamily: systemFontFamily,
        fontFamilyFallback: systemCjkFontFallback,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface,
      indicatorColor: Colors.transparent,
      indicatorShape: const StadiumBorder(),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? const IconThemeData(size: 26, color: AppColors.primaryDark)
            : const IconThemeData(size: 24, color: AppColors.textSecondary),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          color: states.contains(WidgetState.selected)
              ? AppColors.primaryDark
              : AppColors.textSecondary,
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
        ),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: surface,
      selectedItemColor: AppColors.primaryDark,
      unselectedItemColor: AppColors.textSecondary,
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: border),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: AppColors.textPrimary,
        minimumSize: const Size(0, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: AppColors.textPrimary,
        disabledBackgroundColor: const Color(0xFFCCCCCC),
        disabledForegroundColor: AppColors.textSecondary,
        minimumSize: const Size(0, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        backgroundColor: surface,
        foregroundColor: AppColors.textPrimary,
        side: const BorderSide(color: border),
        shape: const StadiumBorder(),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? primary : surface,
        ),
        foregroundColor: const WidgetStatePropertyAll(AppColors.textPrimary),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      prefixIconColor: AppColors.textSecondary,
      suffixIconColor: AppColors.textSecondary,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primaryDark, width: 1.5),
      ),
    ),
  );

  static final ThemeData dark = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: systemFontFamily,
    fontFamilyFallback: systemCjkFontFallback,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.dark,
      primary: darkPrimary,
      onPrimary: darkOnPrimary,
      primaryContainer: darkContainer,
      onPrimaryContainer: Colors.white,
      secondary: darkSecondary,
      onSecondary: Colors.white,
      secondaryContainer: darkContainerVariant,
      onSecondaryContainer: Colors.white,
      tertiary: const Color(0xFF86EFAC),
      onTertiary: Colors.black,
      tertiaryContainer: darkContainerVariant,
      onTertiaryContainer: Colors.white,
      surfaceDim: darkSurface,
      surfaceBright: darkHighestSurface,
      surfaceContainerLowest: darkSurface,
      surfaceContainerLow: darkCard,
      surfaceContainer: darkSubtleSurface,
      surfaceContainerHigh: darkContainer,
      surfaceContainerHighest: darkHighestSurface,
      surfaceTint: Colors.transparent,
      onSurface: Colors.white,
      onSurfaceVariant: darkOnSurfaceVariant,
      outline: darkOutline,
      outlineVariant: darkBorder,
      surface: darkSurface,
      error: const Color(0xFFFF6B6B),
    ),
    scaffoldBackgroundColor: darkSurface,
    dividerColor: darkBorder,
    dialogTheme: DialogThemeData(
      backgroundColor: darkCard,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 24,
        fontWeight: FontWeight.w500,
        fontFamily: systemFontFamily,
        fontFamilyFallback: systemCjkFontFallback,
      ),
      contentTextStyle: TextStyle(
        color: Colors.white,
        fontFamily: systemFontFamily,
        fontFamilyFallback: systemCjkFontFallback,
      ),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? darkPrimary
            : darkOnSurfaceVariant,
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: darkSurface,
      foregroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      systemOverlayStyle: systemOverlayStyleFor(Brightness.dark),
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        fontFamily: systemFontFamily,
        fontFamilyFallback: systemCjkFontFallback,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: darkSurface,
      indicatorColor: Colors.transparent,
      indicatorShape: const StadiumBorder(),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? IconThemeData(size: 26, color: darkPrimary)
            : const IconThemeData(size: 24, color: Color(0xFF9A9DA6)),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          color: states.contains(WidgetState.selected)
              ? darkPrimary
              : const Color(0xFF9A9DA6),
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
        ),
      ),
    ),
    cardTheme: CardThemeData(
      color: darkCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: darkBorder),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: darkPrimary,
        foregroundColor: darkOnPrimary,
        disabledBackgroundColor: const Color(0xFF454851),
        disabledForegroundColor: const Color(0xFFB6B8C0),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: darkPrimary,
        side: const BorderSide(color: darkBorder),
        shape: const StadiumBorder(),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: darkSubtleSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: darkBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: darkBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: darkPrimary, width: 1.5),
      ),
    ),
  );
}
