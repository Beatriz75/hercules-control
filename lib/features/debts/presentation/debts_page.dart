import 'package:flutter/material.dart';
import 'package:hercules_control/app/app_scope.dart';
import 'package:hercules_control/core/utils/formatters.dart';
import 'package:hercules_control/core/widgets/app_panel.dart';
import 'package:hercules_control/core/widgets/page_header.dart';
import 'package:hercules_control/core/widgets/status_badge.dart';
import 'package:hercules_control/domain/entities/debt.dart';
import 'package:hercules_control/domain/value_objects/store_type.dart';

class DebtsPage extends StatefulWidget {
  const DebtsPage({super.key});

  @override
  State<DebtsPage> createState() => _DebtsPageState();
}

class _DebtsPageState extends State<DebtsPage> {
  late Future<List<Debt>> _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future = AppScope.of(context).debtRepository.fetchAll();
  }

  Future<void> _createDebt() async {
    final customerController = TextEditingController();
    final orderController = TextEditingController();
    final amountController = TextEditingController();
    final responsibleController = TextEditingController();
    final notesController = TextEditingController();
    var status = Debt.statuses.first;
    var storeCode = StoreType.pideHoy.name;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nueva deuda'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextField(controller: customerController, decoration: const InputDecoration(labelText: 'Cliente')),
                const SizedBox(height: 12),
                TextField(controller: orderController, decoration: const InputDecoration(labelText: 'Orden')),
                const SizedBox(height: 12),
                TextField(controller: amountController, decoration: const InputDecoration(labelText: 'Monto'), keyboardType: TextInputType.number),
                const SizedBox(height: 12),
                TextField(controller: responsibleController, decoration: const InputDecoration(labelText: 'Responsable')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: const InputDecoration(labelText: 'Estado'),
                  items: Debt.statuses.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
                  onChanged: (value) => status = value ?? status,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: storeCode,
                  decoration: const InputDecoration(labelText: 'Tienda'),
                  items: StoreType.values.map((item) => DropdownMenuItem(value: item.name, child: Text(item.label))).toList(),
                  onChanged: (value) => storeCode = value ?? storeCode,
                ),
                const SizedBox(height: 12),
                TextField(controller: notesController, maxLines: 3, decoration: const InputDecoration(labelText: 'Observaciones')),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Guardar')),
        ],
      ),
    );

    if (saved != true) return;

    if (!mounted) return;

    await AppScope.of(context).debtRepository.insert(
      Debt(
        id: null,
        customerName: customerController.text.trim(),
        orderCode: orderController.text.trim(),
        deliveryDate: DateTime.now(),
        dueDate: DateTime.now().add(const Duration(days: 1)),
        amount: double.tryParse(amountController.text) ?? 0,
        status: status,
        responsible: responsibleController.text.trim(),
        storeCode: storeCode,
        notes: notesController.text.trim(),
      ),
    );

    setState(() => _future = AppScope.of(context).debtRepository.fetchAll());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Debt>>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final debts = snapshot.data!;
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHeader(
                title: 'Deudas de clientes',
                subtitle: 'Seguimiento de clientes con pago diferido a 24 horas.',
                action: FilledButton.icon(
                  onPressed: _createDebt,
                  icon: const Icon(Icons.playlist_add_rounded),
                  label: const Text('Nueva deuda'),
                ),
              ),
              const SizedBox(height: 24),
              AppPanel(
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Cliente')),
                    DataColumn(label: Text('Orden')),
                    DataColumn(label: Text('Entrega')),
                    DataColumn(label: Text('Limite')),
                    DataColumn(label: Text('Monto')),
                    DataColumn(label: Text('Estado')),
                    DataColumn(label: Text('Responsable')),
                    DataColumn(label: Text('Tienda')),
                  ],
                  rows: debts
                      .map(
                        (item) => DataRow(
                          cells: [
                            DataCell(Text(item.customerName)),
                            DataCell(Text(item.orderCode)),
                            DataCell(Text(Formatters.date(item.deliveryDate))),
                            DataCell(Text(Formatters.date(item.dueDate))),
                            DataCell(Text(Formatters.currency(item.amount))),
                            DataCell(
                              StatusBadge(
                                label: item.status,
                                color: item.status == 'pagado'
                                    ? Colors.green
                                    : item.status == 'fraude sospechado'
                                        ? Theme.of(context).colorScheme.error
                                        : Colors.orange,
                              ),
                            ),
                            DataCell(Text(item.responsible)),
                            DataCell(Text(StoreType.fromCode(item.storeCode).label)),
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
