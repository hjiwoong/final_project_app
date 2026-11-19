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
  });
}
