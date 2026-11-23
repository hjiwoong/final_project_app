import 'package:final_project_app/core/auth/session.dart';
import 'package:final_project_app/features/auth/login_screen.dart';
import 'package:final_project_app/features/driver/driver_shell.dart';
import 'package:final_project_app/features/parent/parent_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const storageChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );

  setUp(() {
    Session.name = '테스트 사용자';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, (call) async => null);
  });

  tearDown(() {
    Session.name = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, null);
  });

  for (final screen in <String, Widget>{
    '학부모': const ParentSettingsScreen(),
    '관리자·기사': const DriverSettingsScreen(),
  }.entries) {
    testWidgets('${screen.key} 설정에서 로그아웃 취소 시 세션을 유지한다', (tester) async {
      await tester.pumpWidget(MaterialApp(home: screen.value));
      await tester.ensureVisible(find.text('로그아웃'));
      await tester.tap(find.text('로그아웃'));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('로그아웃하시겠습니까?'), findsOneWidget);
      expect(find.text('취소'), findsOneWidget);

      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(Session.name, '테스트 사용자');
    });

    testWidgets('${screen.key} 설정에서 로그아웃 확인 시 세션을 지우고 로그인으로 이동한다', (
      tester,
    ) async {
      await tester.pumpWidget(MaterialApp(home: screen.value));
      await tester.ensureVisible(find.text('로그아웃'));
      await tester.tap(find.text('로그아웃'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.widgetWithText(FilledButton, '로그아웃'),
        ),
      );
      await tester.pumpAndSettle();

      expect(Session.name, isNull);
      expect(find.byType(LoginScreen), findsOneWidget);
    });
  }
}
