import 'package:flutter/material.dart';

class AppTheme {
  static const Color primary = Color(0xFF2563EB);
  static const Color danger = Color(0xFFDC2626);
  static const Color ok = Color(0xFF16A34A);

  static final ThemeData light = ThemeData(
    colorSchemeSeed: primary,
    useMaterial3: true,
  );
}
