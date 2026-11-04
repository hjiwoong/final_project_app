import 'guardian_location.dart';

class ChildStudent {
  const ChildStudent({
    required this.id,
    required this.name,
    required this.className,
    this.isAbsent = false,
    this.isMock = false,
    this.guardianUserIds = const [],
    this.guardianLocations = const [],
    this.busName,
    this.busStatus,
  });

  final int id;
  final String name;
  final String? className;
  final bool isAbsent;
  final bool isMock;
  final List<int> guardianUserIds;
  final List<GuardianLocation> guardianLocations;
  final String? busName;
  final String? busStatus;

  factory ChildStudent.fromJson(Map<String, dynamic> json) {
    final guardianLocations = json['guardian_locations'] as List? ?? const [];
    return ChildStudent(
      id: json['id'] as int,
      name: json['name'] as String,
      className: json['class_name'] as String?,
      isAbsent: json['is_absent'] as bool? ?? false,
      busName: json['bus_name'] as String?,
      busStatus: json['bus_status'] as String?,
      guardianLocations: guardianLocations
          .map(
            (location) => GuardianLocation.fromJson(
              Map<String, dynamic>.from(location as Map),
            ),
          )
          .toList(),
    );
  }
}
