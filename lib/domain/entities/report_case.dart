class ReportCase {
  const ReportCase({
    required this.id,
    required this.type,
    required this.orderCode,
    required this.customerName,
    this.employeeId,
    required this.storeCode,
    required this.reportDate,
    required this.description,
    required this.status,
    required this.priority,
    required this.owner,
    this.lineId,
    required this.traceabilityRisk,
    required this.externalChannel,
  });

  final int? id;
  final String type;
  final String orderCode;
  final String customerName;
  final int? employeeId;
  final String storeCode;
  final DateTime reportDate;
  final String description;
  final String status;
  final String priority;
  final String owner;
  final int? lineId;
  final bool traceabilityRisk;
  final bool externalChannel;

  static const types = [
    'paqueteria',
    'rotura',
    'cliente no paga',
    'fraude cliente',
    'fraude trabajador',
    'incidencia operativa',
  ];

  static const statuses = ['abierto', 'en revision', 'resuelto'];
  static const priorities = ['baja', 'media', 'alta', 'critica'];

  factory ReportCase.fromMap(Map<String, Object?> map) {
    return ReportCase(
      id: map['id'] as int?,
      type: map['type'] as String,
      orderCode: map['order_code'] as String,
      customerName: map['customer_name'] as String,
      employeeId: map['employee_id'] as int?,
      storeCode: map['store_code'] as String,
      reportDate: DateTime.parse(map['report_date'] as String),
      description: map['description'] as String,
      status: map['status'] as String,
      priority: map['priority'] as String,
      owner: map['owner'] as String,
      lineId: map['line_id'] as int?,
      traceabilityRisk: (map['traceability_risk'] as int? ?? 0) == 1,
      externalChannel: (map['external_channel'] as int? ?? 0) == 1,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'type': type,
      'order_code': orderCode,
      'customer_name': customerName,
      'employee_id': employeeId,
      'store_code': storeCode,
      'report_date': reportDate.toIso8601String(),
      'description': description,
      'status': status,
      'priority': priority,
      'owner': owner,
      'line_id': lineId,
      'traceability_risk': traceabilityRisk ? 1 : 0,
      'external_channel': externalChannel ? 1 : 0,
    };
  }
}
