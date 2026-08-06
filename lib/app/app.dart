import 'package:flutter/material.dart';
import 'package:hercules_control/app/app_scope.dart';
import 'package:hercules_control/app/navigation/app_shell.dart';
import 'package:hercules_control/core/theme/app_theme.dart';
import 'package:hercules_control/data/local/app_database.dart';
import 'package:hercules_control/data/repositories/collection_repository.dart';
import 'package:hercules_control/data/repositories/daily_review_repository.dart';
import 'package:hercules_control/data/repositories/debt_repository.dart';
import 'package:hercules_control/data/repositories/employee_payment_repository.dart';
import 'package:hercules_control/data/repositories/employee_repository.dart';
import 'package:hercules_control/data/repositories/line_repository.dart';
import 'package:hercules_control/data/repositories/report_repository.dart';
import 'package:hercules_control/data/repositories/weekly_report_repository.dart';

class HerculesControlApp extends StatelessWidget {
  const HerculesControlApp({
    super.key,
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

  @override
  Widget build(BuildContext context) {
    return AppScope(
      database: database,
      employeeRepository: employeeRepository,
      employeePaymentRepository: employeePaymentRepository,
      dailyReviewRepository: dailyReviewRepository,
      debtRepository: debtRepository,
      collectionRepository: collectionRepository,
      reportRepository: reportRepository,
      lineRepository: lineRepository,
      weeklyReportRepository: weeklyReportRepository,
      child: MaterialApp(
        title: 'Hercules Control',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: const AppShell(),
      ),
    );
  }
}
