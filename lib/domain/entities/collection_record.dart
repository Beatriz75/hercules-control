class CollectionRecord {
  const CollectionRecord({
    required this.id,
    required this.customerName,
    required this.orderCode,
    required this.paymentDate,
    required this.amount,
    required this.method,
    required this.validatedBy,
    required this.storeCode,
    required this.notes,
    this.lineId,
  });

  final int? id;
  final String customerName;
  final String orderCode;
  final DateTime paymentDate;
  final double amount;
  final String method;
  final String validatedBy;
  final String storeCode;
  final String notes;
  final int? lineId;

  static const methods = ['transferencia', 'efectivo', 'zelle', 'otro'];

  factory CollectionRecord.fromMap(Map<String, Object?> map) {
    return CollectionRecord(
      id: map['id'] as int?,
      customerName: map['customer_name'] as String,
      orderCode: map['order_code'] as String,
      paymentDate: DateTime.parse(map['payment_date'] as String),
      amount: (map['amount'] as num).toDouble(),
      method: map['method'] as String,
      validatedBy: map['validated_by'] as String,
      storeCode: map['store_code'] as String,
      notes: map['notes'] as String? ?? '',
      lineId: map['line_id'] as int?,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'customer_name': customerName,
      'order_code': orderCode,
      'payment_date': paymentDate.toIso8601String(),
      'amount': amount,
      'method': method,
      'validated_by': validatedBy,
      'store_code': storeCode,
      'notes': notes,
      'line_id': lineId,
    };
  }
}
