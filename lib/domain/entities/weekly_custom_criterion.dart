class WeeklyCustomCriterion {
  const WeeklyCustomCriterion({
    required this.id,
    required this.reportId,
    required this.name,
    required this.value,
    required this.notes,
  });

  final int? id;
  final int reportId;
  final String name;
  final double value;
  final String notes;

  factory WeeklyCustomCriterion.fromMap(Map<String, Object?> map) {
    return WeeklyCustomCriterion(
      id: map['id'] as int?,
      reportId: map['report_id'] as int,
      name: map['name'] as String,
      value: (map['value'] as num).toDouble(),
      notes: map['notes'] as String? ?? '',
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'report_id': reportId,
      'name': name,
      'value': value,
      'notes': notes,
    };
  }
}
