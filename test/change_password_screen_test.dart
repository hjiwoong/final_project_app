import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:final_project_app/features/auth/change_password_screen.dart';

void main() {
  Future<void> openScreen(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: ChangePasswordScreen()));
  }

  testWidgets('비밀번호 변경 시 현재 비밀번호를 요구한다', (tester) async {
    await openScreen(tester);

    await tester.tap(find.byType(FilledButton));
    await tester.pump();

    expect(find.text('현재 비밀번호를 입력해 주세요.'), findsOneWidget);
  });

  testWidgets('새 비밀번호 확인이 일치하지 않으면 변경하지 않는다', (tester) async {
    await openScreen(tester);
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Current1!');
    await tester.enterText(fields.at(1), 'NewPassword1!');
    await tester.enterText(fields.at(2), 'Different1!');

    await tester.tap(find.byType(FilledButton));
    await tester.pump();

    expect(find.text('새 비밀번호가 일치하지 않습니다.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('현재 비밀번호와 같은 새 비밀번호는 허용하지 않는다', (tester) async {
    await openScreen(tester);
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Current1!');
    await tester.enterText(fields.at(1), 'Current1!');
    await tester.enterText(fields.at(2), 'Current1!');

    await tester.tap(find.byType(FilledButton));
    await tester.pump();

    expect(find.text('새 비밀번호는 현재 비밀번호와 달라야 합니다.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
