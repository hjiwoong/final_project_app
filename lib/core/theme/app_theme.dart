import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  static const Color primary = Color(0xFF1976D2);
  static const Color accent = Color(0xFF42A5F5);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color subtleSurface = Color(0xFFF8F9FA);
  static const Color border = Color(0xFFE1E3E6);
  static const Color danger = Color(0xFFDC2626);
  static const Color ok = Color(0xFF16A34A);
  static const Color darkSurface = Color(0xFF000000);
  static const Color darkCard = Color(0xFF121212);
  static const Color darkSubtleSurface = Color(0xFF1E1E1E);
  static const Color darkBorder = Color(0xFF333333);
  static const Color darkPrimary = Color(0xFF90CAF9);
  static const Color darkOnPrimary = Color(0xFF102A43);
  static const Color lightContainer = Color(0xFFF1F1F1);
  static const Color lightContainerVariant = Color(0xFFE8E8E8);
  static const Color lightOutline = Color(0xFFBDBDBD);
  static const Color lightOutlineVariant = Color(0xFFD6D6D6);
  static const Color lightMutedSurface = Color(0xFFF5F5F5);
  static const Color darkContainer = Color(0xFF2A2A2A);
  static const Color darkContainerVariant = Color(0xFF383838);
  static const Color darkSecondary = Color(0xFF64B5F6);
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

  static const SystemUiOverlayStyle systemOverlayStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: surface,
    systemNavigationBarDividerColor: surface,
    systemNavigationBarIconBrightness: Brightness.dark,
    systemNavigationBarContrastEnforced: false,
  );

  static SystemUiOverlayStyle systemOverlayStyleFor(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: isDark ? darkSurface : surface,
      systemNavigationBarDividerColor: isDark ? darkSurface : surface,
      systemNavigationBarIconBrightness: isDark
          ? Brightness.light
          : Brightness.dark,
      systemNavigationBarContrastEnforced: false,
    );
  }

  static final ThemeData light = ThemeData(
    useMaterial3: true,
    fontFamilyFallback: systemCjkFontFallback,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      onPrimary: Colors.white,
      secondary: accent,
      tertiary: ok,
      primaryContainer: lightContainer,
      onPrimaryContainer: primary,
      secondaryContainer: lightContainerVariant,
      onSecondaryContainer: primary,
      tertiaryContainer: lightContainerVariant,
      onTertiaryContainer: primary,
      surfaceDim: const Color(0xFFE5E5E5),
      surfaceBright: surface,
      surfaceContainerLowest: surface,
      surfaceContainerLow: subtleSurface,
      surfaceContainer: lightMutedSurface,
      surfaceContainerHigh: lightContainer,
      surfaceContainerHighest: lightContainerVariant,
      surfaceTint: Colors.transparent,
      onSurface: const Color(0xFF171717),
      onSurfaceVariant: const Color(0xFF5F5F5F),
      outline: lightOutline,
      outlineVariant: lightOutlineVariant,
      surface: surface,
      error: danger,
    ),
    scaffoldBackgroundColor: surface,
    dividerColor: lightOutlineVariant,
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        color: Color(0xFF171717),
        fontSize: 24,
        fontWeight: FontWeight.w500,
        fontFamilyFallback: systemCjkFontFallback,
      ),
      contentTextStyle: TextStyle(
        color: Color(0xFF171717),
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
      backgroundColor: surface,
      foregroundColor: Color(0xFF171717),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      systemOverlayStyle: systemOverlayStyle,
      titleTextStyle: TextStyle(
        color: Color(0xFF171717),
        fontSize: 18,
        fontWeight: FontWeight.w700,
        fontFamilyFallback: systemCjkFontFallback,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface,
      indicatorColor: Colors.transparent,
      indicatorShape: const StadiumBorder(),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? const IconThemeData(size: 26, color: primary)
            : const IconThemeData(size: 24, color: Color(0xFF858B93)),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          color: states.contains(WidgetState.selected) ? primary : Colors.grey,
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
        ),
      ),
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: border),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: const Color(0xFFCCCCCC),
        disabledForegroundColor: Colors.white,
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primary,
        side: const BorderSide(color: border),
        shape: const StadiumBorder(),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: subtleSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: accent, width: 1.5),
      ),
    ),
  );

  static final ThemeData dark = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamilyFallback: systemCjkFontFallback,
    colorScheme: ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.dark,
      primary: darkPrimary,
      onPrimary: darkOnPrimary,
      primaryContainer: darkContainer,
      onPrimaryContainer: Colors.white,
      secondary: darkSecondary,
      onSecondary: Colors.black,
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
        fontFamilyFallback: systemCjkFontFallback,
      ),
      contentTextStyle: TextStyle(
        color: Colors.white,
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
        fontFamilyFallback: systemCjkFontFallback,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: darkSurface,
      indicatorColor: Colors.transparent,
      indicatorShape: const StadiumBorder(),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
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
