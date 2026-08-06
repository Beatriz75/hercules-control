import 'package:flutter/material.dart';
import 'package:hercules_control/app/app_scope.dart';
import 'package:hercules_control/core/utils/formatters.dart';
import 'package:hercules_control/core/widgets/page_header.dart';
import 'package:hercules_control/core/widgets/status_badge.dart';
import 'package:hercules_control/domain/entities/employee.dart';
import 'package:hercules_control/domain/entities/phone_line.dart';
import 'package:hercules_control/domain/entities/report_case.dart';
import 'package:hercules_control/domain/value_objects/store_type.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  late Future<_ReportsData> _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future = _load();
  }

  Future<_ReportsData> _load() async {
    final scope = AppScope.of(context);
    return _ReportsData(
      await scope.reportRepository.fetchAll(),
      await scope.employeeRepository.fetchAll(),
      await scope.lineRepository.fetchLines(),
    );
  }

  Future<void> _createReport(List<Employee> employees, List<PhoneLine> lines) async {
    final orderController = TextEditingController();
    final customerController = TextEditingController();
    final descriptionController = TextEditingController();
    final ownerController = TextEditingController();
    var type = ReportCase.types.first;
    var status = ReportCase.statuses.first;
    var priority = ReportCase.priorities[1];
    var storeCode = StoreType.pideHoy.name;
    var traceabilityRisk = false;
    var externalChannel = false;
    int? employeeId = employees.isEmpty ? null : employees.first.id;
    int? lineId = lines.isEmpty ? null : lines.first.id;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Nuevo reporte'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: type,
                    decoration: const InputDecoration(labelText: 'Tipo'),
                    items: ReportCase.types.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
                    onChanged: (value) => type = value ?? type,
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: orderController, decoration: const InputDecoration(labelText: 'Orden')),
                  const SizedBox(height: 12),
                  TextField(controller: customerController, decoration: const InputDecoration(labelText: 'Cliente')),
                  const SizedBox(height: 12),
                  if (employees.isNotEmpty)
                    DropdownButtonFormField<int>(
                      initialValue: employeeId,
                      decoration: const InputDecoration(labelText: 'Empleado'),
                      items: employees.map((item) => DropdownMenuItem(value: item.id!, child: Text(item.name))).toList(),
                      onChanged: (value) => employeeId = value,
                    ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: storeCode,
                    decoration: const InputDecoration(labelText: 'Tienda'),
                    items: StoreType.values.map((item) => DropdownMenuItem(value: item.name, child: Text(item.label))).toList(),
                    onChanged: (value) => storeCode = value ?? storeCode,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    decoration: const InputDecoration(labelText: 'Estado'),
                    items: ReportCase.statuses.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
                    onChanged: (value) => status = value ?? status,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: priority,
                    decoration: const InputDecoration(labelText: 'Prioridad'),
                    items: ReportCase.priorities.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
                    onChanged: (value) => priority = value ?? priority,
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: ownerController, decoration: const InputDecoration(labelText: 'Responsable')),
                  if (lines.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: lineId,
                      decoration: const InputDecoration(labelText: 'Linea relacionada'),
                      items: lines.map((item) => DropdownMenuItem(value: item.id!, child: Text(item.alias))).toList(),
                      onChanged: (value) => lineId = value,
                    ),
                  ],
                  SwitchListTile(
                    value: externalChannel,
                    onChanged: (value) => setDialogState(() => externalChannel = value),
                    title: const Text('Gestion fuera del CRM'),
                  ),
                  SwitchListTile(
                    value: traceabilityRisk,
                    onChanged: (value) => setDialogState(() => traceabilityRisk = value),
                    title: const Text('Falta de contexto verificable'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descriptionController,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Descripcion'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Guardar')),
          ],
        ),
      ),
    );

    if (saved != true) return;

    if (!mounted) return;

    await AppScope.of(context).reportRepository.insert(
      ReportCase(
        id: null,
        type: type,
        orderCode: orderController.text.trim(),
        customerName: customerController.text.trim(),
        employeeId: employeeId,
        storeCode: storeCode,
        reportDate: DateTime.now(),
        description: descriptionController.text.trim(),
        status: status,
        priority: priority,
        owner: ownerController.text.trim(),
        lineId: lineId,
        traceabilityRisk: traceabilityRisk,
        externalChannel: externalChannel,
      ),
    );

    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ReportsData>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!;
        final employeeById = {for (final employee in data.employees) employee.id!: employee.name};
        final lineById = {for (final line in data.lines) line.id!: line.alias};

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHeader(
                title: 'Reportes e incidencias',
                subtitle: 'Registro de roturas, fraude, trazabilidad y problemas operativos.',
                action: FilledButton.icon(
                  onPressed: () => _createReport(data.employees, data.lines),
                  icon: const Icon(Icons.note_add_rounded),
                  label: const Text('Nuevo reporte'),
                ),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: data.reports.map((report) {
                  final isCritical = report.priority == 'critica' || report.traceabilityRisk;
                  return SizedBox(
                    width: 360,
                    child: Card(
                      color: isCritical ? const Color(0xFFFFF1F0) : Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    report.type,
                                    style: Theme.of(context).textTheme.titleLarge,
                                  ),
                                ),
                                StatusBadge(
                                  label: report.priority,
                                  color: isCritical
                                      ? Theme.of(context).colorScheme.error
                                      : Colors.orange,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('${report.orderCode} · ${report.customerName}'),
                            const SizedBox(height: 8),
                            Text('Fecha: ${Formatters.date(report.reportDate)}'),
                            Text('Estado: ${report.status}'),
                            Text('Tienda: ${StoreType.fromCode(report.storeCode).label}'),
                            Text('Responsable: ${report.owner}'),
                            if (report.employeeId != null)
                              Text('Empleado: ${employeeById[report.employeeId!] ?? 'N/D'}'),
                            if (report.lineId != null)
                              Text('Linea: ${lineById[report.lineId!] ?? '-'}'),
                            const SizedBox(height: 12),
                            Text(report.description),
                            if (report.externalChannel || report.traceabilityRisk) ...[
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                children: [
                                  if (report.externalChannel)
                                    const StatusBadge(
                                      label: 'Canal externo',
                                      color: Colors.orange,
                                    ),
                                  if (report.traceabilityRisk)
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

class _ReportsData {
  const _ReportsData(this.reports, this.employees, this.lines);

  final List<ReportCase> reports;
  final List<Employee> employees;
  final List<PhoneLine> lines;
}
