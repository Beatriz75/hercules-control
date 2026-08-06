class LineAssignment {
  const LineAssignment({
    required this.id,
    required this.lineId,
    required this.employeeId,
    required this.assignedAt,
    this.removedAt,
    required this.status,
  });

  final int? id;
  final int lineId;
  final int employeeId;
  final DateTime assignedAt;
  final DateTime? removedAt;
  final String status;

  static const statuses = ['activa', 'retirada'];

  factory LineAssignment.fromMap(Map<String, Object?> map) {
    return LineAssignment(
      id: map['id'] as int?,
      lineId: map['line_id'] as int,
      employeeId: map['employee_id'] as int,
      assignedAt: DateTime.parse(map['assigned_at'] as String),
      removedAt: map['removed_at'] == null
          ? null
          : DateTime.parse(map['removed_at'] as String),
      status: map['status'] as String,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'line_id': lineId,
      'employee_id': employeeId,
      'assigned_at': assignedAt.toIso8601String(),
      'removed_at': removedAt?.toIso8601String(),
      'status': status,
    };
  }
}
