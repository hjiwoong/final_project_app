import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

import 'core/maps/naver_map_status.dart';
import 'core/notifications/in_app_notification_banner.dart';
import 'core/notifications/push_notification_service.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/modal_system_ui_observer.dart';
import 'core/theme/theme_controller.dart';
import 'features/auth/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase 초기화
  await Firebase.initializeApp();
  await ThemeController.instance.initialize();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Match Android's navigation buttons and gesture indicator to the light app surface.
  SystemChrome.setSystemUIOverlayStyle(AppTheme.systemOverlayStyle);

  // 네이버 지도 SDK 초기화
  try {
    await FlutterNaverMap().init(
      clientId: 'o9i3kd3g9k',
      onAuthFailed: (ex) {
        naverMapAuthError.value = ex.toString();
        debugPrint(
          '네이버 지도 인증 실패: $ex. Client ID, Dynamic Map 활성화 및 Android 패키지 등록을 확인하세요.',
        );
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
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) => MaterialApp(
        title: '통학버스 안전',
        navigatorKey: appNavigatorKey,
        navigatorObservers: [ModalSystemUiObserver.instance],
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeController.instance.themeMode,
        debugShowCheckedModeBanner: false,
        scaffoldMessengerKey: pushMessengerKey,
        builder: (context, child) => ListenableBuilder(
          listenable: ModalSystemUiObserver.instance.barrierColor,
          builder: (context, _) => AnnotatedRegion<SystemUiOverlayStyle>(
            value: AppTheme.systemOverlayStyleFor(
              Theme.of(context).brightness,
              modalBarrierColor:
                  ModalSystemUiObserver.instance.barrierColor.value,
            ),
            child: child ?? const SizedBox.shrink(),
          ),
        ),
        home: const LoginScreen(),
      ),
    );
  }
}
