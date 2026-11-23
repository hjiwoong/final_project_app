import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:final_project_app/core/network/api_client.dart';
import 'package:final_project_app/data/models/notification_item.dart';
import 'package:final_project_app/features/parent/notification_list_screen.dart';
import 'package:final_project_app/features/parent/unread_notification_store.dart';
import 'package:final_project_app/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

Map<String, dynamic> notification(
  int id,
  String category,
  DateTime sentAt, {
  bool isRead = false,
}) => {
  'id': id,
  'title': '알림 $id',
  'body': '본문 $id',
  'bus_name': '1호차',
  'sent_at': sentAt.toUtc().toIso8601String(),
  'read_at': isRead ? sentAt.toUtc().toIso8601String() : null,
  'is_read': isRead,
  'category': category,
  'event_type': 'EVENT',
  'trip_id': 7,
  'alert_id': null,
};

void main() {
  late NotificationAdapter adapter;

  setUp(() {
    adapter = NotificationAdapter();
    final dio = ApiClient.instance.dio;
    final original = dio.httpClientAdapter;
    final interceptors = dio.interceptors.toList();
    dio.interceptors.clear();
    dio.httpClientAdapter = adapter;
    UnreadNotificationStore.clear();
    addTearDown(() {
      dio.httpClientAdapter = original;
      dio.interceptors.addAll(interceptors);
      UnreadNotificationStore.clear();
    });
  });

  test('모델이 응답 필드와 로컬 시간을 읽는다', () {
    final date = DateTime.utc(2026, 11, 19, 9, 15);
    final item = NotificationItem.fromJson(
      notification(1, 'CHECK', date, isRead: true)..['alert_id'] = 8,
    );
    expect(item.id, 1);
    expect(item.busName, '1호차');
    expect(item.sentAt, date.toLocal());
    expect(item.sentAt.isUtc, isFalse);
    expect(item.readAt, date.toLocal());
    expect(item.isRead, isTrue);
    expect(item.category, 'CHECK');
    expect(item.eventType, 'EVENT');
    expect(item.tripId, 7);
    expect(item.alertId, 8);
  });

  testWidgets('날짜와 우선순위, 카테고리 스타일 및 읽음 표시를 적용한다', (tester) async {
    final now = DateTime.now();
    final old = DateTime(now.year, now.month, now.day - 3, 10, 5);
    final yesterday = DateTime(now.year, now.month, now.day - 1, 9, 4);
    final urgent = now.subtract(const Duration(minutes: 10));
    adapter.items = [
      notification(1, 'TRIP', now, isRead: true),
      notification(2, 'URGENT', urgent),
      notification(3, 'CHECK', yesterday),
      notification(4, 'TRIP', old, isRead: true),
    ];
    await tester.pumpWidget(const MaterialApp(home: NotificationListScreen()));
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.text('알림 2')).dy,
      lessThan(tester.getTopLeft(find.text('알림 1')).dy),
    );
    expect(find.text('오늘'), findsOneWidget);
    expect(find.text('어제'), findsOneWidget);
    expect(find.text(DateFormat('M월 d일').format(old)), findsOneWidget);
    expect(find.text(DateFormat('HH:mm').format(urgent)), findsOneWidget);
    expect(
      find.text('어제 ${DateFormat('HH:mm').format(yesterday)}'),
      findsOneWidget,
    );
    expect(find.text(DateFormat('M월 d일 HH:mm').format(old)), findsOneWidget);
    expect(
      tester.widget<Icon>(find.byIcon(Icons.error_rounded)).color,
      AppColors.danger,
    );
    expect(
      tester.widget<Icon>(find.byIcon(Icons.warning_amber_rounded)).color,
      AppColors.accent,
    );
    final title = tester.widget<Text>(find.text('알림 2'));
    expect(title.maxLines, 1);
    expect(title.overflow, TextOverflow.ellipsis);
    expect(title.style!.fontWeight, FontWeight.bold);
    final body = tester.widget<Text>(find.text('본문 2'));
    expect(body.maxLines, 2);
    expect(body.overflow, TextOverflow.ellipsis);
    expect(UnreadNotificationStore.unreadCount.value, 2);
  });

  testWidgets('필터는 category로 재조회하고 전체 읽음은 서버 처리 후 재조회한다', (tester) async {
    final now = DateTime.now();
    adapter.items = [
      notification(1, 'URGENT', now),
      notification(2, 'CHECK', now),
    ];
    await tester.pumpWidget(const MaterialApp(home: NotificationListScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('확인 필요'));
    await tester.pumpAndSettle();
    expect(adapter.getQueries.last, {'category': 'CHECK'});
    expect(find.text('알림 2'), findsOneWidget);
    expect(find.text('알림 1'), findsNothing);
    final chip = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, '확인 필요'),
    );
    expect(chip.selectedColor, AppColors.primary);
    expect(chip.labelStyle!.color, AppColors.textPrimary);

    await tester.tap(find.byTooltip('모두 읽음 처리'));
    await tester.pumpAndSettle();
    expect(adapter.posts, ['/me/notifications/read-all']);
    expect(adapter.getQueries.last, {'category': 'CHECK'});
    expect(UnreadNotificationStore.unreadCount.value, 0);
    expect(
      tester.widget<Text>(find.text('알림 2')).style!.fontWeight,
      FontWeight.normal,
    );
  });

  testWidgets('전체에서 24시간 이내 미읽음 긴급만 고정한다', (tester) async {
    final now = DateTime.now();
    adapter.items = [
      notification(1, 'TRIP', now.subtract(const Duration(hours: 1))),
      notification(
        2,
        'URGENT',
        now.subtract(const Duration(hours: 23, minutes: 59)),
      ),
      notification(
        3,
        'URGENT',
        now.subtract(const Duration(hours: 24, minutes: 1)),
      ),
      notification(
        4,
        'URGENT',
        now.subtract(const Duration(hours: 2)),
        isRead: true,
      ),
    ];
    await tester.pumpWidget(const MaterialApp(home: NotificationListScreen()));
    await tester.pumpAndSettle();
    final positions = <int, double>{
      for (final id in [1, 2, 3, 4])
        id: tester.getTopLeft(find.text('알림 $id')).dy,
    };
    expect(positions[2]!, lessThan(positions[1]!));
    expect(positions[1]!, lessThan(positions[4]!));
    expect(positions[4]!, lessThan(positions[3]!));

    await tester.tap(find.text('긴급'));
    await tester.pumpAndSettle();
    expect(adapter.getQueries.last, {'category': 'URGENT'});
    expect(
      tester.getTopLeft(find.text('알림 4')).dy,
      lessThan(tester.getTopLeft(find.text('알림 2')).dy),
    );
  });

  testWidgets('이전 필터의 늦은 응답이 현재 결과를 덮어쓰지 않는다', (tester) async {
    adapter.items = [
      notification(1, 'URGENT', DateTime.now()),
      notification(2, 'CHECK', DateTime.now()),
    ];
    final gate = Completer<void>();
    adapter.categoryGates['URGENT'] = gate;
    await tester.pumpWidget(const MaterialApp(home: NotificationListScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('긴급'));
    await tester.pump();
    await tester.tap(find.text('확인 필요'));
    await tester.pumpAndSettle();
    expect(find.text('알림 2'), findsOneWidget);
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('알림 2'), findsOneWidget);
    expect(find.text('알림 1'), findsNothing);
  });

  testWidgets('전체 읽음 실패 시 읽음 상태를 변경하지 않는다', (tester) async {
    adapter.items = [notification(1, 'TRIP', DateTime.now())];
    adapter.postStatus = 500;
    await tester.pumpWidget(const MaterialApp(home: NotificationListScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('모두 읽음 처리'));
    await tester.pumpAndSettle();
    expect(UnreadNotificationStore.unreadCount.value, 1);
    expect(
      tester.widget<Text>(find.text('알림 1')).style!.fontWeight,
      FontWeight.bold,
    );
    expect(adapter.getQueries.length, 1);
  });

  testWidgets('개별 알림을 누르면 기존 읽음 API를 사용한다', (tester) async {
    adapter.items = [notification(1, 'TRIP', DateTime.now())];
    await tester.pumpWidget(const MaterialApp(home: NotificationListScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('알림 1'));
    await tester.pumpAndSettle();
    expect(adapter.posts, ['/me/notifications/1/read']);
    expect(UnreadNotificationStore.unreadCount.value, 0);
  });

  testWidgets('로딩 스켈레톤, 422 오류, 재시도 및 빈 목록을 표시한다', (tester) async {
    final gate = Completer<void>();
    adapter.gate = gate;
    adapter.status = 422;
    await tester.pumpWidget(const MaterialApp(home: NotificationListScreen()));
    await tester.pump();
    expect(find.byType(CircleAvatar), findsNWidgets(3));
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('알림을 불러오지 못했어요'), findsOneWidget);
    adapter.status = 200;
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(find.text('새 알림이 없어요'), findsOneWidget);
    final calls = adapter.getQueries.length;
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 400));
    await tester.pumpAndSettle();
    expect(adapter.getQueries.length, calls + 1);
  });
}

