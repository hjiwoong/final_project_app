import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:final_project_app/data/mock/mock_repository.dart';
import 'package:final_project_app/features/auth/signup_screen.dart';
import 'package:final_project_app/main.dart';

void main() {
  testWidgets('BusSafetyApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const BusSafetyApp());
    expect(find.text('안전한 통학의 시작'), findsOneWidget);
    expect(find.text('Google로 로그인'), findsNothing);

    await tester.tap(find.text('로그인'));
    await tester.pumpAndSettle();

    expect(find.text('Google로 로그인'), findsOneWidget);
    expect(find.text('빠른 테스트 계정'), findsNothing);
    expect(find.text('기사(관리자) 계정'), findsNothing);
    expect(find.text('학부모 계정'), findsNothing);
    expect(find.text('Naver로 로그인'), findsNothing);

    await tester.tap(find.text('이메일로 로그인'));
    await tester.pumpAndSettle();

    expect(find.text('시작하려면 계정 정보를 입력해주세요'), findsOneWidget);
    expect(find.text('이메일 주소 입력'), findsOneWidget);
    expect(find.text('8자리 이상 입력'), findsOneWidget);
    expect(find.text('비밀번호 재설정'), findsOneWidget);
    expect(find.byType(AppBar), findsOneWidget);
  });

  testWidgets('회원가입은 계정 완료 후 자녀 연결을 선택할 수 있다', (WidgetTester tester) async {
    final requestCount = MockRepository.instance.signupRequests.length;
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
    await tester.enterText(find.byType(TextFormField).first, '테스트 보호자');
    await tester.pump();
    await tester.tap(find.text('계정 만들기'));
    await tester.pumpAndSettle();

    expect(find.text('계정 가입이 완료되었습니다'), findsOneWidget);
    expect(find.text('자녀 연결 요청 추가'), findsOneWidget);
    expect(find.text('나중에 하기'), findsOneWidget);
    expect(
      MockRepository.instance.signupRequests[requestCount].children,
      isEmpty,
    );
  });
}
