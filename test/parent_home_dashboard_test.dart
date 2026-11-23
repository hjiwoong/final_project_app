import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:final_project_app/core/network/api_client.dart';
import 'package:final_project_app/core/maps/naver_map_status.dart';
import 'package:final_project_app/features/parent/bus_status_screen.dart';
import 'package:final_project_app/features/parent/bus_trip_simulation.dart';
import 'package:final_project_app/features/parent/parent_home_screen.dart';
import 'package:final_project_app/features/parent/notification_settings_screen.dart';
import 'package:final_project_app/features/auth/login_screen.dart';
import 'package:final_project_app/features/parent/parent_attendance_screen.dart';
import 'package:final_project_app/features/parent/parent_shell.dart';
import 'package:final_project_app/features/parent/unread_notification_store.dart';
import 'package:final_project_app/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pumpNetwork(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  late DashboardAdapter adapter;

  setUp(() {
    adapter = DashboardAdapter();
    final dio = ApiClient.instance.dio;
    final original = dio.httpClientAdapter;
    final interceptors = dio.interceptors.toList();
    dio.interceptors.clear();
    dio.httpClientAdapter = adapter;
    UnreadNotificationStore.clear();
    naverMapAuthError.value = 'test';
    BusTripSimulation.resetTrip();
    addTearDown(() {
      dio.httpClientAdapter = original;
      dio.interceptors.addAll(interceptors);
      UnreadNotificationStore.clear();
      naverMapAuthError.value = null;
      BusTripSimulation.resetTrip();
    });
  });

  testWidgets('홈 데이터와 요청 수를 불러오고 결석을 변경하면 자녀만 다시 조회한다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ParentHomeScreen()));
    await pumpNetwork(tester);

    expect(adapter.calls.length, 5);
    expect(adapter.query['/me/alerts'], {'status': 'OPEN', 'limit': 1});
    expect(adapter.query['/me/notifications'], {
      'unread_only': true,
      'limit': 1,
    });
    final today = DateTime.now();
    final date =
        '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    expect(adapter.query['/me/children'], {'date': date});
    expect(find.text('확인이 필요한 알림 2건'), findsOneWidget);
    expect(find.text('최근 경고'), findsOneWidget);
    expect(find.text('운행 전'), findsOneWidget);
    expect(find.text('09:30 출발 예정'), findsOneWidget);
    expect(UnreadNotificationStore.unreadCount.value, 3);

    await tester.tap(find.text('오늘 결석 신청'));
    await tester.pumpAndSettle();
    expect(adapter.attendance, isNull);
    await tester.tap(find.text('확인'));
    await pumpNetwork(tester);
    expect(adapter.attendance, {'date': date, 'is_absent': true});
    expect(adapter.calls.where((path) => path == '/me/children').length, 2);
    expect(adapter.calls.where((path) => path == '/me/bus-status').length, 1);
    expect(find.text('결석'), findsOneWidget);
    expect(find.text('결석 취소'), findsOneWidget);
  });

  testWidgets('독립된 오류를 재시도해도 나머지 영역은 유지된다', (tester) async {
    adapter.failedPath = '/me/alerts';
    await tester.pumpWidget(const MaterialApp(home: ParentHomeScreen()));
    await pumpNetwork(tester);
    expect(find.textContaining('확인이 필요한 알림'), findsNothing);
    expect(find.text('09:30 출발 예정'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('자녀 연결 요청 승인 대기'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, 500));
    await tester.pumpAndSettle();
    adapter.failedPath = null;
    await tester.drag(find.byType(ListView).first, const Offset(0, 400));
    await pumpNetwork(tester);
    expect(find.text('확인이 필요한 알림 2건'), findsOneWidget);
  });

  testWidgets('운행 중에는 위치 버튼과 운행 상태를 표시한다', (tester) async {
    adapter.running = true;
    adapter.boarded = true;
    await tester.pumpWidget(const MaterialApp(home: ParentHomeScreen()));
    await pumpNetwork(tester);
    expect(find.text('운행 중'), findsNWidgets(2));
    expect(find.text('실시간 위치 보기'), findsOneWidget);
    expect(find.text('오늘 결석 신청'), findsNothing);
    await tester.tap(find.text('실시간 위치 보기'));
    await tester.pumpAndSettle();
    final screen = tester.widget<BusStatusScreen>(find.byType(BusStatusScreen));
    expect(screen.tripId, 12);
    expect(find.text('테스트 운행 시작'), findsOneWidget);
    expect(find.textContaining('시뮬레이션) 데이터입니다'), findsOneWidget);
  });

  testWidgets('빠른 메뉴에서 기존 테스트 운행 화면을 연다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ParentHomeScreen()));
    await pumpNetwork(tester);
    await tester.ensureVisible(find.text('버스 위치'));
    await tester.tap(find.text('버스 위치'));
    await pumpNetwork(tester);
    expect(find.byType(BusStatusScreen), findsOneWidget);
    expect(find.text('테스트 운행 시작'), findsOneWidget);
    await tester.drag(find.byType(ListView).last, const Offset(0, -450));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('테스트 운행 시작'));
    await tester.tap(find.text('테스트 운행 시작'));
    await tester.pumpAndSettle();
    expect(BusTripSimulation.status.value, BusTripStatus.running);
    await tester.ensureVisible(find.text('버스 위치 이동'));
    await tester.tap(find.text('버스 위치 이동'));
    await tester.pumpAndSettle();
    expect(BusTripSimulation.progress.value, 0.25);
    await tester.ensureVisible(find.text('테스트 운행 종료'));
    await tester.tap(find.text('테스트 운행 종료'));
    await tester.pumpAndSettle();
    expect(BusTripSimulation.status.value, BusTripStatus.finished);
    await tester.ensureVisible(find.text('테스트 운행 초기화'));
    await tester.tap(find.text('테스트 운행 초기화'));
    await tester.pumpAndSettle();
    expect(BusTripSimulation.status.value, BusTripStatus.before);
  });

  testWidgets('새로고침은 모든 영역을 다시 조회한다', (tester) async {
    adapter.running = true;
    adapter.boarded = true;
    adapter.alighted = true;
    await tester.pumpWidget(const MaterialApp(home: ParentHomeScreen()));
    await pumpNetwork(tester);
    expect(find.text('운행 중'), findsNWidgets(2));
    expect(find.text('승차 중'), findsNothing);
    await tester.drag(find.byType(ListView).first, const Offset(0, 400));
    await pumpNetwork(tester);
    expect(adapter.calls.where((path) => path == '/me/children').length, 2);
    expect(adapter.calls.where((path) => path == '/me/bus-status').length, 2);
    expect(adapter.calls.where((path) => path == '/me/alerts').length, 2);
    expect(
      adapter.calls.where((path) => path == '/me/notifications').length,
      2,
    );
    expect(
      adapter.calls.where((path) => path == '/me/child-requests').length,
      2,
    );
  });

  testWidgets('결석은 종료와 승하차 상태보다 우선한다', (tester) async {
    adapter.closed = true;
    adapter.running = true;
    adapter.boarded = true;
    adapter.alighted = true;
    adapter.absent = true;
    await tester.pumpWidget(const MaterialApp(home: ParentHomeScreen()));
    await pumpNetwork(tester);
    expect(find.text('결석'), findsOneWidget);
    expect(find.text('실시간 위치 보기'), findsNothing);
    expect(find.text('오늘 결석 신청'), findsNothing);
    expect(find.text('결석 취소'), findsOneWidget);
  });

  testWidgets('출발 시각은 일치하는 버스에서만 가져오고 없으면 운행 전만 표시한다', (tester) async {
    adapter.scheduledAt = null;
    await tester.pumpWidget(const MaterialApp(home: ParentHomeScreen()));
    await pumpNetwork(tester);
    expect(find.text('운행 전'), findsOneWidget);

    adapter.scheduledAt = '2026-11-19T13:45:00';
    adapter.busId = 999;
    await tester.drag(find.byType(ListView).first, const Offset(0, 400));
    await pumpNetwork(tester);
    expect(find.text('운행 전'), findsOneWidget);
    expect(find.text('13:45 출발 예정'), findsNothing);
  });

  testWidgets('두 번째 출결 관리 탭에서 기존 화면을 열고 다시 돌아오면 정보를 갱신한다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ParentShell()));
    await pumpNetwork(tester);
    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    final destinations = bar.destinations.cast<NavigationDestination>();
    expect(destinations.map((destination) => destination.label).toList(), [
      '홈',
      '출결 관리',
      'AI 채팅',
      '알림',
      '설정',
    ]);
    expect(find.byType(ParentAttendanceScreen), findsNothing);
    await tester.tap(find.text('출결 관리'));
    await pumpNetwork(tester);
    expect(find.byType(ParentAttendanceScreen), findsOneWidget);
    expect(find.text('출석·결석 관리'), findsOneWidget);
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      false,
    );

    await tester.tap(find.text('홈').last);
    await pumpNetwork(tester);
    await tester.tap(find.text('오늘 결석 신청'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('확인'));
    await pumpNetwork(tester);
    await tester.tap(find.text('출결 관리'));
    await pumpNetwork(tester);
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      true,
    );
  });

  testWidgets('결석 확인을 취소하면 저장하지 않는다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ParentHomeScreen()));
    await pumpNetwork(tester);
    await tester.tap(find.text('오늘 결석 신청'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(adapter.attendance, isNull);
    expect(find.text('오늘 결석 신청'), findsOneWidget);
  });

  testWidgets('자녀가 없으면 연결 요청 카드가 표시된다', (tester) async {
    adapter.noChildren = true;
    await tester.pumpWidget(const MaterialApp(home: ParentHomeScreen()));
    await pumpNetwork(tester);
    expect(find.text('자녀를 연결해 주세요'), findsOneWidget);
    expect(find.text('자녀 연결 요청'), findsOneWidget);
  });

  testWidgets('하차 완료 시 운행 상태를 표시하고 버튼을 숨긴다', (tester) async {
    adapter.running = true;
    adapter.boarded = true;
    adapter.alighted = true;
    await tester.pumpWidget(const MaterialApp(home: ParentHomeScreen()));
    await pumpNetwork(tester);
    expect(find.text('운행 중'), findsNWidgets(2));
    expect(find.text('실시간 위치 보기'), findsNothing);
    expect(find.text('오늘 결석 신청'), findsNothing);
  });

  testWidgets('운행 정보가 실패해도 자녀 카드는 표시하고 출발 시간은 숨긴다', (tester) async {
    adapter.failedPath = '/me/bus-status';
    await tester.pumpWidget(const MaterialApp(home: ParentHomeScreen()));
    await pumpNetwork(tester);
    expect(find.textContaining('버스 운행 정보\n불러오지 못했어요'), findsNothing);
    expect(find.text('하늘'), findsOneWidget);
    expect(find.text('운행 전'), findsOneWidget);
    expect(find.text('09:30 출발 예정'), findsNothing);
    adapter.failedPath = null;
    await tester.drag(find.byType(ListView).first, const Offset(0, 400));
    await pumpNetwork(tester);
    expect(find.text('09:30 출발 예정'), findsOneWidget);
  });

  testWidgets('운행 정보 인증 오류도 홈과 자녀 카드를 유지한다', (tester) async {
    adapter.failedPath = '/me/bus-status';
    adapter.failureStatus = 401;
    await tester.pumpWidget(const MaterialApp(home: ParentHomeScreen()));
    await pumpNetwork(tester);
    expect(find.byType(ParentHomeScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
    expect(find.text('하늘'), findsOneWidget);
    expect(find.text('09:30 출발 예정'), findsNothing);
  });

  testWidgets('상태 칩은 내용 크기와 지정된 색상을 사용한다', (tester) async {
    final cases = [
      ('NOT_STARTED', false, '운행 전', AppColors.info, AppColors.textPrimary),
      ('IN_PROGRESS', false, '운행 중', AppColors.primary, AppColors.textPrimary),
      (
        'CLOSED',
        false,
        '운행 종료',
        AppColors.success.withValues(alpha: 0.12),
        AppColors.success,
      ),
      (
        'NOT_ASSIGNED',
        false,
        '배정 없음',
        AppColors.border,
        AppColors.textSecondary,
      ),
      (
        'CLOSED',
        true,
        '결석',
        AppColors.danger.withValues(alpha: 0.1),
        AppColors.danger,
      ),
    ];
    for (final (busStatus, absent, label, background, foreground) in cases) {
      adapter.busStatus = busStatus;
      adapter.absent = absent;
      await tester.pumpWidget(
        MaterialApp(home: ParentHomeScreen(key: ValueKey('$busStatus$absent'))),
      );
      await pumpNetwork(tester);
      final text = tester.widget<Text>(find.text(label).first);
      expect(text.style!.color, foreground);
      expect(text.style!.fontSize, 12);
      expect(text.style!.fontWeight, FontWeight.w600);
      final chip = find
          .ancestor(
            of: find.text(label).first,
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Container &&
                  widget.decoration is BoxDecoration &&
                  (widget.decoration! as BoxDecoration).color == background,
            ),
          )
          .first;
      expect(tester.getSize(chip).height, 28);
      expect(tester.getSize(chip).width, lessThan(120));
      expect(
        tester.widget<Container>(chip).padding,
        const EdgeInsets.symmetric(horizontal: 10),
      );
      if (busStatus == 'CLOSED') {
        expect(find.text('09:30 출발 예정'), findsNothing);
      }
    }
  });

  testWidgets('출발 시간은 운행 ID를 우선하고 일치하지 않으면 버스 ID로 찾는다', (tester) async {
    adapter.childTripId = 12;
    adapter.busTripId = 13;
    await tester.pumpWidget(const MaterialApp(home: ParentHomeScreen()));
    await pumpNetwork(tester);
    expect(find.text('09:30 출발 예정'), findsOneWidget);

    adapter.busTripId = 12;
    adapter.busId = 999;
    adapter.scheduledAt = '2026-11-19T13:45:00Z';
    await tester.drag(find.byType(ListView).first, const Offset(0, 400));
    await pumpNetwork(tester);
    final local = DateTime.parse(adapter.scheduledAt!).toLocal();
    final expected =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')} 출발 예정';
    expect(find.text(expected), findsOneWidget);
  });

  testWidgets('버스 ID가 먼저 일치해도 운행 ID가 일치하는 항목을 우선한다', (tester) async {
    adapter.childTripId = 12;
    adapter.busEntries = [
      {
        'bus_id': 7,
        'trip_id': 13,
        'status': 'NOT_RUNNING',
        'scheduled_at': '2026-11-19T08:00:00',
      },
      {
        'bus_id': 8,
        'trip_id': 12,
        'status': 'NOT_RUNNING',
        'scheduled_at': '2026-11-19T09:30:00',
      },
    ];
    await tester.pumpWidget(const MaterialApp(home: ParentHomeScreen()));
    await pumpNetwork(tester);
    expect(find.text('08:00 출발 예정'), findsNothing);
    expect(find.text('09:30 출발 예정'), findsOneWidget);
    expect(tester.widget<Icon>(find.byIcon(Icons.access_time)).size, 14);
    final time = tester.widget<Text>(find.text('09:30 출발 예정'));
    expect(time.style!.fontSize, 12);
    expect(time.style!.color, AppColors.textSecondary);
  });

  testWidgets('알림 인증 오류도 홈을 유지하고 배너만 숨긴다', (tester) async {
    adapter.failedPath = '/me/alerts';
    adapter.failureStatus = 401;
    await tester.pumpWidget(const MaterialApp(home: ParentHomeScreen()));
    await pumpNetwork(tester);
    expect(find.byType(ParentHomeScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
    expect(find.textContaining('확인이 필요한 알림'), findsNothing);
    expect(find.text('하늘'), findsOneWidget);
  });

  testWidgets('알림 배너를 누르면 알림 탭의 긴급 필터를 선택한다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ParentShell()));
    await pumpNetwork(tester);
    await tester.tap(find.text('확인이 필요한 알림 2건'));
    await pumpNetwork(tester);
    expect(
      tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '긴급')).selected,
      isTrue,
    );
    expect(adapter.query['/me/notifications'], {'category': 'URGENT'});
    await tester.tap(find.text('전체'));
    await pumpNetwork(tester);
    await tester.tap(find.text('홈').last);
    await pumpNetwork(tester);
    await tester.tap(find.text('확인이 필요한 알림 2건'));
    await pumpNetwork(tester);
    expect(
      tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '긴급')).selected,
      isTrue,
    );
    expect(adapter.query['/me/notifications'], {'category': 'URGENT'});
  });

  testWidgets('알림이 없으면 배너를 표시하지 않는다', (tester) async {
    adapter.alertTotal = 0;
    await tester.pumpWidget(const MaterialApp(home: ParentHomeScreen()));
    await pumpNetwork(tester);
    expect(find.textContaining('확인이 필요한 알림'), findsNothing);
    expect(find.text('오늘의 자녀'), findsOneWidget);
  });

  testWidgets('자녀 조회 실패는 재시도 버튼을 표시한다', (tester) async {
    adapter.failedPath = '/me/children';
    await tester.pumpWidget(const MaterialApp(home: ParentHomeScreen()));
    await pumpNetwork(tester);
    expect(find.text('정보를 불러오지 못했어요'), findsOneWidget);
    adapter.failedPath = null;
    await tester.tap(find.text('다시 시도'));
    await pumpNetwork(tester);
    expect(find.text('하늘'), findsOneWidget);
  });

  testWidgets('결석 버튼의 크기와 스타일을 상태에 맞게 표시한다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ParentHomeScreen()));
    await pumpNetwork(tester);
    var finder = find.widgetWithText(FilledButton, '오늘 결석 신청');
    var button = tester.widget<FilledButton>(finder);
    expect(tester.getSize(finder).height, 52);
    expect(button.style!.backgroundColor!.resolve({}), AppColors.primary);
    expect(button.style!.foregroundColor!.resolve({}), AppColors.textPrimary);
    expect(button.style!.textStyle!.resolve({})!.fontSize, 15);
    expect(button.style!.textStyle!.resolve({})!.fontWeight, FontWeight.w600);
    adapter.absent = true;
    await tester.drag(find.byType(ListView).first, const Offset(0, 400));
    await pumpNetwork(tester);
    finder = find.widgetWithText(FilledButton, '결석 취소');
    button = tester.widget<FilledButton>(finder);
    expect(tester.getSize(finder).height, 52);
    expect(button.style!.backgroundColor!.resolve({}), AppColors.surface);
    final shape = button.style!.shape!.resolve({})! as RoundedRectangleBorder;
    expect(shape.borderRadius, BorderRadius.circular(16));
    expect(
      shape.side,
      const BorderSide(color: AppColors.primaryDark, width: 1.5),
    );
  });

  testWidgets('빠른 메뉴의 알림 설정은 기존 화면을 연다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ParentHomeScreen()));
    await pumpNetwork(tester);
    expect(find.text('결석·일정'), findsNothing);
    await tester.ensureVisible(find.text('알림 설정'));
    expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);
    await tester.tap(find.text('알림 설정'));
    await tester.pumpAndSettle();
    expect(find.byType(NotificationSettingsScreen), findsOneWidget);
  });

  testWidgets('선택 탭과 읽지 않은 알림 점에 지정 색상을 사용한다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ParentShell()));
    await pumpNetwork(tester);
    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    final destinations = bar.destinations.cast<NavigationDestination>();
    final selected = destinations.first.selectedIcon as Container;
    final decoration = selected.decoration! as BoxDecoration;
    expect(decoration.color, AppColors.primary);
    expect(selected.constraints!.maxWidth, 52);
    expect(selected.constraints!.maxHeight, 30);
    final badge = tester.widget<Badge>(find.byType(Badge));
    expect(badge.isLabelVisible, isTrue);
    expect(badge.backgroundColor, AppColors.danger);
  });

  testWidgets('큰 시스템 글자에서도 홈과 메뉴가 넘치지 않는다', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: const ParentHomeScreen(),
      ),
    );
    await pumpNetwork(tester);
    await tester.drag(find.byType(ListView).first, const Offset(0, -600));
    await tester.pump();
  });

  testWidgets('운행 ID가 없으면 이동을 막고 다시 시도를 표시한다', (tester) async {
    adapter.running = true;
    adapter.noTripId = true;
    await tester.pumpWidget(const MaterialApp(home: ParentHomeScreen()));
    await pumpNetwork(tester);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '실시간 위치 보기'),
    );
    expect(button.onPressed, isNull);
    expect(find.text('운행 정보를 불러오지 못했어요 · 다시 시도'), findsOneWidget);
  });

  testWidgets('큰 시스템 글자에서도 하단 탭이 넘치지 않는다', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: const ParentShell(),
      ),
    );
    await pumpNetwork(tester);
  });
}

