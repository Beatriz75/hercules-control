import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:hercules_control/app/app.dart';
import 'package:hercules_control/core/api/api_client.dart';
import 'package:hercules_control/core/auth/auth_controller.dart';
import 'package:hercules_control/data/local/app_database.dart';
import 'package:hercules_control/data/repositories/collection_repository.dart';
import 'package:hercules_control/data/repositories/daily_review_repository.dart';
import 'package:hercules_control/data/repositories/debt_repository.dart';
import 'package:hercules_control/data/repositories/employee_payment_repository.dart';
import 'package:hercules_control/data/repositories/employee_repository.dart';
import 'package:hercules_control/data/repositories/line_repository.dart';
import 'package:hercules_control/data/repositories/report_repository.dart';
import 'package:hercules_control/data/repositories/weekly_report_repository.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  // The local SQLite database only backs modules hidden in this delivery; it
  // is opened lazily on first use so it can never block the web startup.
  final database = AppDatabase();
  final authController = AuthController(api: ApiClient());
  unawaited(authController.restore());

  runApp(
    HerculesControlApp(
      authController: authController,
      database: database,
      employeeRepository: EmployeeRepository(database),
      employeePaymentRepository: EmployeePaymentRepository(database),
      dailyReviewRepository: DailyReviewRepository(database),
      debtRepository: DebtRepository(database),
      collectionRepository: CollectionRepository(database),
      reportRepository: ReportRepository(database),
      lineRepository: LineRepository(database),
      weeklyReportRepository: WeeklyReportRepository(database),
    ),
  );
}
