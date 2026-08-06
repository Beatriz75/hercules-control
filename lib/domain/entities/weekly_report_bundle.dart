import 'package:hercules_control/domain/entities/weekly_custom_criterion.dart';
import 'package:hercules_control/domain/entities/weekly_report.dart';
import 'package:hercules_control/domain/entities/weekly_report_day.dart';

class WeeklyReportBundle {
  const WeeklyReportBundle({
    required this.report,
    required this.days,
    required this.customCriteria,
  });

  final WeeklyReport report;
  final List<WeeklyReportDay> days;
  final List<WeeklyCustomCriterion> customCriteria;

  int get deliveredTotal =>
      days.fold(0, (sum, day) => sum + day.deliveredTotal);

  int get paidDelivered => days.fold(0, (sum, day) => sum + day.paidDelivered);

  int get paidLevel3 => days.fold(0, (sum, day) => sum + day.paidLevel3);

  int get reports => days.fold(0, (sum, day) => sum + day.reports);

  int get returnsCount => days.fold(0, (sum, day) => sum + day.returnsCount);

  int get debtors => days.fold(0, (sum, day) => sum + day.debtors);

  int get aliDebtors => days.fold(0, (sum, day) => sum + day.aliDebtors);

  int get classifiedTotal =>
      paidDelivered +
      paidLevel3 +
      reports +
      returnsCount +
      debtors +
      aliDebtors;

  int get difference => deliveredTotal - classifiedTotal;

  bool get isBalanced =>
      difference == 0 &&
      days.length == 7 &&
      days.every((day) => day.isBalanced);

  double get debtorsPercent => _percent(debtors);

  double get aliDebtorsPercent => _percent(aliDebtors);

  double get unpaidPercent =>
      _percent(reports + returnsCount + debtors + aliDebtors);

  double get incidentsPercent => _percent(reports + returnsCount);

  double get paidDeliveredPercent => _percent(paidDelivered);

  double get paidBeforeLevel3Percent => paidDeliveredPercent;

  double get level3Percent => _percent(paidLevel3);

  double get totalPaidPercent => _percent(paidDelivered + paidLevel3);

  double _percent(int value) {
    if (deliveredTotal == 0) {
      return 0;
    }
    return (value / deliveredTotal) * 100;
  }
}
