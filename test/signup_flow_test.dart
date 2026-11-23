import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:final_project_app/data/api/api_repository.dart';
import 'package:final_project_app/data/models/signup_term.dart';
import 'package:final_project_app/features/auth/signup_screen.dart';
import 'package:final_project_app/features/parent/parent_shell.dart';

void main() {
  testWidgets('이름 단계에서 약관 화면으로 이동하고 입력값을 유지한다', (WidgetTester tester) async {
    final gateway = _FakeSignupGateway();
    await _reachNameStep(tester, gateway);

    await tester.tap(find.text('약관 확인'));
    await tester.pumpAndSettle();

    expect(find.text('약관 확인'), findsOneWidget);
    expect(find.text('서비스 이용을 위해 아래 약관을 확인해 주세요.'), findsOneWidget);
    expect(find.text('쿠키 사용'), findsOneWidget);
    expect(find.text('이용약관'), findsOneWidget);
    expect(find.text('개인정보 처리방침'), findsOneWidget);
    for (var index = 0; index < 3; index++) {
      expect(
        find.byKey(ValueKey('signup-progress-segment-$index')),
        findsOneWidget,
      );
    }
    expect(gateway.termsRequestCount, 1);
    expect(gateway.signupRequestCount, 0);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('이름을 입력하세요'), findsOneWidget);
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField)).controller!.text,
      '홍길동',
    );
    await tester.tap(find.byTooltip('뒤로가기'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).first)
          .controller!
          .text,
      'Password!',
    );
    await tester.tap(find.byTooltip('뒤로가기'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField)).controller!.text,
      'parent@example.com',
    );
  });

  testWidgets('약관 시트의 가입 버튼을 누르면 확인 단계 없이 즉시 가입한다', (
    WidgetTester tester,
  ) async {
    final gateway = _FakeSignupGateway();
    await _reachTermsStep(tester, gateway);

    await tester.tap(find.text('가입'));
    await tester.pumpAndSettle();

    expect(gateway.signupRequestCount, 1);
    expect(find.byType(ParentShell), findsOneWidget);
  });

  testWidgets('가입 즉시 서버 버전 약관을 보내고 홈으로 이동한다', (WidgetTester tester) async {
    final gateway = _FakeSignupGateway();
    await _reachTermsStep(tester, gateway);

    await tester.tap(find.text('가입'));
    await tester.pumpAndSettle();

    expect(gateway.signupRequestCount, 1);
    expect(
      gateway.submittedAgreements
          .map((agreement) => '${agreement.type.apiValue}:${agreement.version}')
          .toList(),
      ['COOKIE:cookie-v2', 'TERMS:terms-v3', 'PRIVACY:privacy-v4'],
    );
    expect(find.byType(ParentShell), findsOneWidget);
  });

  testWidgets('409 응답이면 이메일 단계로 돌아가 이메일 오류를 표시한다', (WidgetTester tester) async {
    final gateway = _FakeSignupGateway()
      ..signupError = DioException(
        requestOptions: RequestOptions(path: '/auth/signup'),
        response: Response(
          requestOptions: RequestOptions(path: '/auth/signup'),
          statusCode: 409,
          data: {'detail': '이미 가입된 이메일입니다.'},
        ),
      );
    await _reachTermsStep(tester, gateway);

    await tester.tap(find.text('가입'));
    await tester.pumpAndSettle();

    expect(find.text('이메일을 입력하세요'), findsOneWidget);
    expect(find.text('이미 가입된 이메일입니다.'), findsOneWidget);
    expect(gateway.signupRequestCount, 1);
  });

  testWidgets('422 약관 오류는 최신 버전 갱신 후 약관 시트에 표시한다', (WidgetTester tester) async {
    final gateway = _FakeSignupGateway()
      ..signupError = DioException(
        requestOptions: RequestOptions(path: '/auth/signup'),
        response: Response(
          requestOptions: RequestOptions(path: '/auth/signup'),
          statusCode: 422,
          data: {'detail': '필수 약관에 모두 동의해야 가입할 수 있습니다'},
        ),
      );
    await _reachTermsStep(tester, gateway);

    await tester.tap(find.text('가입'));
    await tester.pumpAndSettle();

    expect(find.textContaining('필수 약관에 모두 동의해야 가입할 수 있습니다'), findsOneWidget);
    expect(gateway.termsRequestCount, 2);
    expect(find.text('약관에 동의하시겠습니까?'), findsNothing);
  });

  testWidgets('그 밖의 가입 실패는 오류를 시트에 표시하고 약관 화면에 머문다', (
    WidgetTester tester,
  ) async {
    final gateway = _FakeSignupGateway()
      ..signupError = DioException(
        requestOptions: RequestOptions(path: '/auth/signup'),
        response: Response(
          requestOptions: RequestOptions(path: '/auth/signup'),
          statusCode: 500,
          data: {'detail': 'server error'},
        ),
      );
    await _reachTermsStep(tester, gateway);

    await tester.tap(find.text('가입'));
    await tester.pumpAndSettle();

    expect(find.text('가입에 실패했습니다. 다시 시도해주세요'), findsOneWidget);
    expect(find.text('쿠키 사용'), findsOneWidget);
    expect(find.byType(ParentShell), findsNothing);
  });

  testWidgets('약관 목록과 전문은 각각 커스텀 시트로 열린다', (WidgetTester tester) async {
    final gateway = _FakeSignupGateway();
    await _reachTermsStep(tester, gateway);

    await tester.tap(find.text('이용약관').last);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('서비스 이용에 필요한 기본 사항과 회원 및 서비스 운영자의 권리와 의무를 정합니다.'),
      findsOneWidget,
    );
    expect(find.text('버전 terms-v3'), findsNWidgets(2));

    await tester.tap(find.byTooltip('약관 목록으로 돌아가기'));
    await tester.pumpAndSettle();
    expect(find.text('약관 목록으로 돌아가기'), findsNothing);
    expect(find.text('가입'), findsWidgets);
  });

  testWidgets('약관을 불러오지 못하면 가입을 막고 다시 시도할 수 있다', (WidgetTester tester) async {
    final gateway = _FakeSignupGateway()..termsError = true;
    await _reachNameStep(tester, gateway);
    await tester.tap(find.text('약관 확인'));
    await tester.pumpAndSettle();

    expect(find.text('약관을 불러오지 못했습니다'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '가입'))
          .onPressed,
      isNull,
    );

    gateway.termsError = false;
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(find.text('쿠키 사용'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '가입'))
          .onPressed,
      isNotNull,
    );
  });
}

