import 'child_location.dart';

class ChildStudent {
  const ChildStudent({
    required this.id,
    required this.name,
    required this.className,
    this.isAbsent = false,
    this.isMock = false,
    this.guardianUserIds = const [],
    this.location,
    this.busName,
    this.busStatus,
  });

  final int id;
  final String name;
  final String? className;
  final bool isAbsent;
  final bool isMock;
  final List<int> guardianUserIds;
  final ChildLocation? location;
  final String? busName;
  final String? busStatus;

  factory ChildStudent.fromJson(Map<String, dynamic> json) {
    final location = json['location'];
    return ChildStudent(
      id: json['id'] as int,
      name: json['name'] as String,
      className: json['class_name'] as String?,
      isAbsent: json['is_absent'] as bool? ?? false,
      busName: json['bus_name'] as String?,
      busStatus: json['bus_status'] as String?,
      location: location is Map
          ? ChildLocation.fromJson(Map<String, dynamic>.from(location))
          : null,
    );
  }
}
