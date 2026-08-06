class WeeklyReportDay {
  const WeeklyReportDay({
    required this.id,
    required this.reportId,
    required this.reportDate,
    required this.deliveredTotal,
    required this.paidDelivered,
    required this.paidLevel3,
    required this.reports,
    required this.returnsCount,
    required this.debtors,
    required this.aliDebtors,
  });

  final int? id;
  final int reportId;
  final DateTime reportDate;
  final int deliveredTotal;
  final int paidDelivered;
  final int paidLevel3;
  final int reports;
  final int returnsCount;
  final int debtors;
  final int aliDebtors;

  int get classifiedTotal =>
      paidDelivered +
      paidLevel3 +
      reports +
      returnsCount +
      debtors +
      aliDebtors;

  int get difference => deliveredTotal - classifiedTotal;

  bool get isBalanced => difference == 0;

  factory WeeklyReportDay.empty({
    required int reportId,
    required DateTime reportDate,
  }) {
    return WeeklyReportDay(
      id: null,
      reportId: reportId,
      reportDate: reportDate,
      deliveredTotal: 0,
      paidDelivered: 0,
      paidLevel3: 0,
      reports: 0,
      returnsCount: 0,
      debtors: 0,
      aliDebtors: 0,
    );
  }

  factory WeeklyReportDay.fromMap(Map<String, Object?> map) {
    return WeeklyReportDay(
      id: map['id'] as int?,
      reportId: map['report_id'] as int,
      reportDate: DateTime.parse(map['report_date'] as String),
      deliveredTotal: map['delivered_total'] as int,
      paidDelivered: map['paid_delivered'] as int,
      paidLevel3: map['paid_level3'] as int,
      reports: map['reports'] as int,
      returnsCount: map['returns'] as int,
      debtors: map['debtors'] as int,
      aliDebtors: map['ali_debtors'] as int,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'report_id': reportId,
      'report_date': reportDate.toIso8601String(),
      'delivered_total': deliveredTotal,
      'paid_delivered': paidDelivered,
      'paid_level3': paidLevel3,
      'reports': reports,
      'returns': returnsCount,
      'debtors': debtors,
      'ali_debtors': aliDebtors,
    };
  }
}
