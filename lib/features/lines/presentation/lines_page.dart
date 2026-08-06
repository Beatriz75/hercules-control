import 'package:flutter/material.dart';
import 'package:hercules_control/app/app_scope.dart';
import 'package:hercules_control/core/utils/formatters.dart';
import 'package:hercules_control/core/widgets/app_panel.dart';
import 'package:hercules_control/core/widgets/page_header.dart';
import 'package:hercules_control/core/widgets/status_badge.dart';
import 'package:hercules_control/domain/entities/employee.dart';
import 'package:hercules_control/domain/entities/line_assignment.dart';
import 'package:hercules_control/domain/entities/phone_line.dart';

class LinesPage extends StatefulWidget {
  const LinesPage({super.key});

  @override
  State<LinesPage> createState() => _LinesPageState();
}

class _LinesPageState extends State<LinesPage> {
  late Future<_LinesData> _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future = _load();
  }

  Future<_LinesData> _load() async {
    final scope = AppScope.of(context);
    return _LinesData(
      await scope.lineRepository.fetchLines(),
      await scope.lineRepository.fetchAssignments(),
      await scope.employeeRepository.fetchAll(),
    );
  }

  Future<void> _createLine() async {
    final numberController = TextEditingController();
    final aliasController = TextEditingController();
    final providerController = TextEditingController();
    final notesController = TextEditingController();
    var status = PhoneLine.statuses.first;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nueva linea'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: numberController,
                decoration: const InputDecoration(
                  labelText: 'Numero telefonico',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: aliasController,
                decoration: const InputDecoration(labelText: 'Alias'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: providerController,
                decoration: const InputDecoration(labelText: 'Proveedor'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: status,
                decoration: const InputDecoration(labelText: 'Estado'),
                items: PhoneLine.statuses
                    .map(
                      (item) =>
                          DropdownMenuItem(value: item, child: Text(item)),
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

    if (saved != true) return;

    if (!mounted) return;

    await AppScope.of(context).lineRepository.insertLine(
      PhoneLine(
        id: null,
        phoneNumber: numberController.text.trim(),
        alias: aliasController.text.trim(),
        status: status,
        provider: providerController.text.trim(),
        createdAt: DateTime.now(),
        notes: notesController.text.trim(),
      ),
    );

    setState(() => _future = _load());
  }

  Future<void> _assignLine(
    List<PhoneLine> lines,
    List<Employee> employees,
  ) async {
    if (lines.isEmpty || employees.isEmpty) return;
    var lineId = lines.first.id!;
    var employeeId = employees.first.id!;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Asignar linea'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: lineId,
                decoration: const InputDecoration(labelText: 'Linea'),
                items: lines
                    .map(
                      (item) => DropdownMenuItem(
                        value: item.id!,
                        child: Text(item.alias),
                      ),
                    )
                    .toList(),
                onChanged: (value) => lineId = value ?? lineId,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: employeeId,
                decoration: const InputDecoration(labelText: 'Empleado'),
                items: employees
                    .where((item) => item.status == 'activo')
                    .map(
                      (item) => DropdownMenuItem(
                        value: item.id!,
                        child: Text(item.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) => employeeId = value ?? employeeId,
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
            child: const Text('Asignar'),
          ),
        ],
      ),
    );

    if (saved != true) return;

    if (!mounted) return;

    await AppScope.of(context).lineRepository.assignLine(
      LineAssignment(
        id: null,
        lineId: lineId,
        employeeId: employeeId,
        assignedAt: DateTime.now(),
        removedAt: null,
        status: 'activa',
      ),
    );

    setState(() => _future = _load());
  }

  Future<void> _retireAssignment(LineAssignment assignment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Retirar linea'),
        content: const Text(
          'La asignacion quedara en el historial como retirada.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Retirar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await AppScope.of(context).lineRepository.retireAssignment(assignment.id!);
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_LinesData>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!;
        final activeAssignments = data.assignments
            .where((item) => item.status == 'activa')
            .toList();
        final lineById = {for (final line in data.lines) line.id!: line};
        final employeeById = {
          for (final employee in data.employees) employee.id!: employee,
        };
        final assignedLineIds = activeAssignments
            .map((item) => item.lineId)
            .toSet();
        final assignedEmployeeIds = activeAssignments
            .map((item) => item.employeeId)
            .toSet();

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHeader(
                title: 'Lineas y WhatsApp Business',
                subtitle:
                    'Control de chips, asignaciones, trazabilidad y exposicion operativa.',
                action: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FilledButton.icon(
                      onPressed: _createLine,
                      icon: const Icon(Icons.add_ic_call_rounded),
                      label: const Text('Nueva linea'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.tonalIcon(
                      onPressed: () => _assignLine(data.lines, data.employees),
                      icon: const Icon(Icons.link_rounded),
                      label: const Text('Asignar'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: AppPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Lineas registradas',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),
                          for (final line in data.lines)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${line.alias} · ${line.phoneNumber}',
                                    ),
                                  ),
                                  StatusBadge(
                                    label: line.status,
                                    color: line.status == 'activa'
                                        ? Colors.green
                                        : line.status == 'bloqueada'
                                        ? Theme.of(context).colorScheme.error
                                        : Colors.orange,
                                  ),
                                ],
                              ),
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
                            'Control operativo',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Lineas sin asignar: ${data.lines.where((item) => !assignedLineIds.contains(item.id)).length}',
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Empleados activos sin linea: ${data.employees.where((item) => item.status == 'activo' && !assignedEmployeeIds.contains(item.id)).length}',
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Asignaciones activas: ${activeAssignments.length}',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              AppPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Historial de asignaciones',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    DataTable(
                      columns: const [
                        DataColumn(label: Text('Linea')),
                        DataColumn(label: Text('Empleado')),
                        DataColumn(label: Text('Asignada')),
                        DataColumn(label: Text('Retiro')),
                        DataColumn(label: Text('Estado')),
                        DataColumn(label: Text('Accion')),
                      ],
                      rows: data.assignments
                          .map(
                            (item) => DataRow(
                              cells: [
                                DataCell(
                                  Text(lineById[item.lineId]?.alias ?? 'N/D'),
                                ),
                                DataCell(
                                  Text(
                                    employeeById[item.employeeId]?.name ??
                                        'N/D',
                                  ),
                                ),
                                DataCell(
                                  Text(Formatters.date(item.assignedAt)),
                                ),
                                DataCell(
                                  Text(
                                    item.removedAt == null
                                        ? '-'
                                        : Formatters.date(item.removedAt!),
                                  ),
                                ),
                                DataCell(
                                  StatusBadge(
                                    label: item.status,
                                    color: item.status == 'activa'
                                        ? Colors.green
                                        : Colors.orange,
                                  ),
                                ),
                                DataCell(
                                  item.status == 'activa'
                                      ? TextButton.icon(
                                          onPressed: () =>
                                              _retireAssignment(item),
                                          icon: const Icon(
                                            Icons.link_off_rounded,
                                          ),
                                          label: const Text('Retirar'),
                                        )
                                      : const Text('-'),
                                ),
                              ],
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LinesData {
  const _LinesData(this.lines, this.assignments, this.employees);

  final List<PhoneLine> lines;
  final List<LineAssignment> assignments;
  final List<Employee> employees;
}
