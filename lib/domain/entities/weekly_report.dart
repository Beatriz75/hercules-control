import 'package:hercules_control/domain/value_objects/store_type.dart';

class WeeklyReport {
  const WeeklyReport({
    required this.id,
    required this.title,
    required this.storeCode,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.closedAt,
  });

  final int? id;
  final String title;
  final String storeCode;
  final DateTime startDate;
  final DateTime endDate;
  final String status;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? closedAt;

  bool get isClosed => status == 'cerrado';
  String get storeLabel => StoreType.fromCode(storeCode).label;

  factory WeeklyReport.fromMap(Map<String, Object?> map) {
    return WeeklyReport(
      id: map['id'] as int?,
      title: map['title'] as String,
      storeCode: map['store_code'] as String? ?? StoreType.pideHoy.name,
      startDate: DateTime.parse(map['start_date'] as String),
      endDate: DateTime.parse(map['end_date'] as String),
      status: map['status'] as String,
      notes: map['notes'] as String? ?? '',
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      closedAt: map['closed_at'] == null
          ? null
          : DateTime.parse(map['closed_at'] as String),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'title': title,
      'store_code': storeCode,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'status': status,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'closed_at': closedAt?.toIso8601String(),
    };
  }
}