class DashboardAdapter implements HttpClientAdapter {
  final List<String> calls = [];
  final Map<String, Map<String, dynamic>> query = {};
  Map<String, dynamic>? attendance;
  String? failedPath;
  int failureStatus = 500;
  bool absent = false;
  bool running = false;
  bool closed = false;
  bool boarded = false;
  bool alighted = false;
  bool noChildren = false;
  bool noTripId = false;
  String? busStatus;
  int? childTripId;
  int? busTripId;
  int busId = 7;
  int alertTotal = 2;
  List<Map<String, dynamic>>? busEntries;
  String? scheduledAt = '2026-11-19T09:30:00';

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls.add(options.path);
    query[options.path] = Map<String, dynamic>.from(options.queryParameters);
    if (failedPath == options.path) {
      return response({'detail': 'failed'}, failureStatus);
    }
    switch (options.path) {
      case '/me/children':
        if (noChildren) return response([]);
        return response([
          {
            'id': 1,
            'name': '하늘',
            'bus_id': 7,
            'bus_name': '1호차',
            'bus_status':
                busStatus ??
                (closed ? 'CLOSED' : (running ? 'IN_PROGRESS' : 'NOT_STARTED')),
            'trip_id': childTripId ?? (running && !noTripId ? 12 : null),
            'is_absent': absent,
            'boarding_confirmed_at': boarded ? '2026-11-19T09:00:00' : null,
            'alighting_confirmed_at': alighted ? '2026-11-19T09:30:00' : null,
          },
        ]);
      case '/me/bus-status':
        return response(
          busEntries ??
              [
                {
                  'bus_id': busId,
                  'bus_name': '1호차',
                  'status': running ? 'IN_PROGRESS' : 'NOT_RUNNING',
                  'trip_id': busTripId ?? (running && !noTripId ? 12 : null),
                  'scheduled_at': scheduledAt,
                },
              ],
        );
      case '/me/alerts':
        return response({
          'items': alertTotal == 0
              ? []
              : [
                  {'title': '최근 경고'},
                ],
          'total': alertTotal,
        });
      case '/me/notifications':
        return response({'items': [], 'total': 3, 'unread_count': 3});
      case '/me/child-requests':
        return response([
          {'id': 8, 'child_name': '다른 자녀', 'status': 'PENDING'},
        ]);
      case '/me/children/1/attendance':
        attendance = Map<String, dynamic>.from(options.data as Map);
        absent = attendance!['is_absent'] as bool;
        return response({});
      default:
        return response({'detail': 'unexpected'}, 404);
    }
  }

  ResponseBody response(Object data, [int status = 200]) =>
      ResponseBody.fromString(
        jsonEncode(data),
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

  @override
  void close({bool force = false}) {}
}
