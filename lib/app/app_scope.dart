import 'package:flutter/widgets.dart';
import 'package:hercules_control/data/local/app_database.dart';
import 'package:hercules_control/data/repositories/collection_repository.dart';
import 'package:hercules_control/data/repositories/daily_review_repository.dart';
import 'package:hercules_control/data/repositories/debt_repository.dart';
import 'package:hercules_control/data/repositories/employee_payment_repository.dart';
import 'package:hercules_control/data/repositories/employee_repository.dart';
import 'package:hercules_control/data/repositories/line_repository.dart';
import 'package:hercules_control/data/repositories/report_repository.dart';
import 'package:hercules_control/data/repositories/weekly_report_repository.dart';

class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required super.child,
    required this.database,
    required this.employeeRepository,
    required this.employeePaymentRepository,
    required this.dailyReviewRepository,
    required this.debtRepository,
    required this.collectionRepository,
    required this.reportRepository,
    required this.lineRepository,
    required this.weeklyReportRepository,
  });

  final AppDatabase database;
  final EmployeeRepository employeeRepository;
  final EmployeePaymentRepository employeePaymentRepository;
  final DailyReviewRepository dailyReviewRepository;
  final DebtRepository debtRepository;
  final CollectionRepository collectionRepository;
  final ReportRepository reportRepository;
  final LineRepository lineRepository;
  final WeeklyReportRepository weeklyReportRepository;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope no disponible en este contexto.');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) => false;
}
