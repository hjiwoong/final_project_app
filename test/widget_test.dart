import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:final_project_app/features/auth/signup_screen.dart';
import 'package:final_project_app/main.dart';

void main() {
  testWidgets('BusSafetyApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const BusSafetyApp());
    expect(find.text('안전한 통학의 시작'), findsOneWidget);
    expect(find.text('Google로 로그인'), findsNothing);

    await tester.tap(find.text('로그인'));
    await tester.pumpAndSettle();

    expect(find.text('Google 계정으로 계속하기'), findsOneWidget);
    // 테스트 계정 바로가기는 제거되었다.
    expect(find.textContaining('테스트 계정'), findsNothing);
    expect(find.text('driver@school.kr'), findsNothing);
    expect(find.text('parent@school.kr'), findsNothing);
    expect(find.text('Naver로 로그인'), findsNothing);

    await tester.tap(find.text('이메일로 로그인'));
    await tester.pumpAndSettle();

    expect(find.text('시작하려면 계정 정보를 입력해주세요'), findsOneWidget);
    expect(find.text('이메일 주소 입력'), findsOneWidget);
    expect(find.text('8자리 이상 입력'), findsOneWidget);
    expect(find.text('비밀번호 재설정'), findsOneWidget);
    expect(find.byType(AppBar), findsOneWidget);
  });

  // 실제 가입 요청은 서버가 필요하므로 입력 단계 흐름만 확인한다.
  testWidgets('회원가입 화면은 이메일 → 비밀번호 → 이름 순서로 진행된다', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SignupScreen()));

    expect(find.text('이메일을 입력하세요'), findsOneWidget);
    expect(find.text('비밀번호'), findsNothing);

    await tester.enterText(
      find.byType(TextFormField).first,
      'new-parent@school.kr',
    );
    await tester.pump();
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();

    expect(find.text('비밀번호를 설정하세요'), findsOneWidget);
    expect(find.text('비밀번호 확인'), findsNothing);

    await tester.enterText(find.byType(TextFormField).first, 'password123');
    await tester.pump();
    expect(find.text('비밀번호 확인'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).last, 'password123');
    await tester.pump();
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();

    expect(find.text('이름을 입력하세요'), findsOneWidget);
    expect(find.text('계정 만들기'), findsOneWidget);
  });
}
