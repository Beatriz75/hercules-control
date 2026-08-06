import 'package:flutter/material.dart';
import 'package:hercules_control/app/app_scope.dart';
import 'package:hercules_control/core/utils/formatters.dart';
import 'package:hercules_control/core/widgets/app_panel.dart';
import 'package:hercules_control/core/widgets/page_header.dart';
import 'package:hercules_control/domain/entities/employee.dart';
import 'package:hercules_control/domain/entities/employee_payment.dart';

class EmployeePaymentsPage extends StatefulWidget {
  const EmployeePaymentsPage({super.key});

  @override
  State<EmployeePaymentsPage> createState() => _EmployeePaymentsPageState();
}

class _EmployeePaymentsPageState extends State<EmployeePaymentsPage> {
  late Future<_EmployeePaymentsData> _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future = _load();
  }

  Future<_EmployeePaymentsData> _load() async {
    final scope = AppScope.of(context);
    final employees = await scope.employeeRepository.fetchAll();
    final payments = await scope.employeePaymentRepository.fetchAll();
    return _EmployeePaymentsData(employees, payments);
  }

  Future<void> _createPayment(List<Employee> employees) async {
    if (employees.isEmpty) {
      return;
    }
    var employeeId = employees.first.id!;
    var method = EmployeePayment.paymentMethods.first;
    final amountController = TextEditingController();
    final conceptController = TextEditingController();
    final notesController = TextEditingController();

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Registrar pago'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: employeeId,
                decoration: const InputDecoration(labelText: 'Empleado'),
                items: employees
                    .map(
                      (item) => DropdownMenuItem(
                        value: item.id!,
                        child: Text(item.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) => employeeId = value ?? employeeId,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                decoration: const InputDecoration(labelText: 'Monto'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: conceptController,
                decoration: const InputDecoration(labelText: 'Concepto'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: method,
                decoration: const InputDecoration(labelText: 'Metodo'),
                items: EmployeePayment.paymentMethods
                    .map(
                      (item) => DropdownMenuItem(
                        value: item,
                        child: Text(item),
                      ),
                    )
                    .toList(),
                onChanged: (value) => method = value ?? method,
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

    await AppScope.of(context).employeePaymentRepository.insert(
      EmployeePayment(
        id: null,
        employeeId: employeeId,
        paymentDate: DateTime.now(),
        amount: double.tryParse(amountController.text) ?? 0,
        concept: conceptController.text.trim(),
        paymentMethod: method,
        notes: notesController.text.trim(),
      ),
    );

    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_EmployeePaymentsData>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!;
        final employeeNameById = {
          for (final employee in data.employees) employee.id!: employee.name,
        };

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHeader(
                title: 'Pagos a empleados',
                subtitle: 'Control de bonos, comisiones y pagos operativos.',
                action: FilledButton.icon(
                  onPressed: () => _createPayment(data.employees),
                  icon: const Icon(Icons.add_card_rounded),
                  label: const Text('Registrar pago'),
                ),
              ),
              const SizedBox(height: 24),
              AppPanel(
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Fecha')),
                    DataColumn(label: Text('Empleado')),
                    DataColumn(label: Text('Monto')),
                    DataColumn(label: Text('Concepto')),
                    DataColumn(label: Text('Metodo')),
                    DataColumn(label: Text('Observaciones')),
                  ],
                  rows: data.payments
                      .map(
                        (item) => DataRow(
                          cells: [
                            DataCell(Text(Formatters.date(item.paymentDate))),
                            DataCell(Text(employeeNameById[item.employeeId] ?? 'N/D')),
                            DataCell(Text(Formatters.currency(item.amount))),
                            DataCell(Text(item.concept)),
                            DataCell(Text(item.paymentMethod)),
                            DataCell(Text(item.notes)),
                          ],
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EmployeePaymentsData {
  const _EmployeePaymentsData(this.employees, this.payments);

  final List<Employee> employees;
  final List<EmployeePayment> payments;
}
