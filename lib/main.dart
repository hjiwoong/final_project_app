import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase 초기화
  await Firebase.initializeApp();

  // Match Android's navigation buttons and gesture indicator to the light app surface.
  SystemChrome.setSystemUIOverlayStyle(AppTheme.systemOverlayStyle);

  // 네이버 지도 SDK 초기화
  try {
    await FlutterNaverMap().init(
      clientId: 'o9i3kd3g9k',
      onAuthFailed: (ex) {
        debugPrint('네이버맵 인증 실패: $ex');
      },
    );
  } catch (e) {
    debugPrint('네이버맵 초기화 중 오류 발생: $e');
  }

  runApp(const BusSafetyApp());
}

class BusSafetyApp extends StatelessWidget {
  const BusSafetyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '통학버스 안전',
      theme: AppTheme.light,
      debugShowCheckedModeBanner: false,
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: AppTheme.systemOverlayStyle,
        child: child ?? const SizedBox.shrink(),
      ),
      home: const LoginScreen(),
    );
  }
}
