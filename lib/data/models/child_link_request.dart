class ChildLinkRequest {
  const ChildLinkRequest({
    required this.id,
    required this.childName,
    required this.status,
    this.className,
    this.relation,
    this.rejectReason,
    this.studentName,
    this.createdAt,
    this.decidedAt,
  });

  final int id;
  final String childName;
  final String? className;
  final String? relation;
  final String status;
  final String? rejectReason;
  final String? studentName;
  final DateTime? createdAt;
  final DateTime? decidedAt;

  factory ChildLinkRequest.fromJson(Map<String, dynamic> json) {
    final student = json['student'];
    return ChildLinkRequest(
      id: json['id'] as int,
      childName: json['child_name'] as String,
      className: json['class_name'] as String?,
      relation: json['relation'] as String?,
      status: (json['status'] as String).toUpperCase(),
      rejectReason: json['reject_reason'] as String?,
      studentName: student is Map ? student['name'] as String? : null,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
      decidedAt: DateTime.tryParse(json['decided_at'] as String? ?? ''),
    );
  }
}
