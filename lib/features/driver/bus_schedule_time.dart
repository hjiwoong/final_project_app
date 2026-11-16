import 'package:flutter/material.dart';

DateTime? parseScheduledAt(Object? value) {
  if (value is DateTime) return value.isUtc ? value.toLocal() : value;
  if (value is! String) return null;

  try {
    final parsed = DateTime.parse(value);
    final hasTimeZone = RegExp(
      r'(?:Z|[+-]\d{2}:?\d{2})$',
      caseSensitive: false,
    ).hasMatch(value);
    if (hasTimeZone) return parsed.toLocal();

    // The API may omit an offset; in that case its wall-clock time is KST.
    return DateTime(
      parsed.year,
      parsed.month,
      parsed.day,
      parsed.hour,
      parsed.minute,
      parsed.second,
      parsed.millisecond,
      parsed.microsecond,
    );
  } on FormatException {
    return null;
  }
}

String? formatScheduledTime(Object? value) {
  final dateTime = value is DateTime
      ? (value.isUtc ? value.toLocal() : value)
      : parseScheduledAt(value);
  if (dateTime == null) return null;
  return '${dateTime.hour.toString().padLeft(2, '0')}:'
      '${dateTime.minute.toString().padLeft(2, '0')}';
}

String formatServiceDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

String formatScheduleStartTime(TimeOfDay value) =>
    '${value.hour.toString().padLeft(2, '0')}:'
    '${value.minute.toString().padLeft(2, '0')}:00';

bool isPastScheduleTime({
  required DateTime serviceDate,
  required TimeOfDay time,
  required DateTime now,
}) {
  final isToday =
      serviceDate.year == now.year &&
      serviceDate.month == now.month &&
      serviceDate.day == now.day;
  if (!isToday) return false;
  return !DateTime(
    serviceDate.year,
    serviceDate.month,
    serviceDate.day,
    time.hour,
    time.minute,
  ).isAfter(now);
}

TimeOfDay initialScheduleTime({
  required DateTime serviceDate,
  required DateTime? scheduledAt,
  required DateTime now,
}) {
  final candidate = scheduledAt == null
      ? TimeOfDay.fromDateTime(now)
      : TimeOfDay.fromDateTime(scheduledAt);
  if (!isPastScheduleTime(
    serviceDate: serviceDate,
    time: candidate,
    now: now,
  )) {
    return candidate;
  }

  var totalMinutes = now.hour * 60 + now.minute + 1;
  totalMinutes = ((totalMinutes + 4) ~/ 5) * 5;
  if (totalMinutes >= 24 * 60) return const TimeOfDay(hour: 23, minute: 55);
  return TimeOfDay(hour: totalMinutes ~/ 60, minute: totalMinutes % 60);
}

Future<TimeOfDay?> showFiveMinuteTimePicker({
  required BuildContext context,
  required DateTime serviceDate,
  required TimeOfDay initialTime,
  DateTime? now,
}) {
  final currentTime = now ?? DateTime.now();
  var hour = initialTime.hour;
  var minute = initialTime.minute - initialTime.minute % 5;
  if (isPastScheduleTime(
    serviceDate: serviceDate,
    time: TimeOfDay(hour: hour, minute: minute),
    now: currentTime,
  )) {
    final next = initialScheduleTime(
      serviceDate: serviceDate,
      scheduledAt: null,
      now: currentTime,
    );
    hour = next.hour;
    minute = next.minute;
  }

  return showDialog<TimeOfDay>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) {
        final selected = TimeOfDay(hour: hour, minute: minute);
        final canConfirm = !isPastScheduleTime(
          serviceDate: serviceDate,
          time: selected,
          now: currentTime,
        );
        return AlertDialog(
          title: const Text('출발 예정 시각'),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              DropdownButton<int>(
                value: hour,
                items: [
                  for (var value = 0; value < 24; value++)
                    DropdownMenuItem(
                      value: value,
                      enabled: !isPastScheduleTime(
                        serviceDate: serviceDate,
                        time: TimeOfDay(hour: value, minute: 55),
                        now: currentTime,
                      ),
                      child: Text(value.toString().padLeft(2, '0')),
                    ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setDialogState(() {
                    hour = value;
                    if (isPastScheduleTime(
                      serviceDate: serviceDate,
                      time: TimeOfDay(hour: hour, minute: minute),
                      now: currentTime,
                    )) {
                      minute = 0;
                      while (minute < 60 &&
                          isPastScheduleTime(
                            serviceDate: serviceDate,
                            time: TimeOfDay(hour: hour, minute: minute),
                            now: currentTime,
                          )) {
                        minute += 5;
                      }
                      if (minute == 60) minute = 55;
                    }
                  });
                },
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text(':', style: TextStyle(fontSize: 20)),
              ),
              DropdownButton<int>(
                value: minute,
                items: [
                  for (var value = 0; value < 60; value += 5)
                    DropdownMenuItem(
                      value: value,
                      enabled: !isPastScheduleTime(
                        serviceDate: serviceDate,
                        time: TimeOfDay(hour: hour, minute: value),
                        now: currentTime,
                      ),
                      child: Text(value.toString().padLeft(2, '0')),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) setDialogState(() => minute = value);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: canConfirm
                  ? () => Navigator.of(
                      context,
                    ).pop(TimeOfDay(hour: hour, minute: minute))
                  : null,
              child: const Text('확인'),
            ),
          ],
        );
      },
    ),
  );
}

class BusScheduleListResult {
  const BusScheduleListResult({
    required this.serviceDate,
    required this.scheduledAt,
  });

  final DateTime serviceDate;
  final DateTime scheduledAt;
}
