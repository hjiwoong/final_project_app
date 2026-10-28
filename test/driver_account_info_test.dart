import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:final_project_app/core/auth/session.dart';
import 'package:final_project_app/features/driver/driver_shell.dart';

void main() {
  tearDown(() {
    Session.role = null;
    Session.accountRole = null;
    Session.email = null;
    Session.name = null;
    Session.createdAt = null;
  });

  testWidgets('기사 계정 정보에 계정 상세 정보가 표시된다', (WidgetTester tester) async {
    Session.name = '홍길동';
    Session.email = 'driver@example.com';
    Session.accountRole = 'ADMIN';
    Session.createdAt = DateTime(2024, 1, 2, 3, 4);

    await tester.pumpWidget(const MaterialApp(home: DriverAccountInfoScreen()));

    expect(find.text('홍길동'), findsNWidgets(2));
    expect(find.text('driver@example.com'), findsNWidgets(2));
    expect(find.text('계정 생성일'), findsOneWidget);
    expect(find.text('2024년 1월 2일 03:04'), findsOneWidget);
    expect(find.text('관리자'), findsOneWidget);
  });

  testWidgets('설정 목록에서 계정 정보 화면을 연다', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: DriverSettingsScreen()));

    expect(find.text('계정 정보'), findsOneWidget);
    expect(find.text('로그아웃'), findsOneWidget);

    await tester.tap(find.text('계정 정보'));
    await tester.pumpAndSettle();

    expect(find.text('계정 상세 정보'), findsOneWidget);
    expect(find.text('계정 생성일'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
