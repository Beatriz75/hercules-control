class Debt {
  const Debt({
    required this.id,
    required this.customerName,
    required this.orderCode,
    required this.deliveryDate,
    required this.dueDate,
    required this.amount,
    required this.status,
    required this.responsible,
    required this.storeCode,
    required this.notes,
  });

  final int? id;
  final String customerName;
  final String orderCode;
  final DateTime deliveryDate;
  final DateTime dueDate;
  final double amount;
  final String status;
  final String responsible;
  final String storeCode;
  final String notes;

  static const statuses = [
    'pendiente',
    'contactado',
    'promete pagar',
    'pagado',
    'vencido',
    'incobrable',
    'fraude sospechado',
  ];

  factory Debt.fromMap(Map<String, Object?> map) {
    return Debt(
      id: map['id'] as int?,
      customerName: map['customer_name'] as String,
      orderCode: map['order_code'] as String,
      deliveryDate: DateTime.parse(map['delivery_date'] as String),
      dueDate: DateTime.parse(map['due_date'] as String),
      amount: (map['amount'] as num).toDouble(),
      status: map['status'] as String,
      responsible: map['responsible'] as String,
      storeCode: map['store_code'] as String,
      notes: map['notes'] as String? ?? '',
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'customer_name': customerName,
      'order_code': orderCode,
      'delivery_date': deliveryDate.toIso8601String(),
      'due_date': dueDate.toIso8601String(),
      'amount': amount,
      'status': status,
      'responsible': responsible,
      'store_code': storeCode,
      'notes': notes,
    };
  }
}
