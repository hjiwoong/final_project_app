import 'package:final_project_app/core/auth/session.dart';
import 'package:final_project_app/features/auth/account_removal_screen.dart';
import 'package:final_project_app/features/driver/driver_shell.dart';
import 'package:final_project_app/data/models/account_deletion_schedule.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    Session.role = null;
    Session.accountRole = 'DRIVER';
    Session.name = '테스트 사용자';
    Session.email = 'test@example.com';
    Session.createdAt = DateTime(2024, 1, 2, 3, 4);
  });

  tearDown(() {
    Session.role = null;
    Session.accountRole = null;
    Session.email = null;
    Session.name = null;
    Session.createdAt = null;
  });

  testWidgets('로그아웃 아래 계정 제거를 눌러 주의사항과 계정 정보를 확인한다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: DriverAccountInfoScreen()));

    expect(find.text('로그아웃'), findsOneWidget);
    await tester.tap(find.text('계정 제거'));
    await tester.pumpAndSettle();

    expect(find.byType(AccountRemovalScreen), findsOneWidget);
    expect(find.text('테스트 사용자'), findsOneWidget);
    expect(find.text('test@example.com'), findsOneWidget);
    expect(find.text('계정 삭제 시 참고 사항'), findsOneWidget);
    expect(find.textContaining('30일 후 영구 삭제'), findsOneWidget);
    expect(find.text('계정 삭제는 학부모 계정에서만 요청할 수 있습니다.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('학부모가 계정 삭제를 누르면 비밀번호를 확인하도록 요청한다', (tester) async {
    Session.accountRole = 'PARENT';
    await tester.pumpWidget(const MaterialApp(home: AccountRemovalScreen()));

    await tester.tap(find.byType(OutlinedButton));
    await tester.pumpAndSettle();

    expect(find.textContaining('30일 후 영구 삭제'), findsOneWidget);
    expect(find.text('현재 비밀번호'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Google 계정으로 재인증'), findsOneWidget);
    expect(find.text('삭제 예약'), findsOneWidget);

    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(find.byType(AccountRemovalScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('비밀번호 입력 후 삭제 예약을 한 번 더 확인하고 돌아갈 수 있다', (tester) async {
    Session.accountRole = 'PARENT';
    await tester.pumpWidget(const MaterialApp(home: AccountRemovalScreen()));

    await tester.tap(find.byType(OutlinedButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Password1!');
    await tester.tap(find.text('삭제 예약'));
    await tester.pumpAndSettle();

    expect(find.text('계정 삭제를 예약하시겠습니까?'), findsOneWidget);
    expect(find.text('30일 후 영구 삭제됩니다.'), findsOneWidget);
    expect(find.text('돌아가기'), findsOneWidget);
    expect(find.text('삭제 예약'), findsNWidgets(2));

    await tester.tap(find.text('돌아가기'));
    await tester.pumpAndSettle();
    expect(find.text('계정 삭제를 예약하시겠습니까?'), findsNothing);
    expect(find.byType(AccountRemovalScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('삭제 유예 중에는 남은 기간과 취소·로그아웃을 표시한다', (tester) async {
    final now = DateTime.now();
    await tester.pumpWidget(
      MaterialApp(
        home: AccountDeletionPendingScreen(
          email: 'parent@example.com',
          password: 'Password1!',
          schedule: AccountDeletionSchedule(
            requestedAt: now.subtract(const Duration(days: 18)),
            scheduledDeletionAt: now.add(const Duration(days: 12)),
            gracePeriodDays: 30,
            daysRemaining: 12,
          ),
        ),
      ),
    );

    expect(find.text('계정 삭제까지 12일 남았습니다.'), findsOneWidget);
    expect(find.text('계정 삭제 취소'), findsOneWidget);
    expect(find.text('로그아웃'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
