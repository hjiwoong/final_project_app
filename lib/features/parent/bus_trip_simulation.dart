import 'package:flutter/foundation.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

enum BusTripStatus { before, running, finished }

/// 버스 위치 '테스트 운행'(시뮬레이션).
///
/// 서버에 버스 실시간 GPS 데이터가 없어서, 학부모 앱의 버스 위치·도착 예정 시간은
/// 이 시뮬레이션으로 보여 준다. 실제 운행 상태(운행 중/완료)는 서버 값을 따로 표시한다.
class BusTripSimulation {
  BusTripSimulation._();

  /// 테스트 운행 경로 (출발지 → 학교)
  static const List<NLatLng> route = [
    NLatLng(37.5547, 126.9707), // 출발지
    NLatLng(37.5598, 126.9753),
    NLatLng(37.5640, 126.9770),
    NLatLng(37.5663, 126.9784), // 학교
  ];

  /// 출발지에서 학교까지 걸리는 시간(분)
  static const int totalMinutes = 16;

  static final ValueNotifier<BusTripStatus> status =
      ValueNotifier<BusTripStatus>(BusTripStatus.before);

  // 0.0 = 출발지, 1.0 = 학교
  static final ValueNotifier<double> progress = ValueNotifier<double>(0.0);

  static DateTime? startedAt;

  static String statusText(BusTripStatus value) => switch (value) {
    BusTripStatus.before => '운행 전',
    BusTripStatus.running => '운행 중',
    BusTripStatus.finished => '운행 종료',
  };

  static String etaText(BusTripStatus value) => switch (value) {
    BusTripStatus.before => '운행 시작 전',
    BusTripStatus.running =>
      '약 ${(totalMinutes * (1 - progress.value)).ceil()}분',
    BusTripStatus.finished => '도착 완료',
  };

  /// 진행률에 해당하는 버스 좌표 (경로 위 선형 보간)
  static NLatLng busPosition([double? value]) {
    final p = (value ?? progress.value).clamp(0.0, 1.0).toDouble();
    final scaled = p * (route.length - 1);
    final index = scaled.floor();
    if (index >= route.length - 1) return route.last;
    final ratio = scaled - index;
    final start = route[index];
    final end = route[index + 1];
    return NLatLng(
      start.latitude + (end.latitude - start.latitude) * ratio,
      start.longitude + (end.longitude - start.longitude) * ratio,
    );
  }

  static void startTrip() {
    progress.value = 0.0;
    startedAt = DateTime.now();
    status.value = BusTripStatus.running;
  }

  static void moveBus() {
    if (status.value != BusTripStatus.running) return;
    final next = progress.value + 0.25;
    progress.value = next >= 1.0 ? 1.0 : next;
    if (progress.value >= 1.0) status.value = BusTripStatus.finished;
  }

  static void finishTrip() {
    progress.value = 1.0;
    status.value = BusTripStatus.finished;
  }

  static void resetTrip() {
    progress.value = 0.0;
    startedAt = null;
    status.value = BusTripStatus.before;
  }
}
