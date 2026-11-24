import 'package:flutter/foundation.dart';

/// 결석(출결)이 바뀌었다는 신호.
///
/// - 학부모 앱: 홈·출석·결석 관리 어디서 저장하든 [notifyChanged] → 홈이 바로 다시 불러온다
/// - 관리자(기사) 앱: 결석 알림 푸시를 받으면 [notifyChanged] → 탑승 지도·출결 확인이 바로 다시 불러온다
///   (푸시가 안 오는 환경을 위해 그 화면들은 주기적으로도 다시 불러온다)
class AttendanceSync {
  AttendanceSync._();

  static final ValueNotifier<int> changes = ValueNotifier<int>(0);

  static void notifyChanged() => changes.value++;

  /// 푸시 data 가 결석 알림인지 (서버 notifier: category=ATTENDANCE, event_type=ABSENT·ABSENT_CANCELED)
  static bool isAttendanceMessage(Map<String, dynamic> data) =>
      data['category'] == 'ATTENDANCE' ||
      data['event_type'] == 'ABSENT' ||
      data['event_type'] == 'ABSENT_CANCELED';
}
