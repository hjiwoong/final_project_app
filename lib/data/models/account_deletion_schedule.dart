class AccountDeletionSchedule {
  const AccountDeletionSchedule({
    required this.requestedAt,
    required this.scheduledDeletionAt,
    required this.gracePeriodDays,
    this.daysRemaining,
  });

  final DateTime requestedAt;
  final DateTime scheduledDeletionAt;
  final int gracePeriodDays;
  final int? daysRemaining;

  int get remainingDays {
    if (daysRemaining != null) return daysRemaining!;
    final seconds = scheduledDeletionAt.difference(DateTime.now()).inSeconds;
    return ((seconds + 86399) ~/ 86400).clamp(0, gracePeriodDays);
  }

  factory AccountDeletionSchedule.fromJson(Map<String, dynamic> json) =>
      AccountDeletionSchedule(
        requestedAt: DateTime.parse(json['requested_at'] as String),
        scheduledDeletionAt: DateTime.parse(
          json['scheduled_deletion_at'] as String,
        ),
        gracePeriodDays: json['grace_period_days'] as int,
        daysRemaining: json['days_remaining'] as int?,
      );
}
