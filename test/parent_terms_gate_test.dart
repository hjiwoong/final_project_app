import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:final_project_app/core/auth/session.dart';
import 'package:final_project_app/core/network/api_client.dart';
import 'package:final_project_app/data/api/api_repository.dart';
import 'package:final_project_app/data/models/signup_term.dart';
import 'package:final_project_app/features/auth/parent_terms_gate.dart';

void main() {
  testWidgets('pending 약관이 있으면 동의 전 홈을 가리고 pending 항목만 전송한다', (tester) async {
    final pending = _agreements();
    final gateway = FakeTermsGateway()
      ..pending = pending
      ..history = _agreements(version: 'old');
    Session.pendingTerms = pending;

    await tester.pumpWidget(_app(gateway));
    await tester.pumpAndSettle();

    expect(find.text('약관이 변경되어 다시 동의가 필요해요.'), findsOneWidget);
    expect(find.text('홈 화면'), findsNothing);
    expect(find.text('(필수) 쿠키 사용'), findsOneWidget);
    expect(find.text('2026.11.18 시행'), findsNWidgets(3));
    expect(find.text('변경됨'), findsNWidgets(3));

    await tester.tap(find.text('동의하고 계속하기'));
    await tester.pumpAndSettle();

    expect(find.text('홈 화면'), findsOneWidget);
    expect(gateway.saved.map((item) => item.toJson()), [
      {'term_type': 'COOKIE', 'term_version': '2026-11-18'},
      {'term_type': 'TERMS', 'term_version': '2026-11-18'},
      {'term_type': 'PRIVACY', 'term_version': '2026-11-18'},
    ]);
  });

  testWidgets('pending 약관이 없으면 홈으로 바로 이동하고 약관 API를 호출하지 않는다', (tester) async {
    final gateway = FakeTermsGateway();
    Session.pendingTerms = const [];

    await tester.pumpWidget(_app(gateway));
    await tester.pumpAndSettle();

    expect(find.text('홈 화면'), findsOneWidget);
    expect(find.text('동의하고 계속하기'), findsNothing);
    expect(gateway.loads, 0);
    expect(gateway.pendingLoads, 0);
  });

  testWidgets('약관 전문을 열어 본 항목은 체크 아이콘으로 표시한다', (tester) async {
    Session.pendingTerms = _agreements();
    await tester.pumpWidget(_app(FakeTermsGateway()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('(필수) 이용약관'));
    await tester.pumpAndSettle();
    expect(find.text('약관 목록으로 돌아가기'), findsOneWidget);
    expect(find.textContaining('본 약관은 서비스 이용에 필요한 기본 사항'), findsOneWidget);

    await tester.tap(find.byTooltip('약관 목록으로 돌아가기'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.ancestor(
          of: find.text('(필수) 이용약관'),
          matching: find.byType(ListTile),
        ),
        matching: find.byIcon(Icons.check_rounded),
      ),
      findsOneWidget,
    );
  });

  testWidgets('403 TERMS_REQUIRED는 한 번 시트를 띄운 뒤 실패한 요청을 한 번 재시도한다', (
    tester,
  ) async {
    final gateway = FakeTermsGateway()..pending = _agreements();
    Session.pendingTerms = const [];
    final dio = ApiClient.instance.dio;
    final originalAdapter = dio.httpClientAdapter;
    final adapter = TermsRequiredAdapter(failures: 2);
    dio.httpClientAdapter = adapter;
    addTearDown(() => dio.httpClientAdapter = originalAdapter);

    await tester.pumpWidget(_app(gateway));
    await tester.pumpAndSettle();
    final request = dio.get(
      '/protected',
      options: Options(extra: const {'skipAuth': true}),
    );
    final secondRequest = dio.get(
      '/also-protected',
      options: Options(extra: const {'skipAuth': true}),
    );
    await tester.pumpAndSettle();
    expect(find.text('약관 확인'), findsOneWidget);
    expect(gateway.pendingLoads, 1);

    await tester.tap(find.text('동의하고 계속하기'));
    await tester.pumpAndSettle();
    await Future.wait([request, secondRequest]);

    expect(adapter.calls, 4);
    expect(find.text('홈 화면'), findsOneWidget);
    expect(gateway.saved, hasLength(3));
  });

  testWidgets('422이면 GET /me와 GET /terms를 다시 호출하고 갱신 안내를 표시한다', (tester) async {
    final gateway = FakeTermsGateway()
      ..pending = _agreements()
      ..pendingAfterConflict = _agreements(version: '2027-01-01')
      ..staleOnSave = true;
    Session.pendingTerms = _agreements();

    await tester.pumpWidget(_app(gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.text('동의하고 계속하기'));
    await tester.pumpAndSettle();

    expect(gateway.pendingLoads, 1);
    expect(gateway.loads, 2);
    expect(find.text('약관이 다시 변경되었습니다'), findsOneWidget);
    expect(find.text('2027.01.01 시행'), findsNWidgets(3));
    expect(find.text('홈 화면'), findsNothing);
  });

  testWidgets('동의하지 않고 로그아웃은 확인 후 기존 로그아웃 처리를 호출한다', (tester) async {
    var loggedOut = false;
    Session.pendingTerms = _agreements();
    await tester.pumpWidget(
      _app(FakeTermsGateway(), onLogout: () async => loggedOut = true),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('동의하지 않고 로그아웃'));
    await tester.pumpAndSettle();
    expect(find.text('로그아웃하시겠습니까?'), findsOneWidget);
    expect(loggedOut, isFalse);

    await tester.tap(find.text('로그아웃').last);
    await tester.pumpAndSettle();
    expect(loggedOut, isTrue);
  });
}

Widget _app(FakeTermsGateway gateway, {Future<void> Function()? onLogout}) =>
    MaterialApp(
      home: ParentTermsGate(
        gateway: gateway,
        onLogout: onLogout ?? () async {},
        child: const Scaffold(body: Text('홈 화면')),
      ),
    );

List<SignupTermAgreement> _agreements({String version = '2026-11-18'}) =>
    SignupTermType.values
        .map((type) => SignupTermAgreement(type: type, version: version))
        .toList();

class FakeTermsGateway implements TermsGateway {
  List<SignupTermAgreement> history = [];
  List<SignupTermAgreement> pending = [];
  List<SignupTermAgreement> pendingAfterConflict = [];
  List<SignupTermAgreement> saved = [];
  bool failLoad = false;
  bool staleOnSave = false;
  int loads = 0;
  int pendingLoads = 0;

  @override
  Future<List<SignupTermInfo>> getSignupTerms() async {
    loads++;
    if (failLoad) throw Exception('network');
    final version = pendingAfterConflict.isNotEmpty
        ? pendingAfterConflict.first.version
        : '2026-11-18';
    return SignupTermType.values
        .map(
          (type) => SignupTermInfo(
            type: type,
            title: type.title,
            version: version,
            required: true,
          ),
        )
        .toList();
  }

  @override
  Future<List<SignupTermAgreement>> getMyAgreements() async => history;

  @override
  Future<List<SignupTermAgreement>> getPendingTerms() async {
    pendingLoads++;
    pending = pendingAfterConflict.isNotEmpty ? pendingAfterConflict : pending;
    Session.pendingTerms = pending;
    return pending;
  }

  @override
  Future<void> saveAgreements(List<SignupTermAgreement> agreements) async {
    if (staleOnSave) {
      final request = RequestOptions(path: '/me/agreements');
      throw DioException(
        requestOptions: request,
        response: Response(requestOptions: request, statusCode: 422),
      );
    }
    saved = agreements;
  }
}

class TermsRequiredAdapter implements HttpClientAdapter {
  TermsRequiredAdapter({this.failures = 1});

  final int failures;
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    if (calls <= failures) {
      return ResponseBody.fromString(
        jsonEncode({'detail': 'TERMS_REQUIRED'}),
        403,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    return ResponseBody.fromString(
      jsonEncode({'ok': true}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
