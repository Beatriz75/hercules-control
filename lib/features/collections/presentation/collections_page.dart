import 'package:flutter/material.dart';
import 'package:hercules_control/app/app_scope.dart';
import 'package:hercules_control/core/utils/formatters.dart';
import 'package:hercules_control/core/widgets/app_panel.dart';
import 'package:hercules_control/core/widgets/page_header.dart';
import 'package:hercules_control/domain/entities/collection_record.dart';
import 'package:hercules_control/domain/entities/phone_line.dart';
import 'package:hercules_control/domain/value_objects/store_type.dart';

class CollectionsPage extends StatefulWidget {
  const CollectionsPage({super.key});

  @override
  State<CollectionsPage> createState() => _CollectionsPageState();
}

class _CollectionsPageState extends State<CollectionsPage> {
  late Future<_CollectionsData> _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future = _load();
  }

  Future<_CollectionsData> _load() async {
    final scope = AppScope.of(context);
    return _CollectionsData(
      await scope.collectionRepository.fetchAll(),
      await scope.lineRepository.fetchLines(),
    );
  }

  Future<void> _createCollection(List<PhoneLine> lines) async {
    final customerController = TextEditingController();
    final orderController = TextEditingController();
    final amountController = TextEditingController();
    final validatorController = TextEditingController();
    final notesController = TextEditingController();
    var method = CollectionRecord.methods.first;
    var storeCode = StoreType.pideHoy.name;
    int? lineId = lines.isEmpty ? null : lines.first.id;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Registrar cobro'),
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
                TextField(controller: validatorController, decoration: const InputDecoration(labelText: 'Validado por')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: method,
                  decoration: const InputDecoration(labelText: 'Metodo'),
                  items: CollectionRecord.methods.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
                  onChanged: (value) => method = value ?? method,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: storeCode,
                  decoration: const InputDecoration(labelText: 'Tienda'),
                  items: StoreType.values.map((item) => DropdownMenuItem(value: item.name, child: Text(item.label))).toList(),
                  onChanged: (value) => storeCode = value ?? storeCode,
                ),
                if (lines.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: lineId,
                    decoration: const InputDecoration(labelText: 'Linea usada'),
                    items: lines.map((item) => DropdownMenuItem(value: item.id!, child: Text(item.alias))).toList(),
                    onChanged: (value) => lineId = value,
                  ),
                ],
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

    await AppScope.of(context).collectionRepository.insert(
      CollectionRecord(
        id: null,
        customerName: customerController.text.trim(),
        orderCode: orderController.text.trim(),
        paymentDate: DateTime.now(),
        amount: double.tryParse(amountController.text) ?? 0,
        method: method,
        validatedBy: validatorController.text.trim(),
        storeCode: storeCode,
        notes: notesController.text.trim(),
        lineId: lineId,
      ),
    );

    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_CollectionsData>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!;
        final lineById = {for (final line in data.lines) line.id!: line};

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHeader(
                title: 'Cobros',
                subtitle: 'Registro de pagos recuperados y validacion operativa.',
                action: FilledButton.icon(
                  onPressed: () => _createCollection(data.lines),
                  icon: const Icon(Icons.add_business_rounded),
                  label: const Text('Registrar cobro'),
                ),
              ),
              const SizedBox(height: 24),
              AppPanel(
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Fecha')),
                    DataColumn(label: Text('Cliente')),
                    DataColumn(label: Text('Orden')),
                    DataColumn(label: Text('Monto')),
                    DataColumn(label: Text('Metodo')),
                    DataColumn(label: Text('Validador')),
                    DataColumn(label: Text('Linea')),
                  ],
                  rows: data.collections
                      .map(
                        (item) => DataRow(
                          cells: [
                            DataCell(Text(Formatters.date(item.paymentDate))),
                            DataCell(Text(item.customerName)),
                            DataCell(Text(item.orderCode)),
                            DataCell(Text(Formatters.currency(item.amount))),
                            DataCell(Text(item.method)),
                            DataCell(Text(item.validatedBy)),
                            DataCell(Text(item.lineId == null ? '-' : lineById[item.lineId!]?.alias ?? '-')),
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

class _CollectionsData {
  const _CollectionsData(this.collections, this.lines);

  final List<CollectionRecord> collections;
  final List<PhoneLine> lines;
}
