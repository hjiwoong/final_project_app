import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'in_app_notification_banner.dart';

final pushMessengerKey = GlobalKey<ScaffoldMessengerState>();

String? _readMessageValue(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = data[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
  }
  return null;
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  final title =
      message.notification?.title ??
      _readMessageValue(message.data, ['title', 'notification_title']) ??
      '새 알림';
  final body =
      message.notification?.body ??
      _readMessageValue(message.data, [
        'body',
        'message',
        'notification_body',
      ]) ??
      '';

  if (title.trim().isEmpty && body.trim().isEmpty) {
    return;
  }

  debugPrint('FCM 백그라운드 메시지 수신: $title / $body');
}

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  bool _listenersInitialized = false;

  Future<void> initialize({
    required Future<void> Function(String token) registerToken,
  }) async {
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);
      await messaging.setForegroundNotificationPresentationOptions(
        alert: false,
        badge: false,
        sound: false,
      );

      if (!_listenersInitialized) {
        FirebaseMessaging.onMessage.listen(_showIncomingNotification);
        FirebaseMessaging.onMessageOpenedApp.listen(_showIncomingNotification);
        messaging.onTokenRefresh.listen(
          (token) => unawaited(_registerToken(token, registerToken)),
          onError: (Object error) {
            debugPrint('FCM 토큰 갱신 수신 실패: $error');
          },
        );
        _listenersInitialized = true;
      }
      final token = await messaging.getToken();
      if (token != null) {
        await _registerToken(token, registerToken);
      }
    } catch (error) {
      debugPrint('푸시 알림 초기화 실패: $error');
    }
  }

  Future<void> _registerToken(
    String token,
    Future<void> Function(String token) registerToken,
  ) async {
    try {
      await registerToken(token);
    } catch (error) {
      debugPrint('푸시 토큰 서버 등록 실패: $error');
    }
  }

  void _showIncomingNotification(RemoteMessage message) {
    final title =
        message.notification?.title ??
        _readMessageValue(message.data, ['title', 'notification_title']) ??
        '새 알림';
    final body =
        message.notification?.body ??
        _readMessageValue(message.data, [
          'body',
          'message',
          'notification_body',
        ]) ??
        '';

    final cleanTitle = title.trim();
    final cleanBody = body.trim();
    if (cleanTitle.isEmpty && cleanBody.isEmpty) return;

    InAppNotificationBanner.show(
      title: cleanTitle.isEmpty ? cleanBody : cleanTitle,
      body: cleanTitle.isEmpty ? '' : cleanBody,
    );
  }
}
