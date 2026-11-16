import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:final_project_app/features/driver/widgets/driver_home_cards.dart';

void main() {
  group('기사 홈 주요 카드 상태', () {
    test('진행 중 운행이 있으면 진행 중 카드 상태를 선택한다', () {
      expect(
        resolveHomeTopCardState(hasActiveTrip: true, hasAssignedBuses: true),
        HomeTopCardState.activeTrip,
      );
    });

    test('진행 중 운행은 없고 배정 버스가 있으면 다음 운행 상태를 선택한다', () {
      expect(
        resolveHomeTopCardState(hasActiveTrip: false, hasAssignedBuses: true),
        HomeTopCardState.nextTrip,
      );
    });

    test('진행 중 운행과 배정 버스가 모두 없으면 빈 상태를 선택한다', () {
      expect(
        resolveHomeTopCardState(hasActiveTrip: false, hasAssignedBuses: false),
        HomeTopCardState.empty,
      );
    });
  });

  testWidgets('다음 운행 미리보기에 출발 정보와 시작 버튼을 표시한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NextTripCard(
            departureTime: '08:10',
            busName: '1호차',
            routeName: '학교 → 종점',
            onStart: () {},
          ),
        ),
      ),
    );

    expect(find.text('다음 운행'), findsOneWidget);
    expect(find.text('08:10 출발 · 1호차'), findsOneWidget);
    expect(find.text('학교 → 종점'), findsOneWidget);
    expect(find.text('운행 시작'), findsOneWidget);
  });

  testWidgets('진행 중 운행 미리보기에 재개와 종료 동작을 표시한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ActiveTripCard(
            title: '1호차 · 12가3456',
            elapsedTime: '15분',
            boardingCount: 0,
            studentCount: 1,
            onResume: () {},
            onEnd: () {},
          ),
        ),
      ),
    );

    expect(find.text('진행 중인 운행'), findsOneWidget);
    expect(find.text('1호차 · 12가3456'), findsOneWidget);
    expect(find.text('운행 시작 후 15분 · 탑승 0/1명'), findsOneWidget);
    expect(find.text('운행 재개'), findsOneWidget);
    expect(find.text('운행 종료'), findsOneWidget);
  });

  testWidgets('빈 상태 카드는 안전 운행 안내만 표시한다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: EmptyStateCard())),
    );

    expect(find.text('안전한 운행을 시작하세요'), findsOneWidget);
    expect(find.text('버스를 배정받으면 아래에 목록이 표시됩니다.'), findsOneWidget);
    expect(find.text('진행 중인 운행'), findsNothing);
    expect(find.text('다음 운행'), findsNothing);
  });

  testWidgets('배정 버스 카드에 출발 시각과 운행 중 배지를 표시하고 탭을 전달한다', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AssignedBusCard(
            busName: '1호차',
            busNumber: '12가3456',
            departureLabel: '08:10 출발',
            routeName: '학교 → 종점',
            studentCount: 1,
            isActive: true,
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('08:10 출발'), findsOneWidget);
    expect(find.text('운행 중'), findsOneWidget);
    expect(find.text('학교 → 종점'), findsOneWidget);
    await tester.tap(find.text('12가3456'));
    expect(tapped, isTrue);
  });
}
