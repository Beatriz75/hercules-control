import 'package:flutter/material.dart';
import 'package:hercules_control/app/app_scope.dart';
import 'package:hercules_control/core/utils/formatters.dart';
import 'package:hercules_control/core/widgets/app_panel.dart';
import 'package:hercules_control/core/widgets/metric_card.dart';
import 'package:hercules_control/core/widgets/page_header.dart';
import 'package:hercules_control/core/widgets/simple_bar_chart.dart';
import 'package:hercules_control/core/widgets/status_badge.dart';
import 'package:hercules_control/domain/entities/collection_record.dart';
import 'package:hercules_control/domain/entities/daily_review.dart';
import 'package:hercules_control/domain/entities/debt.dart';
import 'package:hercules_control/domain/entities/employee.dart';
import 'package:hercules_control/domain/entities/employee_payment.dart';
import 'package:hercules_control/domain/entities/line_assignment.dart';
import 'package:hercules_control/domain/entities/phone_line.dart';
import 'package:hercules_control/domain/entities/report_case.dart';
import 'package:hercules_control/domain/value_objects/store_type.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late Future<_DashboardData> _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future = _load();
  }

  Future<_DashboardData> _load() async {
    final scope = AppScope.of(context);
    final results = await Future.wait([
      scope.employeeRepository.fetchAll(),
      scope.employeePaymentRepository.fetchAll(),
      scope.dailyReviewRepository.fetchAll(),
      scope.debtRepository.fetchAll(),
      scope.collectionRepository.fetchAll(),
      scope.reportRepository.fetchAll(),
      scope.lineRepository.fetchLines(),
      scope.lineRepository.fetchAssignments(),
    ]);

    return _DashboardData(
      employees: results[0] as List<Employee>,
      payments: results[1] as List<EmployeePayment>,
      reviews: results[2] as List<DailyReview>,
      debts: results[3] as List<Debt>,
      collections: results[4] as List<CollectionRecord>,
      reports: results[5] as List<ReportCase>,
      lines: results[6] as List<PhoneLine>,
      assignments: results[7] as List<LineAssignment>,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_DashboardData>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data!;
        final activeEmployees =
            data.employees.where((item) => item.status == 'activo').length;
        final inactiveEmployees =
            data.employees.where((item) => item.status != 'activo').length;
        final totalPaid =
            data.payments.fold<double>(0, (sum, item) => sum + item.amount);
        final totalDebt =
            data.debts.fold<double>(0, (sum, item) => sum + item.amount);
        final totalCollected =
            data.collections.fold<double>(0, (sum, item) => sum + item.amount);
        final collectionRate = (totalCollected + totalDebt) == 0
            ? 100.0
            : (totalCollected / (totalCollected + totalDebt)) * 100;
        final openReports =
            data.reports.where((item) => item.status != 'resuelto').length;
        final delinquentClients = data.debts
            .where(
              (item) =>
                  item.status == 'vencido' ||
                  item.status == 'incobrable' ||
                  item.status == 'fraude sospechado',
            )
            .length;
        final riskyWorkers = _riskyWorkers(data.employees, data.reviews);
        final reviewsByStore = {
          for (final store in StoreType.values)
            store.label: _averageScoreForStore(store.name, data.reviews),
        };

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHeader(
                title: 'Dashboard operativo',
                subtitle:
                    'Vista consolidada de empleados, cartera, cobros e incidencias.',
                action: FilledButton.icon(
                  onPressed: () => setState(() => _future = _load()),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Actualizar'),
                ),
              ),
              const SizedBox(height: 24),
              GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.30,
                children: [
                  MetricCard(
                    title: 'Empleados activos',
                    value: '$activeEmployees',
                    caption: '$inactiveEmployees fuera de operacion',
                    icon: Icons.groups_rounded,
                  ),
                  MetricCard(
                    title: 'Pagado a empleados',
                    value: Formatters.currency(totalPaid),
                    caption: 'Acumulado en el MVP',
                    icon: Icons.payments_rounded,
                  ),
                  MetricCard(
                    title: 'Deuda pendiente',
                    value: Formatters.currency(totalDebt),
                    caption: '$delinquentClients clientes morosos',
                    icon: Icons.money_off_csred_rounded,
                    alert: delinquentClients > 0,
                  ),
                  MetricCard(
                    title: 'Porcentaje de cobro',
                    value: '${collectionRate.toStringAsFixed(1)}%',
                    caption: '${data.collections.length} cobros validados',
                    icon: Icons.request_quote_rounded,
                  ),
                  MetricCard(
                    title: 'Reportes abiertos',
                    value: '$openReports',
                    caption: 'Operativos y fraude',
                    icon: Icons.report_problem_rounded,
                    alert: openReports > 0,
                  ),
                  MetricCard(
                    title: 'Trabajadores con faltas',
                    value: '${riskyWorkers.length}',
                    caption: 'Tarjetas en rojo',
                    icon: Icons.warning_amber_rounded,
                    alert: riskyWorkers.isNotEmpty,
                  ),
                  MetricCard(
                    title: 'Lineas activas',
                    value:
                        '${data.lines.where((item) => item.status == 'activa').length}',
                    caption:
                        '${data.assignments.where((item) => item.status == 'activa').length} asignaciones vigentes',
                    icon: Icons.sim_card_rounded,
                  ),
                  MetricCard(
                    title: 'Evaluaciones del dia',
                    value:
                        '${data.reviews.where((item) => _isSameDay(item.reviewDate, DateTime.now())).length}',
                    caption: 'Muestra diaria revisada',
                    icon: Icons.analytics_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: AppPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Desempeno por tienda',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 18),
                          SimpleBarChart(
                            values: reviewsByStore.entries
                                .map(
                                  (entry) => ChartBarValue(
                                    label: entry.key,
                                    value: entry.value,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: AppPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Desempeno por trabajador',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 18),
                          for (final item in _workerScores(
                            data.employees,
                            data.reviews,
                          ))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: Row(
                                children: [
                                  Expanded(child: Text(item.name)),
                                  StatusBadge(
                                    label: item.hasFaults
                                        ? 'Con faltas'
                                        : 'Normal',
                                    color: item.hasFaults
                                        ? Theme.of(context).colorScheme.error
                                        : Colors.green,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(item.score.toStringAsFixed(1)),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Trabajadores con alerta roja',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: riskyWorkers.map((item) {
                  return SizedBox(
                    width: 320,
                    child: Card(
                      color: const Color(0xFFFDECEC),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                        side: const BorderSide(color: Color(0xFFE19A96)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.employee.name,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(color: const Color(0xFF9E2720)),
                            ),
                            const SizedBox(height: 8),
                            Text('${item.employee.role} - ${item.storeLabel}'),
                            const SizedBox(height: 12),
                            StatusBadge(
                              label:
                                  '${item.review.faultsDetected} faltas detectadas',
                              color: const Color(0xFFB4322A),
                            ),
                            const SizedBox(height: 12),
                            Text(item.review.observations),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  List<_RiskWorker> _riskyWorkers(
    List<Employee> employees,
    List<DailyReview> reviews,
  ) {
    final latestByEmployee = <int, DailyReview>{};
    for (final review in reviews) {
      latestByEmployee.putIfAbsent(review.employeeId, () => review);
    }

    return employees
        .where((employee) => latestByEmployee.containsKey(employee.id))
        .map((employee) => _RiskWorker(employee, latestByEmployee[employee.id]!))
        .where(
          (item) => item.review.faultsDetected > 0 || item.review.traceabilityRisk,
        )
        .toList();
  }

  List<_WorkerScore> _workerScores(
    List<Employee> employees,
    List<DailyReview> reviews,
  ) {
    final latestByEmployee = <int, DailyReview>{};
    for (final review in reviews) {
      latestByEmployee.putIfAbsent(review.employeeId, () => review);
    }

    return employees
        .where((employee) => latestByEmployee.containsKey(employee.id))
        .map(
          (employee) => _WorkerScore(
            employee.name,
            latestByEmployee[employee.id]!.score,
            latestByEmployee[employee.id]!.faultsDetected > 0 ||
                latestByEmployee[employee.id]!.traceabilityRisk,
          ),
        )
        .toList();
  }

  double _averageScoreForStore(String storeCode, List<DailyReview> reviews) {
    final filtered =
        reviews.where((review) => review.storeCode == storeCode).toList();
    if (filtered.isEmpty) {
      return 0;
    }
    final total = filtered.fold<double>(0, (sum, item) => sum + item.score);
    return total / filtered.length;
  }

  bool _isSameDay(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }
}

class _DashboardData {
  const _DashboardData({
    required this.employees,
    required this.payments,
    required this.reviews,
    required this.debts,
    required this.collections,
    required this.reports,
    required this.lines,
    required this.assignments,
  });

  final List<Employee> employees;
  final List<EmployeePayment> payments;
  final List<DailyReview> reviews;
  final List<Debt> debts;
  final List<CollectionRecord> collections;
  final List<ReportCase> reports;
  final List<PhoneLine> lines;
  final List<LineAssignment> assignments;
}

class _RiskWorker {
  const _RiskWorker(this.employee, this.review);

  final Employee employee;
  final DailyReview review;

  String get storeLabel => StoreType.fromCode(employee.storeCode).label;
}

class _WorkerScore {
  const _WorkerScore(this.name, this.score, this.hasFaults);

  final String name;
  final double score;
  final bool hasFaults;
}
