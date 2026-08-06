class EmployeePayment {
  const EmployeePayment({
    required this.id,
    required this.employeeId,
    required this.paymentDate,
    required this.amount,
    required this.concept,
    required this.paymentMethod,
    required this.notes,
  });

  final int? id;
  final int employeeId;
  final DateTime paymentDate;
  final double amount;
  final String concept;
  final String paymentMethod;
  final String notes;

  static const paymentMethods = ['transferencia', 'efectivo', 'zelle'];

  factory EmployeePayment.fromMap(Map<String, Object?> map) {
    return EmployeePayment(
      id: map['id'] as int?,
      employeeId: map['employee_id'] as int,
      paymentDate: DateTime.parse(map['payment_date'] as String),
      amount: (map['amount'] as num).toDouble(),
      concept: map['concept'] as String,
      paymentMethod: map['payment_method'] as String,
      notes: map['notes'] as String? ?? '',
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'employee_id': employeeId,
      'payment_date': paymentDate.toIso8601String(),
      'amount': amount,
      'concept': concept,
      'payment_method': paymentMethod,
      'notes': notes,
    };
  }
}
