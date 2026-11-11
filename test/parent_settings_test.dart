import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:final_project_app/core/auth/session.dart';
import 'package:final_project_app/features/parent/attendance_screen.dart';
import 'package:final_project_app/features/parent/parent_settings_screen.dart';

void main() {
  setUp(() {
    Session.role = null;
    Session.accountRole = null;
    Session.name = '테스트 보호자';
    Session.email = 'parent@example.com';
    Session.createdAt = DateTime(2024, 1, 2, 3, 4);
    Session.signupMethod = 'APP';
  });

  tearDown(() {
    Session.role = null;
    Session.accountRole = null;
    Session.name = null;
    Session.email = null;
    Session.createdAt = null;
    Session.signupMethod = null;
  });

  testWidgets('학부모 계정 정보에 가입 경로가 표시된다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: ParentAccountInfoScreen()),
    );

    expect(find.text('가입 경로'), findsOneWidget);
    expect(find.text('앱 가입'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('설정에서 출석·결석 관리 항목을 누르면 관리 화면으로 이동한다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ParentSettingsScreen()));

    expect(find.text('설정'), findsOneWidget);
    expect(find.text('출석·결석 관리'), findsOneWidget);

    await tester.tap(find.text('출석·결석 관리'));
    await tester.pumpAndSettle();

    expect(find.text('신청 날짜'), findsOneWidget);
    expect(find.text('선택한 날짜:'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
