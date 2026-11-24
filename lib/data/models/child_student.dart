import 'child_location.dart';

class ChildStudent {
  const ChildStudent({
    required this.id,
    required this.name,
    required this.className,
    this.isAbsent = false,
    this.guardianUserIds = const [],
    this.location,
    this.busId,
    this.busName,
    this.busStatus,
    this.tripId,
    this.boardingConfirmedAt,
    this.alightingConfirmedAt,
    this.absenceStatus,
  });

  final int id;
  final String name;
  final String? className;
  final bool isAbsent;
  final List<int> guardianUserIds;
  final ChildLocation? location;
  final int? busId;
  final String? busName;
  final String? busStatus;
  final int? tripId;
  final DateTime? boardingConfirmedAt;
  final DateTime? alightingConfirmedAt;

  /// 결석 신청 처리 상태: REQUESTED(확인 대기) · CONFIRMED(확인됨) · REJECTED(반려)
  final String? absenceStatus;

  factory ChildStudent.fromJson(Map<String, dynamic> json) {
    final location = json['location'];
    return ChildStudent(
      id: json['id'] as int,
      name: json['name'] as String,
      className: json['class_name'] as String?,
      isAbsent: json['is_absent'] as bool? ?? false,
      busId: json['bus_id'] as int?,
      busName: json['bus_name'] as String?,
      busStatus: json['bus_status'] as String?,
      tripId: json['trip_id'] as int?,
      boardingConfirmedAt: DateTime.tryParse(
        json['boarding_confirmed_at']?.toString() ?? '',
      ),
      alightingConfirmedAt: DateTime.tryParse(
        json['alighting_confirmed_at']?.toString() ?? '',
      ),
      absenceStatus: json['attendance'] is Map
          ? (json['attendance'] as Map)['status'] as String?
          : null,
      location: location is Map
          ? ChildLocation.fromJson(Map<String, dynamic>.from(location))
          : null,
    );
  }
}
