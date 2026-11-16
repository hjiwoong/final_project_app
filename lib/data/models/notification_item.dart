
class NotificationItem {
  final int id;
  final String title;
  final String body;
  final String? alertLevel;
  final String busName;
  final String time;
  final bool isAlert;
  bool read;
  final int? alertId;

  // 신규: 알림 카테고리 및 이벤트 종류
  final String? category;
  final String? eventType;

  NotificationItem({
    required this.id,
    required this.title,
    this.body = '',
    this.alertLevel,
    required this.busName,
    required this.time,
    required this.isAlert,
    this.read = false,
    this.alertId,

    // 신규 필드
    this.category,
    this.eventType,
  });

  // 운행 관련 알림인지 확인
  bool get isTripNotification =>
      category == 'TRIP' ||
          eventType == 'STARTED' ||
          eventType == 'ENDED' ||
          eventType == 'DELAYED';
}
