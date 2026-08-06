class Employee {
  const Employee({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.role,
    required this.storeCode,
    required this.hireDate,
    this.terminationDate,
    this.terminationReason,
    required this.status,
    required this.notes,
  });

  final int? id;
  final String name;
  final String phone;
  final String email;
  final String role;
  final String storeCode;
  final DateTime hireDate;
  final DateTime? terminationDate;
  final String? terminationReason;
  final String status;
  final String notes;

  static const statuses = ['activo', 'baja', 'suspendido'];

  factory Employee.fromMap(Map<String, Object?> map) {
    return Employee(
      id: map['id'] as int?,
      name: map['name'] as String,
      phone: map['phone'] as String,
      email: map['email'] as String,
      role: map['role'] as String,
      storeCode: map['store_code'] as String,
      hireDate: DateTime.parse(map['hire_date'] as String),
      terminationDate: map['termination_date'] == null
          ? null
          : DateTime.parse(map['termination_date'] as String),
      terminationReason: map['termination_reason'] as String?,
      status: map['status'] as String,
      notes: map['notes'] as String? ?? '',
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'role': role,
      'store_code': storeCode,
      'hire_date': hireDate.toIso8601String(),
      'termination_date': terminationDate?.toIso8601String(),
      'termination_reason': terminationReason,
      'status': status,
      'notes': notes,
    };
  }
}