Future<void> _reachNameStep(
  WidgetTester tester,
  _FakeSignupGateway gateway,
) async {
  await tester.pumpWidget(MaterialApp(home: SignupScreen(gateway: gateway)));
  await tester.enterText(
    find.byType(TextFormField).first,
    'parent@example.com',
  );
  await tester.pump();
  await tester.tap(find.text('다음'));
  await tester.pumpAndSettle();

  await tester.enterText(find.byType(TextFormField).first, 'Password!');
  await tester.pump();
  await tester.enterText(find.byType(TextFormField).last, 'Password!');
  await tester.pump();
  await tester.tap(find.text('다음'));
  await tester.pumpAndSettle();

  await tester.enterText(find.byType(TextFormField).first, '홍길동');
  await tester.pump();
}

Future<void> _reachTermsStep(
  WidgetTester tester,
  _FakeSignupGateway gateway,
) async {
  await _reachNameStep(tester, gateway);
  await tester.tap(find.text('약관 확인'));
  await tester.pumpAndSettle();
}

class _FakeSignupGateway implements SignupGateway {
  int termsRequestCount = 0;
  int signupRequestCount = 0;
  DioException? signupError;
  bool termsError = false;
  List<SignupTermAgreement> submittedAgreements = const [];

  @override
  Future<List<SignupTermInfo>> getSignupTerms() async {
    termsRequestCount++;
    if (termsError) throw StateError('offline');
    return const [
      SignupTermInfo(
        type: SignupTermType.cookie,
        title: '쿠키 사용',
        version: 'cookie-v2',
      ),
      SignupTermInfo(
        type: SignupTermType.termsOfService,
        title: '이용약관',
        version: 'terms-v3',
      ),
      SignupTermInfo(
        type: SignupTermType.privacyPolicy,
        title: '개인정보 처리방침',
        version: 'privacy-v4',
      ),
    ];
  }

  @override
  Future<void> signup({
    required String email,
    required String password,
    required String name,
    required List<SignupTermAgreement> agreements,
  }) async {
    signupRequestCount++;
    submittedAgreements = agreements;
    if (signupError != null) throw signupError!;
  }
}
