class ChildStudent {
  const ChildStudent({
    required this.id,
    required this.name,
    required this.className,
    this.isAbsent = false,
    this.isMock = false,
  });

  final int id;
  final String name;
  final String? className;
  final bool isAbsent;
  final bool isMock;

  factory ChildStudent.fromJson(Map<String, dynamic> json) => ChildStudent(
    id: json['id'] as int,
    name: json['name'] as String,
    className: json['class_name'] as String?,
    isAbsent: json['is_absent'] as bool? ?? false,
  );
}
