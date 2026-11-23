import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:final_project_app/core/network/api_client.dart';
import 'package:final_project_app/features/parent/parent_home_screen.dart';

void main() {
  testWidgets('승차와 하차 완료를 순서대로 확인하고 서버에 저장한다', (tester) async {
    final dio = ApiClient.instance.dio;
    final originalAdapter = dio.httpClientAdapter;
    final adapter = ParentAttendanceAdapter();
    dio.httpClientAdapter = adapter;
    addTearDown(() => dio.httpClientAdapter = originalAdapter);

    await tester.pumpWidget(const MaterialApp(home: ParentHomeScreen()));
    await tester.pumpAndSettle();

    expect(find.text('승차 확인 대기'), findsOneWidget);
    expect(find.text('승차 완료'), findsOneWidget);

    await tester.tap(find.text('승차 완료'));
    await tester.pumpAndSettle();
    expect(find.text('승차 완료 확인'), findsOneWidget);
    await tester.tap(find.text('승차 완료 확인'));
    await tester.pumpAndSettle();

    expect(adapter.confirmations, [
      {'event_type': 'BOARDING'},
    ]);
    expect(find.text('승차 확인 완료 · 하차 확인 대기'), findsOneWidget);
    expect(find.text('하차 완료'), findsOneWidget);

    await tester.tap(find.text('하차 완료'));
    await tester.pumpAndSettle();
    expect(find.text('하차 완료 확인'), findsOneWidget);
    await tester.tap(find.text('하차 완료 확인'));
    await tester.pumpAndSettle();

    expect(adapter.confirmations, [
      {'event_type': 'BOARDING'},
      {'event_type': 'ALIGHTING'},
    ]);
    expect(find.text('승차·하차 확인 완료'), findsOneWidget);
    expect(find.text('승차 완료'), findsNothing);
    expect(find.text('하차 완료'), findsNothing);
  });

  testWidgets('확인을 취소하면 승하차 기록을 전송하지 않는다', (tester) async {
    final dio = ApiClient.instance.dio;
    final originalAdapter = dio.httpClientAdapter;
    final adapter = ParentAttendanceAdapter();
    dio.httpClientAdapter = adapter;
    addTearDown(() => dio.httpClientAdapter = originalAdapter);

    await tester.pumpWidget(const MaterialApp(home: ParentHomeScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('승차 완료'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();

    expect(adapter.confirmations, isEmpty);
    expect(find.text('승차 완료'), findsOneWidget);
  });
}

class ParentAttendanceAdapter implements HttpClientAdapter {
  DateTime? boardingConfirmedAt;
  DateTime? alightingConfirmedAt;
  final List<Map<String, dynamic>> confirmations = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    dynamic data;
    if (options.method == 'POST' &&
        options.path == '/me/trips/12/students/34/confirmations') {
      final confirmation = Map<String, dynamic>.from(options.data as Map);
      confirmations.add(confirmation);
      if (confirmation['event_type'] == 'BOARDING') {
        boardingConfirmedAt = DateTime.utc(2026, 11, 19, 9);
      } else {
        alightingConfirmedAt = DateTime.utc(2026, 11, 19, 10);
      }
      data = {'ok': true};
    } else if (options.method == 'GET' && options.path == '/me/children') {
      data = [
        {
          'id': 34,
          'name': '김하늘',
          'class_name': '햇살반',
          'bus_name': '1호차',
          'bus_status': 'IN_PROGRESS',
          'trip_id': 12,
          'boarding_confirmed_at': boardingConfirmedAt?.toIso8601String(),
          'alighting_confirmed_at': alightingConfirmedAt?.toIso8601String(),
        },
      ];
    } else if (options.method == 'GET' &&
        (options.path == '/me/buses' || options.path == '/me/bus-status')) {
      data = [];
    } else {
      return ResponseBody.fromString(
        jsonEncode({'detail': 'Unexpected request'}),
        404,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }

    return ResponseBody.fromString(
      jsonEncode(data),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
