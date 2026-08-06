import 'package:flutter/material.dart';
import 'package:hercules_control/app/app_scope.dart';
import 'package:hercules_control/core/utils/formatters.dart';
import 'package:hercules_control/core/widgets/app_panel.dart';
import 'package:hercules_control/core/widgets/page_header.dart';
import 'package:hercules_control/core/widgets/status_badge.dart';
import 'package:hercules_control/domain/entities/daily_review.dart';
import 'package:hercules_control/domain/entities/employee.dart';
import 'package:hercules_control/domain/entities/phone_line.dart';
import 'package:hercules_control/domain/value_objects/store_type.dart';

class EmployeesPage extends StatefulWidget {
  const EmployeesPage({super.key});

  @override
  State<EmployeesPage> createState() => _EmployeesPageState();
}

class _EmployeesPageState extends State<EmployeesPage> {
  late Future<_EmployeesData> _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future = _load();
  }

  Future<_EmployeesData> _load() async {
    final scope = AppScope.of(context);
    final employees = await scope.employeeRepository.fetchAll();
    final reviews = await scope.dailyReviewRepository.fetchAll();
    final lines = await scope.lineRepository.fetchLines();
    final currentAssignments =
        await scope.lineRepository.fetchCurrentLineByEmployee();
    return _EmployeesData(employees, reviews, lines, currentAssignments);
  }

  Future<void> _openCreateDialog() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    final roleController = TextEditingController();
    final notesController = TextEditingController();
    var storeCode = StoreType.pideHoy.name;
    var status = Employee.statuses.first;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nuevo empleado'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(labelText: 'Telefono'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Correo'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: roleController,
                  decoration: const InputDecoration(labelText: 'Rol'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: storeCode,
                  decoration: const InputDecoration(labelText: 'Tienda'),
                  items: StoreType.values
                      .map(
                        (item) => DropdownMenuItem(
                          value: item.name,
                          child: Text(item.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => storeCode = value ?? storeCode,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: const InputDecoration(labelText: 'Estado'),
                  items: Employee.statuses
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(item),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => status = value ?? status,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Observaciones'),
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
    );

    if (saved != true) {
      return;
    }

    if (!mounted) {
      return;
    }

    await AppScope.of(context).employeeRepository.insert(
      Employee(
        id: null,
        name: nameController.text.trim(),
        phone: phoneController.text.trim(),
        email: emailController.text.trim(),
        role: roleController.text.trim(),
        storeCode: storeCode,
        hireDate: DateTime.now(),
        terminationDate: null,
        terminationReason: null,
        status: status,
        notes: notesController.text.trim(),
      ),
    );

    setState(() {
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_EmployeesData>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data!;
        final latestByEmployee = <int, DailyReview>{};
        for (final review in data.reviews) {
          latestByEmployee.putIfAbsent(review.employeeId, () => review);
        }

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHeader(
                title: 'Empleados y rotacion',
                subtitle:
                    'Historial permanente de personal, permanencia y riesgo operativo.',
                action: FilledButton.icon(
                  onPressed: _openCreateDialog,
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: const Text('Agregar empleado'),
                ),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: data.employees.map((employee) {
                  final review = latestByEmployee[employee.id];
                  final hasAlert = review != null &&
                      (review.faultsDetected > 0 || review.traceabilityRisk);
                  final lineId = data.currentAssignments[employee.id];
                  PhoneLine? line;
                  if (lineId != null) {
                    for (final item in data.lines) {
                      if (item.id == lineId) {
                        line = item;
                        break;
                      }
                    }
                  }

                  return SizedBox(
                    width: 340,
                    child: Card(
                      color: hasAlert ? const Color(0xFFFDECEC) : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                        side: BorderSide(
                          color: hasAlert
                              ? const Color(0xFFE1A2A0)
                              : const Color(0xFFE3EBF3),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    employee.name,
                                    style:
                                        Theme.of(context).textTheme.titleLarge,
                                  ),
                                ),
                                StatusBadge(
                                  label: employee.status,
                                  color: employee.status == 'activo'
                                      ? Colors.green
                                      : Colors.orange,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${employee.role} - ${StoreType.fromCode(employee.storeCode).label}',
                            ),
                            const SizedBox(height: 8),
                            Text(employee.email),
                            const SizedBox(height: 4),
                            Text(employee.phone),
                            const SizedBox(height: 14),
                            Text(
                              'Ingreso: ${Formatters.date(employee.hireDate)}',
                            ),
                            if (line != null) ...[
                              const SizedBox(height: 4),
                              Text('Linea actual: ${line.alias}'),
                            ],
                            if (review != null) ...[
                              const SizedBox(height: 12),
                              StatusBadge(
                                label: review.faultsDetected > 0
                                    ? '${review.faultsDetected} faltas'
                                    : 'Sin faltas',
                                color: hasAlert
                                    ? Theme.of(context).colorScheme.error
                                    : Colors.green,
                              ),
                              const SizedBox(height: 8),
                              Text(review.observations),
                            ],
                            if (employee.notes.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              AppPanel(
                                padding: const EdgeInsets.all(12),
                                child: Text(employee.notes),
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

class _EmployeesData {
  const _EmployeesData(
    this.employees,
    this.reviews,
    this.lines,
    this.currentAssignments,
  );

  final List<Employee> employees;
  final List<DailyReview> reviews;
  final List<PhoneLine> lines;
  final Map<int, int> currentAssignments;
}
