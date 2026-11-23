class NotificationItem {
  final int id;
  final String title;
  final String body;
  final String? busName;
  final DateTime sentAt;
  final DateTime? readAt;
  bool isRead;
  final String category;
  final String? eventType;
  final int? tripId;
  final int? alertId;

  NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    this.busName,
    required this.sentAt,
    this.readAt,
    required this.isRead,
    required this.category,
    this.eventType,
    this.tripId,
    this.alertId,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    final readAt = json['read_at'] as String?;
    return NotificationItem(
      id: json['id'] as int,
      title: json['title'] as String,
      body: json['body'] as String? ?? '',
      busName: json['bus_name'] as String?,
      sentAt: DateTime.parse(json['sent_at'] as String).toLocal(),
      readAt: readAt == null ? null : DateTime.parse(readAt).toLocal(),
      isRead: json['is_read'] as bool,
      category: json['category'] as String,
      eventType: json['event_type'] as String?,
      tripId: json['trip_id'] as int?,
      alertId: json['alert_id'] as int?,
    );
  }
}

class NotificationPage {
  final List<NotificationItem> items;
  final int total;
  final int unreadCount;

  NotificationPage({
    required this.items,
    required this.total,
    required this.unreadCount,
  });

  factory NotificationPage.fromJson(Map<String, dynamic> json) {
    return NotificationPage(
      items: (json['items'] as List)
          .map(
            (item) => NotificationItem.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
      total: json['total'] as int,
      unreadCount: json['unread_count'] as int,
    );
  }
}
