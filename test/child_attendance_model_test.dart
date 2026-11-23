import 'package:final_project_app/data/models/child_attendance.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses local timestamps, request status, reasons, and attachments', () {
    final attendance = ChildAttendance.fromJson({
      'date': '2026-11-23',
      'is_absent': true,
      'deadline_at': '2026-11-23T12:30:00Z',
      'editable': true,
      'status': 'REQUESTED',
      'confirmed_at': '2026-11-23T09:00:00Z',
      'reject_reason': null,
      'reason_type': 'SICK',
      'reason_memo': '병원 진료',
      'files': [
        {
          'file_id': 17,
          'file_name': '진료확인서.pdf',
          'content_type': 'application/pdf',
        },
      ],
    }, fallbackDate: DateTime(2026, 11, 23));

    expect(attendance.date, DateTime(2026, 11, 23));
    expect(
      attendance.deadlineAt,
      DateTime.parse('2026-11-23T12:30:00Z').toLocal(),
    );
    expect(
      attendance.confirmedAt,
      DateTime.parse('2026-11-23T09:00:00Z').toLocal(),
    );
    expect(attendance.status, 'REQUESTED');
    expect(attendance.reasonType, 'SICK');
    expect(attendance.reasonMemo, '병원 진료');
    expect(attendance.files.single.id, 17);
    expect(attendance.files.single.contentType, 'application/pdf');
  });

  test('does not expose absence status or reasons for an attendance day', () {
    final attendance = ChildAttendance.fromJson({
      'date': '2026-11-23',
      'is_absent': false,
      'editable': false,
      'status': 'CONFIRMED',
      'reason_type': 'SICK',
      'reason_memo': 'ignored',
    }, fallbackDate: DateTime(2026, 11, 23));

    expect(attendance.status, isNull);
    expect(attendance.reasonType, isNull);
    expect(attendance.reasonMemo, isNull);
  });
}
