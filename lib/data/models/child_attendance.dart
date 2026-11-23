class ChildAttendance {
  const ChildAttendance({
    required this.date,
    required this.isAbsent,
    required this.editable,
    this.deadlineAt,
    this.status,
    this.confirmedAt,
    this.rejectReason,
    this.reasonType,
    this.reasonMemo,
    this.files = const [],
  });

  final DateTime date;
  final bool isAbsent;
  final DateTime? deadlineAt;
  final bool editable;
  final String? status;
  final DateTime? confirmedAt;
  final String? rejectReason;
  final String? reasonType;
  final String? reasonMemo;
  final List<ChildAttendanceFile> files;

  factory ChildAttendance.fromJson(
    Map<String, dynamic> json, {
    required DateTime fallbackDate,
  }) {
    final isAbsent = json['is_absent'] as bool? ?? false;
    final rawDate = json['date']?.toString();
    final date = rawDate == null
        ? DateTime(fallbackDate.year, fallbackDate.month, fallbackDate.day)
        : _parseDateOnly(rawDate);
    final rawFiles = json['files'] ?? json['attachments'];

    return ChildAttendance(
      date: date,
      isAbsent: isAbsent,
      deadlineAt: _parseTimestamp(json['deadline_at']),
      editable: json['editable'] as bool? ?? false,
      status: isAbsent ? json['status'] as String? : null,
      confirmedAt: _parseTimestamp(json['confirmed_at']),
      rejectReason: json['reject_reason'] as String?,
      reasonType: isAbsent ? json['reason_type'] as String? : null,
      reasonMemo: isAbsent ? json['reason_memo'] as String? : null,
      files: rawFiles is List
          ? rawFiles
                .map(
                  (file) => ChildAttendanceFile.fromJson(
                    Map<String, dynamic>.from(file as Map),
                  ),
                )
                .toList()
          : const [],
    );
  }

  static DateTime? _parseTimestamp(Object? value) {
    if (value == null) return null;
    return DateTime.parse(value.toString()).toLocal();
  }

  static DateTime _parseDateOnly(String value) {
    final parts = value.split('-');
    if (parts.length != 3) return DateTime.parse(value).toLocal();
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2].substring(0, 2)),
    );
  }
}

class ChildAttendanceFile {
  const ChildAttendanceFile({
    required this.id,
    required this.name,
    this.contentType,
  });

  final int id;
  final String name;
  final String? contentType;

  factory ChildAttendanceFile.fromJson(Map<String, dynamic> json) {
    final id = json['file_id'] ?? json['id'];
    return ChildAttendanceFile(
      id: id is int ? id : int.parse(id.toString()),
      name:
          json['file_name'] as String? ??
          json['filename'] as String? ??
          json['name'] as String? ??
          '첨부 파일',
      contentType:
          json['content_type'] as String? ?? json['mime_type'] as String?,
    );
  }
}
