class PhoneLine {
  const PhoneLine({
    required this.id,
    required this.phoneNumber,
    required this.alias,
    required this.status,
    required this.provider,
    required this.createdAt,
    required this.notes,
  });

  final int? id;
  final String phoneNumber;
  final String alias;
  final String status;
  final String provider;
  final DateTime createdAt;
  final String notes;

  static const statuses = ['activa', 'inactiva', 'bloqueada'];

  factory PhoneLine.fromMap(Map<String, Object?> map) {
    return PhoneLine(
      id: map['id'] as int?,
      phoneNumber: map['phone_number'] as String,
      alias: map['alias'] as String,
      status: map['status'] as String,
      provider: map['provider'] as String? ?? '',
      createdAt: DateTime.parse(map['created_at'] as String),
      notes: map['notes'] as String? ?? '',
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'phone_number': phoneNumber,
      'alias': alias,
      'status': status,
      'provider': provider,
      'created_at': createdAt.toIso8601String(),
      'notes': notes,
    };
  }
}
