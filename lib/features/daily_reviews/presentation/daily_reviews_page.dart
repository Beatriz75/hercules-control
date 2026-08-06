import 'package:flutter/material.dart';
import 'package:hercules_control/app/app_scope.dart';
import 'package:hercules_control/core/utils/formatters.dart';
import 'package:hercules_control/core/widgets/page_header.dart';
import 'package:hercules_control/core/widgets/status_badge.dart';
import 'package:hercules_control/domain/entities/daily_review.dart';
import 'package:hercules_control/domain/entities/employee.dart';
import 'package:hercules_control/domain/value_objects/store_type.dart';

class DailyReviewsPage extends StatefulWidget {
  const DailyReviewsPage({super.key});

  @override
  State<DailyReviewsPage> createState() => _DailyReviewsPageState();
}

class _DailyReviewsPageState extends State<DailyReviewsPage> {
  late Future<_DailyReviewsData> _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future = _load();
  }

  Future<_DailyReviewsData> _load() async {
    final scope = AppScope.of(context);
    final employees = await scope.employeeRepository.fetchAll();
    final reviews = await scope.dailyReviewRepository.fetchAll();
    return _DailyReviewsData(employees, reviews);
  }

  Future<void> _createReview(List<Employee> employees) async {
    if (employees.isEmpty) {
      return;
    }

    var employeeId = employees.first.id!;
    var storeCode = employees.first.storeCode;
    var usedWhatsApp = false;
    var traceabilityRisk = false;
    final supervisorController = TextEditingController();
    final leadsController = TextEditingController(text: '5');
    final responseController = TextEditingController(text: '20');
    final treatmentController = TextEditingController(text: '4.5');
    final faultsController = TextEditingController(text: '0');
    final scoreController = TextEditingController(text: '90');
    final observationsController = TextEditingController();
    final extraController = TextEditingController();

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Nueva evaluacion diaria'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: employeeId,
                    decoration: const InputDecoration(labelText: 'Trabajador'),
                    items: employees
                        .map(
                          (item) => DropdownMenuItem(
                            value: item.id!,
                            child: Text(item.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      final selected = employees.firstWhere((item) => item.id == value);
                      setDialogState(() {
                        employeeId = selected.id!;
                        storeCode = selected.storeCode;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: supervisorController,
                    decoration: const InputDecoration(labelText: 'Encargado'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: leadsController,
                    decoration: const InputDecoration(labelText: 'Leads revisados'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: responseController,
                    decoration: const InputDecoration(labelText: 'Tiempo de respuesta promedio'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: treatmentController,
                    decoration: const InputDecoration(labelText: 'Calificacion trato cliente'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: faultsController,
                    decoration: const InputDecoration(labelText: 'Faltas detectadas'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: scoreController,
                    decoration: const InputDecoration(labelText: 'Score'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    value: usedWhatsApp,
                    onChanged: (value) => setDialogState(() => usedWhatsApp = value),
                    title: const Text('Uso de WhatsApp Business'),
                  ),
                  SwitchListTile(
                    value: traceabilityRisk,
                    onChanged: (value) =>
                        setDialogState(() => traceabilityRisk = value),
                    title: const Text('Riesgo por falta de trazabilidad'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: observationsController,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Observaciones'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: extraController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Criterios adicionales',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    if (saved != true) {
      return;
    }

    if (!mounted) {
      return;
    }

    await AppScope.of(context).dailyReviewRepository.insert(
      DailyReview(
        id: null,
        reviewDate: DateTime.now(),
        employeeId: employeeId,
        storeCode: storeCode,
        supervisorName: supervisorController.text.trim(),
        leadsReviewed: int.tryParse(leadsController.text) ?? 0,
        avgResponseMinutes: double.tryParse(responseController.text) ?? 0,
        customerTreatmentScore: double.tryParse(treatmentController.text) ?? 0,
        faultsDetected: int.tryParse(faultsController.text) ?? 0,
        observations: observationsController.text.trim(),
        score: double.tryParse(scoreController.text) ?? 0,
        usedWhatsApp: usedWhatsApp,
        traceabilityRisk: traceabilityRisk,
        additionalCriteria: extraController.text.trim(),
      ),
    );

    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_DailyReviewsData>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!;
        final employeeById = {
          for (final employee in data.employees) employee.id!: employee,
        };

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHeader(
                title: 'Estadisticas diarias',
                subtitle:
                    'Evaluacion muestral del desempeno, trato al cliente y riesgo de trazabilidad.',
                action: FilledButton.icon(
                  onPressed: () => _createReview(data.employees),
                  icon: const Icon(Icons.playlist_add_check_circle_rounded),
                  label: const Text('Nueva evaluacion'),
                ),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: data.reviews.map((review) {
                  final employee = employeeById[review.employeeId];
                  final hasAlert = review.faultsDetected > 0 || review.traceabilityRisk;
                  return SizedBox(
                    width: 360,
                    child: Card(
                      color: hasAlert ? const Color(0xFFFDECEC) : Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    employee?.name ?? 'Trabajador',
                                    style: Theme.of(context).textTheme.titleLarge,
                                  ),
                                ),
                                StatusBadge(
                                  label: review.faultsDetected > 0 ? 'Alerta' : 'Correcto',
                                  color: hasAlert
                                      ? Theme.of(context).colorScheme.error
                                      : Colors.green,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${Formatters.date(review.reviewDate)} · ${StoreType.fromCode(review.storeCode).label}',
                            ),
                            const SizedBox(height: 12),
                            Text('Encargado: ${review.supervisorName}'),
                            Text('Leads revisados: ${review.leadsReviewed}'),
                            Text('Tiempo respuesta: ${review.avgResponseMinutes} min'),
                            Text('Trato cliente: ${review.customerTreatmentScore}'),
                            Text('Score: ${review.score}'),
                            const SizedBox(height: 12),
                            Text(review.observations),
                            if (review.usedWhatsApp || review.traceabilityRisk) ...[
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  if (review.usedWhatsApp)
                                    const StatusBadge(
                                      label: 'WhatsApp Business',
                                      color: Colors.orange,
                                    ),
                                  if (review.traceabilityRisk)
                                    StatusBadge(
                                      label: 'Riesgo de trazabilidad',
                                      color: Theme.of(context).colorScheme.error,
                                    ),
                                ],
                              ),
                            ],
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
}

class _DailyReviewsData {
  const _DailyReviewsData(this.employees, this.reviews);

  final List<Employee> employees;
  final List<DailyReview> reviews;
}
