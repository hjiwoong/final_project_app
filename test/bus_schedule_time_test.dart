import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:final_project_app/features/driver/bus_schedule_time.dart';

void main() {
  test(
    'formats scheduled_at timestamps with a timezone in device local time',
    () {
      final value = parseScheduledAt('2026-11-15T15:10:00Z');
      expect(value, DateTime.parse('2026-11-15T15:10:00Z').toLocal());
      expect(
        formatScheduledTime('2026-11-15T15:10:00Z'),
        formatScheduledTime(value),
      );
    },
  );

  test('assumes timezone-less scheduled_at timestamps are KST wall time', () {
    final value = parseScheduledAt('2026-11-16T08:10:00');
    expect(value, DateTime(2026, 11, 16, 8, 10));
    expect(formatScheduledTime(value), '08:10');
  });

  test('preserves midnight-adjacent times and converts offset rollover', () {
    expect(formatScheduledTime('2026-11-16T00:05:00'), '00:05');
    final converted = DateTime.parse('2026-11-15T15:05:00Z').toLocal();
    expect(
      formatScheduledTime('2026-11-15T15:05:00Z'),
      formatScheduledTime(converted),
    );
  });

  test('formats date and selected time using API field formats', () {
    expect(formatServiceDate(DateTime(2026, 11, 6)), '2026-11-06');
    expect(
      formatScheduleStartTime(const TimeOfDay(hour: 8, minute: 30)),
      '08:30:00',
    );
  });

  test('blocks past time slots only for the current date', () {
    final now = DateTime(2026, 11, 16, 8, 10);
    expect(
      isPastScheduleTime(
        serviceDate: DateTime(2026, 11, 16),
        time: const TimeOfDay(hour: 8, minute: 5),
        now: now,
      ),
      isTrue,
    );
    expect(
      isPastScheduleTime(
        serviceDate: DateTime(2026, 11, 16),
        time: const TimeOfDay(hour: 8, minute: 15),
        now: now,
      ),
      isFalse,
    );
    expect(
      isPastScheduleTime(
        serviceDate: DateTime(2026, 11, 17),
        time: const TimeOfDay(hour: 0, minute: 0),
        now: now,
      ),
      isFalse,
    );
  });
}
