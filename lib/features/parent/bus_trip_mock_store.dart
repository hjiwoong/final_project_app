
import 'package:flutter/foundation.dart';

enum BusTripStatus {
  before,
  running,
  finished,
}

class BusTripMockStore {
  static final ValueNotifier<BusTripStatus> status =
  ValueNotifier<BusTripStatus>(BusTripStatus.running);

  // 0.0 = 출발지, 1.0 = 학교
  static final ValueNotifier<double> progress =
  ValueNotifier<double>(0.5);

  static String getStatusText(BusTripStatus value) {
    switch (value) {
      case BusTripStatus.before:
        return '운행 전';
      case BusTripStatus.running:
        return '운행 중';
      case BusTripStatus.finished:
        return '운행 종료';
    }
  }

  static String getEtaText(BusTripStatus value) {
    switch (value) {
      case BusTripStatus.before:
        return '운행 시작 전';
      case BusTripStatus.running:
        final minutes = (16 * (1 - progress.value)).ceil();
        return '약 $minutes분';
      case BusTripStatus.finished:
        return '운행 종료';
    }
  }

  static void startTrip() {
    progress.value = 0.0;
    status.value = BusTripStatus.running;
  }

  static void moveBus() {
    if (status.value != BusTripStatus.running) return;

    final next = progress.value + 0.25;
    progress.value = next >= 1.0 ? 1.0 : next;

    if (progress.value >= 1.0) {
      status.value = BusTripStatus.finished;
    }
  }

  static void finishTrip() {
    progress.value = 1.0;
    status.value = BusTripStatus.finished;
  }

  static void resetTrip() {
    progress.value = 0.0;
    status.value = BusTripStatus.before;
  }
}
