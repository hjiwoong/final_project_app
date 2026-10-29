
import 'package:flutter/foundation.dart';

enum ChildBoardingStatus {
  waiting,
  boarded,
  droppedOff,
}

enum SafetyEventType {
  suddenBrake,
  speeding,
  routeDeviation,
}

class ParentMockEvent {
  final int id;
  final String title;
  final String message;
  final String time;
  final bool isAlert;

  const ParentMockEvent({
    required this.id,
    required this.title,
    required this.message,
    required this.time,
    required this.isAlert,
  });
}

class ParentEventMockStore {
  static int _nextId = 1;

  static final ValueNotifier<Map<String, ChildBoardingStatus>>
  childStatuses =
  ValueNotifier<Map<String, ChildBoardingStatus>>({
    '김하늘': ChildBoardingStatus.droppedOff,
    '이도윤': ChildBoardingStatus.boarded,
  });

  static final ValueNotifier<List<ParentMockEvent>> events =
  ValueNotifier<List<ParentMockEvent>>([]);

  static final ValueNotifier<Set<int>> readEventIds =
  ValueNotifier<Set<int>>(<int>{});

  static final ValueNotifier<Map<SafetyEventType, int>>
  safetyCounts =
  ValueNotifier<Map<SafetyEventType, int>>({
    SafetyEventType.suddenBrake: 1,
    SafetyEventType.speeding: 0,
    SafetyEventType.routeDeviation: 0,
  });

  static String getChildStatusText(
      ChildBoardingStatus status,
      ) {
    switch (status) {
      case ChildBoardingStatus.waiting:
        return '탑승 대기';
      case ChildBoardingStatus.boarded:
        return '탑승 중';
      case ChildBoardingStatus.droppedOff:
        return '하차 완료';
    }
  }

  static void updateChildStatus(
      String name,
      ChildBoardingStatus status,
      ) {
    if (childStatuses.value[name] == status) return;

    childStatuses.value = {
      ...childStatuses.value,
      name: status,
    };

    final title = status == ChildBoardingStatus.boarded
        ? '$name 승차 완료'
        : status == ChildBoardingStatus.droppedOff
        ? '$name 하차 완료'
        : '$name 탑승 대기';

    _addEvent(
      title: title,
      message: '1호차 · $name 학생의 상태가 변경되었습니다.',
      isAlert: false,
    );
  }

  static void addSafetyEvent(SafetyEventType type) {
    String title;
    String message;

    switch (type) {
      case SafetyEventType.suddenBrake:
        title = '급정거 감지 (테스트)';
        message = '1호차에서 급정거 상황이 발생했습니다.';
        break;
      case SafetyEventType.speeding:
        title = '과속 감지 (테스트)';
        message = '1호차에서 과속 상황이 발생했습니다.';
        break;
      case SafetyEventType.routeDeviation:
        title = '경로 이탈 감지 (테스트)';
        message = '1호차가 지정된 운행 경로를 이탈했습니다.';
        break;
    }

    safetyCounts.value = {
      ...safetyCounts.value,
      type: (safetyCounts.value[type] ?? 0) + 1,
    };

    _addEvent(
      title: title,
      message: message,
      isAlert: true,
    );
  }

  static void _addEvent({
    required String title,
    required String message,
    required bool isAlert,
  }) {
    final now = DateTime.now();

    final time =
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}';

    final event = ParentMockEvent(
      id: _nextId++,
      title: title,
      message: message,
      time: time,
      isAlert: isAlert,
    );

    events.value = [event, ...events.value];
  }

  static void markEventAsRead(int id) {
    if (readEventIds.value.contains(id)) return;

    readEventIds.value = {
      ...readEventIds.value,
      id,
    };
  }

  static int get unreadEventCount {
    return events.value
        .where((event) => !readEventIds.value.contains(event.id))
        .length;
  }
}