class NotificationAdapter implements HttpClientAdapter {
  List<Map<String, dynamic>> items = [];
  final List<Map<String, dynamic>> getQueries = [];
  final List<String> posts = [];
  Completer<void>? gate;
  final Map<String, Completer<void>> categoryGates = {};
  int status = 200;
  int postStatus = 200;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.method == 'GET') {
      getQueries.add(Map<String, dynamic>.from(options.queryParameters));
      if (gate != null) await gate!.future;
      final category = options.queryParameters['category'];
      if (categoryGates[category] != null) {
        await categoryGates[category]!.future;
      }
      if (status != 200) return response({'detail': 'failed'}, status);
      final filtered = items
          .where((item) => category == null || item['category'] == category)
          .toList();
      return response({
        'items': filtered,
        'total': filtered.length,
        'unread_count': items.where((item) => item['is_read'] == false).length,
      });
    }
    posts.add(options.path);
    if (postStatus != 200) return response({'detail': 'failed'}, postStatus);
    if (options.path == '/me/notifications/read-all') {
      for (final item in items) {
        item['is_read'] = true;
      }
    } else {
      final id = int.parse(options.path.split('/')[3]);
      items.singleWhere((item) => item['id'] == id)['is_read'] = true;
    }
    return response({});
  }

  ResponseBody response(Object data, [int code = 200]) =>
      ResponseBody.fromString(
        jsonEncode(data),
        code,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

  @override
  void close({bool force = false}) {}
}
