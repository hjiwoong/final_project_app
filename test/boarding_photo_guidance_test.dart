import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:final_project_app/core/auth/session.dart';
import 'package:final_project_app/data/models/trip_progress.dart';
import 'package:final_project_app/features/driver/boarding_capture_screen.dart';

void main() {
  const guidance = '사진이 어두워 다시 촬영해 주세요.';
  const progress = TripProgress(
    tripId: 1,
    busId: 2,
    busName: '버스',
    busNumber: '1',
    isMock: false,
    currentStopIndex: 0,
    boardingCount: 3,
    boardingPhotoGuidance: guidance,
  );

  tearDown(() {
    Session.currentBoardingCount = null;
  });

  test('사진 안내가 운행 정보에 저장되고 재촬영 시 삭제된다', () {
    final restored = TripProgress.fromJson(progress.toJson());
    expect(restored.boardingPhotoGuidance, guidance);
    expect(
      restored.copyWith(currentStopIndex: 1).boardingPhotoGuidance,
      guidance,
    );
    expect(
      restored.copyWith(clearBoardingCount: true).boardingPhotoGuidance,
      isNull,
    );
    expect(
      restored.copyWith(clearBoardingPhotoGuidance: true).boardingPhotoGuidance,
      isNull,
    );
    final legacy = Map<String, dynamic>.from(progress.toJson())
      ..remove('boarding_photo_guidance');
    expect(TripProgress.fromJson(legacy).boardingPhotoGuidance, isNull);
  });

  testWidgets('복구된 사진 안내를 탑승 인원 아래에 표시한다', (tester) async {
    Session.currentBoardingCount = 3;
    await tester.pumpWidget(
      const MaterialApp(
        home: BoardingCaptureScreen(initialPhotoGuidance: guidance),
      ),
    );

    expect(find.text('총 탑승 인원: 3명'), findsOneWidget);
    expect(find.text(guidance), findsOneWidget);
    expect(
      tester.getTopLeft(find.text(guidance)).dy,
      greaterThan(tester.getTopLeft(find.text('총 탑승 인원: 3명')).dy),
    );
  });

  testWidgets('사진 안내가 없으면 경고를 표시하지 않는다', (tester) async {
    Session.currentBoardingCount = 3;
    await tester.pumpWidget(const MaterialApp(home: BoardingCaptureScreen()));

    expect(find.text('총 탑승 인원: 3명'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
  });
}
