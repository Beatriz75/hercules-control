import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hercules_control/app/app_scope.dart';
import 'package:hercules_control/core/utils/formatters.dart';
import 'package:hercules_control/core/widgets/app_panel.dart';
import 'package:hercules_control/core/widgets/multi_line_chart.dart';
import 'package:hercules_control/core/widgets/page_header.dart';
import 'package:hercules_control/core/widgets/status_badge.dart';
import 'package:hercules_control/domain/entities/weekly_report_bundle.dart';
import 'package:hercules_control/domain/entities/weekly_report_day.dart';
import 'package:hercules_control/domain/value_objects/store_type.dart';

Future<String?> _showWeeklyImportDialog(BuildContext context) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Importar tabla semanal'),
      content: SizedBox(
        width: 760,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Copia desde Excel/Sheets las columnas: Fecha, Entregado total, Pagado entregados, Pagado nivel 3, Reportes, Devoluciones, Deudores y Deudores Ali.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              minLines: 10,
              maxLines: 14,
              decoration: const InputDecoration(
                hintText:
                    'Pega aqui la tabla limpia. Si la primera columna trae fecha, puedo crear el corte automaticamente.',
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: () async {
            final data = await Clipboard.getData(Clipboard.kTextPlain);
            controller.text = data?.text ?? '';
          },
          icon: const Icon(Icons.content_paste_rounded),
          label: const Text('Pegar portapapeles'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(controller.text),
          child: const Text('Importar'),
        ),
      ],
    ),
  );
}

class WeeklyReportsPage extends StatefulWidget {
  const WeeklyReportsPage({super.key});

  @override
  State<WeeklyReportsPage> createState() => _WeeklyReportsPageState();
}

class _WeeklyReportsPageState extends State<WeeklyReportsPage> {
  late Future<_WeeklyReportsData> _future;
  int? _selectedReportId;
  String _selectedStoreCode = StoreType.pideHoy.name;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future = _loadReports();
  }

  Future<_WeeklyReportsData> _loadReports() async {
    final repository = AppScope.of(context).weeklyReportRepository;
    final stores = await repository.fetchStores();
    final reports = await repository.fetchAll();
    return _WeeklyReportsData(reports: reports, stores: stores);
  }

  Future<void> _createReport() async {
    final now = DateTime.now();
    final initialDate = now.subtract(Duration(days: now.weekday - 1));
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
      initialDate: initialDate,
      helpText: 'Selecciona el lunes de la semana',
    );
    if (selected == null || !mounted) {
      return;
    }

    final store = StoreType.fromCode(_selectedStoreCode);
    final report = await AppScope.of(
      context,
    ).weeklyReportRepository.createReport(startDate: selected, store: store);
    setState(() {
      _selectedReportId = report.report.id;
      _future = _loadReports();
    });
  }

  Future<void> _saveDays(
    WeeklyReportBundle report,
    List<WeeklyReportDay> days,
  ) async {
    await AppScope.of(
      context,
    ).weeklyReportRepository.saveDays(report.report.id!, days);
    setState(() => _future = _loadReports());
  }

  Future<void> _closeReport(WeeklyReportBundle report) async {
    if (!report.isBalanced) {
      final difference = report.difference;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('No se puede cerrar'),
          content: Text(
            'Aun hay una diferencia de $difference registros. '
            'Revisa los filtros y descontamina la data en Excel para que cuadre.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      return;
    }

    await AppScope.of(
      context,
    ).weeklyReportRepository.closeReport(report.report.id!);
    setState(() => _future = _loadReports());
  }

  Future<void> _changeReportDates(WeeklyReportBundle report) async {
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
      initialDate: report.report.startDate,
      helpText: 'Selecciona el nuevo lunes del corte',
    );
    if (selected == null || !mounted) {
      return;
    }

    await AppScope.of(context).weeklyReportRepository.updateReportDates(
      report: report,
      startDate: selected,
    );
    setState(() => _future = _loadReports());
  }

  Future<void> _deleteReport(WeeklyReportBundle report) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar reporte semanal'),
        content: Text(
          'Esto eliminara el corte ${report.report.title}, sus 7 dias y sus criterios personalizados. '
          'Si necesitas rehacerlo desde cero, podras crear otro corte despues.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    await AppScope.of(
      context,
    ).weeklyReportRepository.deleteReport(report.report.id!);
    setState(() {
      _selectedReportId = null;
      _future = _loadReports();
    });
  }

  Future<void> _addCriterion(WeeklyReportBundle report) async {
    final nameController = TextEditingController();
    final valueController = TextEditingController();
    final notesController = TextEditingController();

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nuevo criterio personalizado'),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: valueController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Valor %'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Notas'),
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
            child: const Text('Agregar'),
          ),
        ],
      ),
    );

    if (saved != true || !mounted) {
      return;
    }

    await AppScope.of(context).weeklyReportRepository.addCustomCriterion(
      reportId: report.report.id!,
      name: nameController.text.trim(),
      value: double.tryParse(valueController.text.trim()) ?? 0,
      notes: notesController.text.trim(),
    );
    setState(() => _future = _loadReports());
  }

  Future<void> _addStore() async {
    final controller = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nueva tienda'),
        content: SizedBox(
          width: 420,
          child: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Nombre de tienda'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Agregar'),
          ),
        ],
      ),
    );

    if (saved != true || !mounted) {
      return;
    }

    try {
      final store = await AppScope.of(
        context,
      ).weeklyReportRepository.addStore(controller.text);
      setState(() {
        _selectedStoreCode = store.name;
        _selectedReportId = null;
        _future = _loadReports();
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('No se pudo agregar'),
          content: const Text(
            'Revisa que el nombre no este vacio y que la tienda no exista ya.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_WeeklyReportsData>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data!;
        final reports = data.reports;
        final stores = data.stores;
        if (!stores.any((store) => store.name == _selectedStoreCode)) {
          _selectedStoreCode = stores.first.name;
        }
        final activeStore = stores.firstWhere(
          (store) => store.name == _selectedStoreCode,
          orElse: () => StoreType.fromCode(_selectedStoreCode),
        );
        final storeReports = reports.where((report) {
          return report.report.storeCode == _selectedStoreCode;
        }).toList();

        WeeklyReportBundle? selectedReport;
        for (final report in storeReports) {
          if (report.report.id == _selectedReportId) {
            selectedReport = report;
          }
        }
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHeader(
                title: 'Estadisticas semanales',
                subtitle:
                    'Captura manual limpia por tienda. Todas manejan la misma estructura.',
              ),
              const SizedBox(height: 24),
              _StoreSelectorPanel(
                stores: stores,
                selectedStoreCode: _selectedStoreCode,
                onChanged: (storeCode) {
                  setState(() {
                    _selectedStoreCode = storeCode;
                    _selectedReportId = null;
                  });
                },
                onAddStore: _addStore,
              ),
              const SizedBox(height: 24),
              if (storeReports.isEmpty)
                _EmptyStoreReportsPanel(
                  store: activeStore,
                  onCreateReport: _createReport,
                )
              else ...[
                _HistorySelector(
                  reports: storeReports,
                  selectedReportId: _selectedReportId,
                  store: activeStore,
                  onCreateReport: _createReport,
                  onSelected: (reportId) {
                    setState(() => _selectedReportId = reportId);
                  },
                  onChangeDates: _changeReportDates,
                  onDelete: _deleteReport,
                ),
                const SizedBox(height: 24),
                if (selectedReport == null)
                  const _SelectReportPrompt()
                else
                  _WeeklyReportDetail(
                    key: ValueKey(selectedReport.report.id),
                    report: selectedReport,
                    allReports: storeReports,
                    onSave: (days) => _saveDays(selectedReport!, days),
                    onClose: () => _closeReport(selectedReport!),
                    onChangeDates: () => _changeReportDates(selectedReport!),
                    onDelete: () => _deleteReport(selectedReport!),
                    onAddCriterion: () => _addCriterion(selectedReport!),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _EmptyStoreReportsPanel extends StatelessWidget {
  const _EmptyStoreReportsPanel({
    required this.store,
    required this.onCreateReport,
  });

  final StoreType store;
  final VoidCallback onCreateReport;

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              Icons.calendar_month_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Aun no hay reportes semanales para ${store.label}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                const Text(
                  'Crea el primer corte para abrir su panel de edicion. Desde ahi podras llenarlo manualmente o importar una tabla limpia.',
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          FilledButton.icon(
            onPressed: onCreateReport,
            icon: const Icon(Icons.add_chart_rounded),
            label: Text('Crear corte ${store.label}'),
          ),
        ],
      ),
    );
  }
}

class _WeeklyReportsData {
  const _WeeklyReportsData({required this.reports, required this.stores});

  final List<WeeklyReportBundle> reports;
  final List<StoreType> stores;
}

class _StoreSelectorPanel extends StatelessWidget {
  const _StoreSelectorPanel({
    required this.stores,
    required this.selectedStoreCode,
    required this.onChanged,
    required this.onAddStore,
  });

  final List<StoreType> stores;
  final String selectedStoreCode;
  final ValueChanged<String> onChanged;
  final VoidCallback onAddStore;

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tienda activa',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                const Text(
                  'Abre las estadisticas de cada tienda por separado. Si agregas otra tienda al catalogo, usara esta misma estructura.',
                ),
              ],
            ),
          ),
          const SizedBox(width: 28),
          SizedBox(
            width: 360,
            child: DropdownButtonFormField<String>(
              initialValue: selectedStoreCode,
              decoration: const InputDecoration(labelText: 'Ver tienda'),
              items: stores.map((store) {
                return DropdownMenuItem(
                  value: store.name,
                  child: Text(store.label),
                );
              }).toList(),
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                onChanged(value);
              },
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.tonalIcon(
            onPressed: onAddStore,
            icon: const Icon(Icons.add_business_rounded),
            label: const Text('Agregar tienda'),
          ),
        ],
      ),
    );
  }
}

class _HistorySelector extends StatelessWidget {
  const _HistorySelector({
    required this.reports,
    required this.selectedReportId,
    required this.store,
    required this.onCreateReport,
    required this.onSelected,
    required this.onChangeDates,
    required this.onDelete,
  });

  final List<WeeklyReportBundle> reports;
  final int? selectedReportId;
  final StoreType store;
  final VoidCallback onCreateReport;
  final ValueChanged<int> onSelected;
  final ValueChanged<WeeklyReportBundle> onChangeDates;
  final ValueChanged<WeeklyReportBundle> onDelete;

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Cortes semanales de ${store.label}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              FilledButton.icon(
                onPressed: onCreateReport,
                icon: const Icon(Icons.add_chart_rounded),
                label: const Text('Nuevo corte'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Cada corte es una tarjeta. Toca una para abrir su panel de edicion, importar tabla, cambiar fechas o eliminar.',
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: reports.map((report) {
              final selected = report.report.id == selectedReportId;
              return _WeeklyReportCard(
                report: report,
                selected: selected,
                onTap: () => onSelected(report.report.id!),
                onChangeDates: () => onChangeDates(report),
                onDelete: () => onDelete(report),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _WeeklyReportCard extends StatelessWidget {
  const _WeeklyReportCard({
    required this.report,
    required this.selected,
    required this.onTap,
    required this.onChangeDates,
    required this.onDelete,
  });

  final WeeklyReportBundle report;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onChangeDates;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final difference = report.difference;
    final borderColor = selected
        ? colorScheme.primary
        : difference == 0
        ? const Color(0xFFE0E6EF)
        : colorScheme.error.withValues(alpha: 0.45);
    final background = selected
        ? colorScheme.primary.withValues(alpha: 0.08)
        : Colors.white;

    return SizedBox(
      width: 330,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: borderColor, width: selected ? 2 : 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${Formatters.date(report.report.startDate)} - ${Formatters.date(report.report.endDate)}',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'Acciones del corte',
                      onSelected: (value) {
                        if (value == 'dates') {
                          onChangeDates();
                        }
                        if (value == 'delete') {
                          onDelete();
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'dates',
                          child: Text('Cambiar fechas'),
                        ),
                        PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  selected
                      ? 'Abierto para editar datos'
                      : 'Toca para modificar datos',
                  style: TextStyle(
                    color: selected ? colorScheme.primary : Colors.blueGrey,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _ReportCardMetric(
                        label: 'Entregado',
                        value: '${report.deliveredTotal}',
                      ),
                    ),
                    Expanded(
                      child: _ReportCardMetric(
                        label: 'Cobro',
                        value: '${report.totalPaidPercent.toStringAsFixed(1)}%',
                      ),
                    ),
                    Expanded(
                      child: _ReportCardMetric(
                        label: 'Dif.',
                        value: '$difference',
                        alert: difference != 0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                StatusBadge(
                  label: report.report.status,
                  color: report.report.isClosed ? Colors.green : Colors.orange,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReportCardMetric extends StatelessWidget {
  const _ReportCardMetric({
    required this.label,
    required this.value,
    this.alert = false,
  });

  final String label;
  final String value;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: alert ? Theme.of(context).colorScheme.error : null,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _SelectReportPrompt extends StatelessWidget {
  const _SelectReportPrompt();

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              Icons.touch_app_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 18),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Selecciona una tarjeta para editar',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 6),
                Text(
                  'El formulario de captura solo aparece dentro del corte seleccionado. Desde ahi puedes editar manualmente o importar datos.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyReportDetail extends StatefulWidget {
  const _WeeklyReportDetail({
    super.key,
    required this.report,
    required this.allReports,
    required this.onSave,
    required this.onClose,
    required this.onChangeDates,
    required this.onDelete,
    required this.onAddCriterion,
  });

  final WeeklyReportBundle report;
  final List<WeeklyReportBundle> allReports;
  final ValueChanged<List<WeeklyReportDay>> onSave;
  final VoidCallback onClose;
  final VoidCallback onChangeDates;
  final VoidCallback onDelete;
  final VoidCallback onAddCriterion;

  @override
  State<_WeeklyReportDetail> createState() => _WeeklyReportDetailState();
}

class _WeeklyReportDetailState extends State<_WeeklyReportDetail> {
  late List<_DayDraft> _drafts;
  int _lastImportedRows = 0;
  bool _hasPendingImport = false;

  @override
  void initState() {
    super.initState();
    _drafts = widget.report.days.map(_DayDraft.fromDay).toList();
  }

  @override
  Widget build(BuildContext context) {
    final current = _bundleFromDrafts();
    final difference = current.difference;
    final hasDifference = difference != 0;
    final previousReport = _previousReport();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.report.report.title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            StatusBadge(
              label: widget.report.report.storeLabel,
              color: Colors.blue,
            ),
            const SizedBox(width: 12),
            StatusBadge(
              label: widget.report.report.status,
              color: widget.report.report.isClosed
                  ? Colors.green
                  : Colors.orange,
            ),
            const SizedBox(width: 12),
            FilledButton.tonalIcon(
              onPressed: _importTable,
              icon: Icon(
                _hasPendingImport
                    ? Icons.check_circle_rounded
                    : Icons.table_view_rounded,
              ),
              label: Text(
                _hasPendingImport
                    ? 'Importado: $_lastImportedRows sin guardar'
                    : 'Importar tabla',
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.tonalIcon(
              onPressed: widget.onChangeDates,
              icon: const Icon(Icons.edit_calendar_rounded),
              label: const Text('Cambiar fechas'),
            ),
            const SizedBox(width: 12),
            FilledButton.tonalIcon(
              onPressed: widget.onDelete,
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Eliminar'),
            ),
            const SizedBox(width: 12),
            FilledButton.tonalIcon(
              onPressed: () {
                widget.onSave(_drafts.map((draft) => draft.toDay()).toList());
                setState(() => _hasPendingImport = false);
              },
              icon: const Icon(Icons.save_rounded),
              label: const Text('Guardar'),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: widget.onClose,
              icon: const Icon(Icons.lock_rounded),
              label: const Text('Cerrar'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_hasPendingImport) ...[
          _ImportAppliedNotice(rows: _lastImportedRows),
          const SizedBox(height: 16),
        ],
        if (hasDifference)
          _BalanceAlert(difference: difference)
        else
          const _BalancedMessage(),
        const SizedBox(height: 16),
        _WeeklyEntryTable(
          drafts: _drafts,
          importedRows: _hasPendingImport ? _lastImportedRows : 0,
          onChanged: () => setState(() {}),
        ),
        const SizedBox(height: 24),
        _PercentPanel(report: current, previousReport: previousReport),
        const SizedBox(height: 24),
        _ComparisonPanel(reports: widget.allReports),
        const SizedBox(height: 24),
        _CustomCriteriaPanel(
          report: widget.report,
          onAddCriterion: widget.onAddCriterion,
        ),
      ],
    );
  }

  WeeklyReportBundle _bundleFromDrafts() {
    return WeeklyReportBundle(
      report: widget.report.report,
      days: _drafts.map((draft) => draft.toDay()).toList(),
      customCriteria: widget.report.customCriteria,
    );
  }

  WeeklyReportBundle? _previousReport() {
    final currentStart = widget.report.report.startDate;
    final olderReports =
        widget.allReports
            .where((report) => report.report.startDate.isBefore(currentStart))
            .where((report) {
              return report.report.storeCode == widget.report.report.storeCode;
            })
            .toList()
          ..sort((left, right) {
            return right.report.startDate.compareTo(left.report.startDate);
          });

    if (olderReports.isEmpty) {
      return null;
    }
    return olderReports.first;
  }

  Future<void> _importTable() async {
    final imported = await _showWeeklyImportDialog(context);

    if (imported == null || imported.trim().isEmpty || !mounted) {
      return;
    }

    final rows = _WeeklyImportParser.parseRows(imported);
    if (rows.isEmpty) {
      setState(() {
        _lastImportedRows = 0;
        _hasPendingImport = false;
      });
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('No se pudo leer la tabla'),
          content: const Text(
            'Revisa que la tabla tenga 7 columnas numericas: entregado, pagado entregados, pagado nivel 3, reportes, devoluciones, deudores y deudores Ali.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      return;
    }

    final appliedRows = rows.length > _drafts.length
        ? _drafts.length
        : rows.length;
    setState(() {
      for (
        var index = 0;
        index < rows.length && index < _drafts.length;
        index++
      ) {
        rows[index].applyTo(_drafts[index]);
      }
      _lastImportedRows = appliedRows;
      _hasPendingImport = appliedRows > 0;
    });

    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
        content: Text(
          'Importacion aplicada: $appliedRows filas llenadas. Revisa el cuadre y presiona Guardar.',
        ),
      ),
    );
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Importacion aplicada'),
        content: Text(
          '$appliedRows filas fueron cargadas en la tabla del corte.\n\n'
          'Ahora revisa el cuadre. Si esta correcto, presiona Guardar para dejarlo registrado.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Ver tabla'),
          ),
        ],
      ),
    );
  }
}

class _ImportAppliedNotice extends StatelessWidget {
  const _ImportAppliedNotice({required this.rows});

  final int rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          const Icon(Icons.table_view_rounded, color: Colors.blue),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Importacion aplicada en $rows filas. Las filas resaltadas vienen de la tabla pegada. Revisa el cuadre y presiona Guardar.',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyEntryTable extends StatelessWidget {
  const _WeeklyEntryTable({
    required this.drafts,
    required this.importedRows,
    required this.onChanged,
  });

  final List<_DayDraft> drafts;
  final int importedRows;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Fecha')),
            DataColumn(label: Text('Entregado total')),
            DataColumn(label: Text('Pagado entregados')),
            DataColumn(label: Text('Pagado nivel 3')),
            DataColumn(label: Text('Reportes')),
            DataColumn(label: Text('Devoluciones')),
            DataColumn(label: Text('Deudores')),
            DataColumn(label: Text('Deudores Ali')),
            DataColumn(label: Text('Diferencia')),
          ],
          rows: drafts.asMap().entries.map((entry) {
            final rowIndex = entry.key;
            final draft = entry.value;
            final difference = draft.difference;
            final imported = rowIndex < importedRows;
            return DataRow(
              color: WidgetStatePropertyAll(
                imported
                    ? Colors.blue.withValues(alpha: 0.10)
                    : difference == 0
                    ? Colors.transparent
                    : Theme.of(
                        context,
                      ).colorScheme.error.withValues(alpha: 0.08),
              ),
              cells: [
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_dayLabel(draft.reportDate)),
                      if (imported) ...[
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.check_circle_rounded,
                          color: Colors.blue,
                          size: 16,
                        ),
                      ],
                    ],
                  ),
                ),
                DataCell(
                  _NumberField(
                    value: draft.deliveredTotal,
                    onChanged: (value) {
                      draft.deliveredTotal = value;
                      onChanged();
                    },
                  ),
                ),
                DataCell(
                  _NumberField(
                    value: draft.paidDelivered,
                    onChanged: (value) {
                      draft.paidDelivered = value;
                      onChanged();
                    },
                  ),
                ),
                DataCell(
                  _NumberField(
                    value: draft.paidLevel3,
                    onChanged: (value) {
                      draft.paidLevel3 = value;
                      onChanged();
                    },
                  ),
                ),
                DataCell(
                  _NumberField(
                    value: draft.reports,
                    onChanged: (value) {
                      draft.reports = value;
                      onChanged();
                    },
                  ),
                ),
                DataCell(
                  _NumberField(
                    value: draft.returnsCount,
                    onChanged: (value) {
                      draft.returnsCount = value;
                      onChanged();
                    },
                  ),
                ),
                DataCell(
                  _NumberField(
                    value: draft.debtors,
                    onChanged: (value) {
                      draft.debtors = value;
                      onChanged();
                    },
                  ),
                ),
                DataCell(
                  _NumberField(
                    value: draft.aliDebtors,
                    onChanged: (value) {
                      draft.aliDebtors = value;
                      onChanged();
                    },
                  ),
                ),
                DataCell(
                  StatusBadge(
                    label: '$difference',
                    color: difference == 0
                        ? Colors.green
                        : Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  static String _dayLabel(DateTime date) {
    const days = [
      'Lunes',
      'Martes',
      'Miercoles',
      'Jueves',
      'Viernes',
      'Sabado',
      'Domingo',
    ];
    return '${days[date.weekday - 1]} ${date.day}';
  }
}

class _PercentPanel extends StatelessWidget {
  const _PercentPanel({required this.report, required this.previousReport});

  final WeeklyReportBundle report;
  final WeeklyReportBundle? previousReport;

  @override
  Widget build(BuildContext context) {
    final rows = [
      _PercentMetric(
        label: '% de deudores',
        currentValue: report.debtorsPercent,
        previousValue: previousReport?.debtorsPercent,
        lowerIsBetter: true,
      ),
      _PercentMetric(
        label: '% de deudores ALI',
        currentValue: report.aliDebtorsPercent,
        previousValue: previousReport?.aliDebtorsPercent,
        lowerIsBetter: true,
      ),
      _PercentMetric(
        label: '% que no pago',
        currentValue: report.unpaidPercent,
        previousValue: previousReport?.unpaidPercent,
        lowerIsBetter: true,
      ),
      _PercentMetric(
        label: '% de incidencias',
        currentValue: report.incidentsPercent,
        previousValue: previousReport?.incidentsPercent,
        lowerIsBetter: true,
      ),
      _PercentMetric(
        label: '% de cobros en Entregados',
        currentValue: report.paidDeliveredPercent,
        previousValue: previousReport?.paidDeliveredPercent,
      ),
      _PercentMetric(
        label: '% de cobros antes de Nivel 3',
        currentValue: report.paidBeforeLevel3Percent,
        previousValue: previousReport?.paidBeforeLevel3Percent,
      ),
      _PercentMetric(
        label: '% de Nivel 3',
        currentValue: report.level3Percent,
        previousValue: previousReport?.level3Percent,
      ),
      _PercentMetric(
        label: '% de cobros total',
        currentValue: report.totalPaidPercent,
        previousValue: previousReport?.totalPaidPercent,
      ),
    ];

    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Porcentajes', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            previousReport == null
                ? 'No hay un corte anterior inmediato para estas tarjetas. La grafica historica de abajo usa todos los cortes guardados.'
                : 'Referencia inmediata contra ${Formatters.date(previousReport!.report.startDate)} - ${Formatters.date(previousReport!.report.endDate)}. La grafica historica de abajo usa todos los cortes guardados.',
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: rows.map((row) {
              return _PercentTrendCard(metric: row);
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _PercentTrendCard extends StatelessWidget {
  const _PercentTrendCard({required this.metric});

  final _PercentMetric metric;

  @override
  Widget build(BuildContext context) {
    final previous = metric.previousValue;
    final delta = previous == null ? null : metric.currentValue - previous;
    final trendColor = _trendColor(context, delta);
    final trendIcon = delta == null
        ? Icons.horizontal_rule_rounded
        : delta > 0
        ? Icons.trending_up_rounded
        : delta < 0
        ? Icons.trending_down_rounded
        : Icons.trending_flat_rounded;
    final trendLabel = delta == null
        ? 'Sin comparacion'
        : delta == 0
        ? 'Sin cambios'
        : '${delta > 0 ? 'Sube' : 'Baja'} ${delta.abs().toStringAsFixed(2)} pts';

    return SizedBox(
      width: 320,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F7FB),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: trendColor.withValues(alpha: 0.24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    metric.label,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Icon(trendIcon, color: trendColor),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${metric.currentValue.toStringAsFixed(2)}%',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: trendColor,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            _PercentBar(
              value: metric.currentValue,
              color: trendColor,
              label: 'Actual',
            ),
            const SizedBox(height: 8),
            _PercentBar(
              value: previous ?? 0,
              color: Colors.blueGrey,
              label: previous == null
                  ? 'Anterior: sin datos'
                  : 'Anterior: ${previous.toStringAsFixed(2)}%',
            ),
            const SizedBox(height: 10),
            StatusBadge(label: trendLabel, color: trendColor),
          ],
        ),
      ),
    );
  }

  Color _trendColor(BuildContext context, double? delta) {
    if (delta == null || delta == 0) {
      return Colors.blueGrey;
    }
    final improved = metric.lowerIsBetter ? delta < 0 : delta > 0;
    return improved ? Colors.green : Theme.of(context).colorScheme.error;
  }
}

class _PercentBar extends StatelessWidget {
  const _PercentBar({
    required this.value,
    required this.color,
    required this.label,
  });

  final double value;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final normalized = (value / 100).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: normalized,
            minHeight: 9,
            backgroundColor: color.withValues(alpha: 0.14),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _PercentMetric {
  const _PercentMetric({
    required this.label,
    required this.currentValue,
    required this.previousValue,
    this.lowerIsBetter = false,
  });

  final String label;
  final double currentValue;
  final double? previousValue;
  final bool lowerIsBetter;
}

class _ComparisonPanel extends StatefulWidget {
  const _ComparisonPanel({required this.reports});

  final List<WeeklyReportBundle> reports;

  @override
  State<_ComparisonPanel> createState() => _ComparisonPanelState();
}

class _ComparisonPanelState extends State<_ComparisonPanel> {
  String _selectedMetricId = 'totalPaid';
  int _selectedWeekRange = 0;
  final Set<String> _selectedLineMetricIds = {
    'incidents',
    'unpaid',
    'debtors',
    'aliDebtors',
  };

  @override
  Widget build(BuildContext context) {
    final metrics = _HistoricalMetric.fromReports(widget.reports);
    if (!metrics.any((item) => item.id == _selectedMetricId)) {
      _selectedMetricId = metrics.last.id;
    }
    _ensureSelectedLineMetrics(metrics);
    final orderedReports = widget.reports.toList()
      ..sort((left, right) {
        return left.report.startDate.compareTo(right.report.startDate);
      });
    final visibleReports = _visibleReports(orderedReports);

    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Grafica historica por criterio',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Usa todos los cortes guardados desde el primero, incluso de anos anteriores.',
                    ),
                  ],
                ),
              ),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: 320,
                    child: OutlinedButton.icon(
                      onPressed: () => _openLineMetricSelector(metrics),
                      icon: const Icon(Icons.stacked_line_chart_rounded),
                      label: Text(
                        _selectedLineMetricIds.length == 1
                            ? _selectedLineMetrics(metrics).first.label
                            : '${_selectedLineMetricIds.length} parametros en grafica',
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<int>(
                      initialValue: _selectedWeekRange,
                      decoration: const InputDecoration(labelText: 'Rango'),
                      items: _HistoryRangeOption.options.map((option) {
                        return DropdownMenuItem(
                          value: option.weeks,
                          child: Text(option.label),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setState(() => _selectedWeekRange = value);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _selectedWeekRange == 0
                ? 'Mostrando todo el historial: ${visibleReports.length} cortes.'
                : 'Mostrando ultimas $_selectedWeekRange semanas: ${visibleReports.length} cortes disponibles.',
          ),
          const SizedBox(height: 18),
          if (visibleReports.isEmpty)
            const Text('No hay cortes para la tienda y rango seleccionados.')
          else
            _SelectedParametersLineChart(
              reports: visibleReports,
              metrics: _selectedLineMetrics(metrics),
            ),
          const SizedBox(height: 22),
          _HistoricalComparisonTable(reports: visibleReports, metrics: metrics),
        ],
      ),
    );
  }

  List<WeeklyReportBundle> _visibleReports(
    List<WeeklyReportBundle> orderedReports,
  ) {
    if (_selectedWeekRange == 0 ||
        orderedReports.length <= _selectedWeekRange) {
      return orderedReports;
    }
    return orderedReports.sublist(orderedReports.length - _selectedWeekRange);
  }

  List<_HistoricalMetric> _selectedLineMetrics(
    List<_HistoricalMetric> metrics,
  ) {
    return metrics.where((metric) {
      return _selectedLineMetricIds.contains(metric.id);
    }).toList();
  }

  void _ensureSelectedLineMetrics(List<_HistoricalMetric> metrics) {
    final validIds = metrics.map((metric) => metric.id).toSet();
    _selectedLineMetricIds.removeWhere((id) => !validIds.contains(id));
    if (_selectedLineMetricIds.isEmpty && metrics.isNotEmpty) {
      _selectedLineMetricIds.add(metrics.first.id);
    }
  }

  Future<void> _openLineMetricSelector(List<_HistoricalMetric> metrics) async {
    final draftSelection = Set<String>.from(_selectedLineMetricIds);
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Parametros de la grafica'),
              content: SizedBox(
                width: 460,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: metrics.map((metric) {
                      final selected = draftSelection.contains(metric.id);
                      return CheckboxListTile(
                        value: selected,
                        title: Text(metric.label),
                        subtitle: Text(
                          metric.lowerIsBetter
                              ? 'Si sube afecta negativamente'
                              : 'Si sube mejora el resultado',
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                        onChanged: (value) {
                          setDialogState(() {
                            if (value == true) {
                              draftSelection.add(metric.id);
                            } else if (draftSelection.length > 1) {
                              draftSelection.remove(metric.id);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () =>
                      Navigator.of(dialogContext).pop(draftSelection),
                  child: const Text('Aplicar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null || result.isEmpty) {
      return;
    }
    setState(() {
      _selectedLineMetricIds
        ..clear()
        ..addAll(result);
      _selectedMetricId = result.first;
    });
  }
}

class _HistoryRangeOption {
  const _HistoryRangeOption({required this.weeks, required this.label});

  final int weeks;
  final String label;

  static const options = [
    _HistoryRangeOption(weeks: 0, label: 'Todo el historial'),
    _HistoryRangeOption(weeks: 4, label: 'Ultimas 4 semanas'),
    _HistoryRangeOption(weeks: 6, label: 'Ultimas 6 semanas'),
    _HistoryRangeOption(weeks: 8, label: 'Ultimas 8 semanas'),
    _HistoryRangeOption(weeks: 12, label: 'Ultimas 12 semanas'),
    _HistoryRangeOption(weeks: 26, label: 'Ultimas 26 semanas'),
    _HistoryRangeOption(weeks: 52, label: 'Ultimas 52 semanas'),
  ];
}

class _SelectedParametersLineChart extends StatelessWidget {
  const _SelectedParametersLineChart({
    required this.reports,
    required this.metrics,
  });

  final List<WeeklyReportBundle> reports;
  final List<_HistoricalMetric> metrics;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE0E6EF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Grafica de parametros seleccionados',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          const Text(
            'Usa el selector de parametros para decidir que lineas comparar.',
          ),
          const SizedBox(height: 18),
          MultiLineChart(
            labels: reports.map(_labelForReport).toList(),
            series: metrics.map((metric) {
              return LineChartSeries(
                label: metric.legendLabel,
                color: metric.lineColor,
                values: reports.map(metric.resolve).toList(),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  String _labelForReport(WeeklyReportBundle report) {
    final start = report.report.startDate;
    final end = report.report.endDate;
    if (start.month == end.month) {
      return '${start.day}-${end.day}/${end.month}';
    }
    return '${start.day}/${start.month}-${end.day}/${end.month}';
  }
}

class _HistoricalComparisonTable extends StatelessWidget {
  const _HistoricalComparisonTable({
    required this.reports,
    required this.metrics,
  });

  final List<WeeklyReportBundle> reports;
  final List<_HistoricalMetric> metrics;

  @override
  Widget build(BuildContext context) {
    if (reports.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Comparativo por semanas',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 6),
        const Text(
          'Las flechas se pintan segun el criterio: bajar deudas/incidencias es bueno, subir cobros es bueno.',
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStatePropertyAll(
              const Color(0xFFFFC476).withValues(alpha: 0.88),
            ),
            dataRowMinHeight: 56,
            dataRowMaxHeight: 68,
            columns: [
              const DataColumn(label: Text('Criterio')),
              for (final report in reports)
                DataColumn(label: Text(_weekHeader(report))),
            ],
            rows: metrics.map((metric) {
              return DataRow(
                color: WidgetStatePropertyAll(
                  metric.lowerIsBetter
                      ? const Color(0xFFEAF3F0)
                      : const Color(0xFFEAF0FA),
                ),
                cells: [
                  DataCell(
                    Text(
                      metric.label,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  for (var index = 0; index < reports.length; index++)
                    DataCell(
                      _MetricTrendValue(
                        currentValue: metric.resolve(reports[index]),
                        previousValue: index == 0
                            ? null
                            : metric.resolve(reports[index - 1]),
                        lowerIsBetter: metric.lowerIsBetter,
                      ),
                    ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  String _weekHeader(WeeklyReportBundle report) {
    final start = report.report.startDate;
    final end = report.report.endDate;
    return '${start.day}-${end.day}/${end.month}';
  }
}

class _MetricTrendValue extends StatelessWidget {
  const _MetricTrendValue({
    required this.currentValue,
    required this.previousValue,
    required this.lowerIsBetter,
  });

  final double currentValue;
  final double? previousValue;
  final bool lowerIsBetter;

  @override
  Widget build(BuildContext context) {
    final delta = previousValue == null ? null : currentValue - previousValue!;
    final color = _trendColor(context, delta);
    final icon = delta == null || delta == 0
        ? Icons.trending_flat_rounded
        : delta > 0
        ? Icons.arrow_upward_rounded
        : Icons.arrow_downward_rounded;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${currentValue.toStringAsFixed(2)}%',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(width: 8),
        Icon(icon, color: color, size: 16),
      ],
    );
  }

  Color _trendColor(BuildContext context, double? delta) {
    if (delta == null || delta == 0) {
      return Colors.blueGrey;
    }
    final improved = lowerIsBetter ? delta < 0 : delta > 0;
    return improved ? Colors.green : Theme.of(context).colorScheme.error;
  }
}

class _HistoricalMetric {
  const _HistoricalMetric({
    required this.id,
    required this.label,
    required this.resolve,
    required this.lineColor,
    String? legendLabel,
    this.lowerIsBetter = false,
  }) : legendLabel = legendLabel ?? label;

  final String id;
  final String label;
  final String legendLabel;
  final double Function(WeeklyReportBundle report) resolve;
  final Color lineColor;
  final bool lowerIsBetter;

  Color colorFor(BuildContext context, double value) {
    if (value == 0) {
      return Colors.blueGrey;
    }
    if (lowerIsBetter) {
      return value >= 20 ? Theme.of(context).colorScheme.error : Colors.orange;
    }
    return Theme.of(context).colorScheme.primary;
  }

  static List<_HistoricalMetric> fromReports(List<WeeklyReportBundle> reports) {
    final customNames = <String, String>{};
    for (final report in reports) {
      for (final criterion in report.customCriteria) {
        final normalized = _normalizeCustomMetricName(criterion.name);
        if (normalized.isNotEmpty) {
          customNames.putIfAbsent(normalized, () => criterion.name.trim());
        }
      }
    }

    return [
      ...baseMetrics,
      for (final entry in customNames.entries)
        _HistoricalMetric(
          id: 'custom:${entry.key}',
          label: entry.value,
          lineColor: const Color(0xFF6B7280),
          resolve: (report) {
            for (final criterion in report.customCriteria) {
              if (_normalizeCustomMetricName(criterion.name) == entry.key) {
                return criterion.value;
              }
            }
            return 0;
          },
        ),
    ];
  }

  static String _normalizeCustomMetricName(String value) {
    return value.trim().toLowerCase();
  }

  static final baseMetrics = [
    _HistoricalMetric(
      id: 'debtors',
      label: '% de deudores',
      legendLabel: 'Deudores',
      lineColor: Color(0xFFA5A5A5),
      resolve: (report) => report.debtorsPercent,
      lowerIsBetter: true,
    ),
    _HistoricalMetric(
      id: 'aliDebtors',
      label: '% de deudores ALI',
      legendLabel: 'Deudores ALI',
      lineColor: Color(0xFFFFC000),
      resolve: (report) => report.aliDebtorsPercent,
      lowerIsBetter: true,
    ),
    _HistoricalMetric(
      id: 'unpaid',
      label: '% que no pago',
      legendLabel: 'No pago',
      lineColor: Color(0xFFED7D31),
      resolve: (report) => report.unpaidPercent,
      lowerIsBetter: true,
    ),
    _HistoricalMetric(
      id: 'incidents',
      label: '% de incidencias',
      legendLabel: 'Incidencias',
      lineColor: Color(0xFF4472C4),
      resolve: (report) => report.incidentsPercent,
      lowerIsBetter: true,
    ),
    _HistoricalMetric(
      id: 'paidDelivered',
      label: '% de cobros en Entregados',
      legendLabel: 'Cobros Entregados',
      lineColor: Color(0xFF70AD47),
      resolve: (report) => report.paidDeliveredPercent,
    ),
    _HistoricalMetric(
      id: 'paidBeforeLevel3',
      label: '% de cobros antes de Nivel 3',
      legendLabel: 'Cobros antes Nivel 3',
      lineColor: Color(0xFF00A6A6),
      resolve: (report) => report.paidBeforeLevel3Percent,
    ),
    _HistoricalMetric(
      id: 'level3',
      label: '% de Nivel 3',
      legendLabel: 'Nivel 3',
      lineColor: Color(0xFF7030A0),
      resolve: (report) => report.level3Percent,
    ),
    _HistoricalMetric(
      id: 'totalPaid',
      label: '% de cobros total',
      legendLabel: 'Cobros total',
      lineColor: Color(0xFF1F4E79),
      resolve: (report) => report.totalPaidPercent,
    ),
  ];
}

class _CustomCriteriaPanel extends StatelessWidget {
  const _CustomCriteriaPanel({
    required this.report,
    required this.onAddCriterion,
  });

  final WeeklyReportBundle report;
  final VoidCallback onAddCriterion;

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Criterios personalizados',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: onAddCriterion,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Agregar criterio'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (report.customCriteria.isEmpty)
            const Text(
              'Puedes agregar porcentajes o criterios nuevos sin cambiar el reporte base.',
            ),
          for (final criterion in report.customCriteria)
            ListTile(
              title: Text(criterion.name),
              subtitle: Text(criterion.notes),
              trailing: Text('${criterion.value.toStringAsFixed(2)}%'),
            ),
        ],
      ),
    );
  }
}

class _BalanceAlert extends StatelessWidget {
  const _BalanceAlert({required this.difference});

  final int difference;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.error.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.error.withValues(alpha: 0.30),
        ),
      ),
      child: Text(
        'Aun hay una diferencia de $difference registros. '
        'Revisa filtros y descontamina la data en Excel antes de cerrar.',
        style: TextStyle(
          color: Theme.of(context).colorScheme.error,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _BalancedMessage extends StatelessWidget {
  const _BalancedMessage();

  @override
  Widget build(BuildContext context) {
    return const StatusBadge(
      label: 'Cuadre correcto. El reporte puede cerrarse.',
      color: Colors.green,
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      child: TextFormField(
        initialValue: '$value',
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(isDense: true),
        onChanged: (rawValue) => onChanged(int.tryParse(rawValue) ?? 0),
      ),
    );
  }
}

class _DayDraft {
  _DayDraft({
    required this.id,
    required this.reportId,
    required this.reportDate,
    required this.deliveredTotal,
    required this.paidDelivered,
    required this.paidLevel3,
    required this.reports,
    required this.returnsCount,
    required this.debtors,
    required this.aliDebtors,
  });

  final int? id;
  final int reportId;
  final DateTime reportDate;
  int deliveredTotal;
  int paidDelivered;
  int paidLevel3;
  int reports;
  int returnsCount;
  int debtors;
  int aliDebtors;

  int get classifiedTotal =>
      paidDelivered +
      paidLevel3 +
      reports +
      returnsCount +
      debtors +
      aliDebtors;

  int get difference => deliveredTotal - classifiedTotal;

  factory _DayDraft.fromDay(WeeklyReportDay day) {
    return _DayDraft(
      id: day.id,
      reportId: day.reportId,
      reportDate: day.reportDate,
      deliveredTotal: day.deliveredTotal,
      paidDelivered: day.paidDelivered,
      paidLevel3: day.paidLevel3,
      reports: day.reports,
      returnsCount: day.returnsCount,
      debtors: day.debtors,
      aliDebtors: day.aliDebtors,
    );
  }

  WeeklyReportDay toDay() {
    return WeeklyReportDay(
      id: id,
      reportId: reportId,
      reportDate: reportDate,
      deliveredTotal: deliveredTotal,
      paidDelivered: paidDelivered,
      paidLevel3: paidLevel3,
      reports: reports,
      returnsCount: returnsCount,
      debtors: debtors,
      aliDebtors: aliDebtors,
    );
  }
}

class _ImportedWeeklyRow {
  const _ImportedWeeklyRow({
    required this.deliveredTotal,
    required this.paidDelivered,
    required this.paidLevel3,
    required this.reports,
    required this.returnsCount,
    required this.debtors,
    required this.aliDebtors,
  });

  final int deliveredTotal;
  final int paidDelivered;
  final int paidLevel3;
  final int reports;
  final int returnsCount;
  final int debtors;
  final int aliDebtors;

  void applyTo(_DayDraft draft) {
    draft.deliveredTotal = deliveredTotal;
    draft.paidDelivered = paidDelivered;
    draft.paidLevel3 = paidLevel3;
    draft.reports = reports;
    draft.returnsCount = returnsCount;
    draft.debtors = debtors;
    draft.aliDebtors = aliDebtors;
  }

  WeeklyReportDay toDay(WeeklyReportDay day) {
    return WeeklyReportDay(
      id: day.id,
      reportId: day.reportId,
      reportDate: day.reportDate,
      deliveredTotal: deliveredTotal,
      paidDelivered: paidDelivered,
      paidLevel3: paidLevel3,
      reports: reports,
      returnsCount: returnsCount,
      debtors: debtors,
      aliDebtors: aliDebtors,
    );
  }
}

class _WeeklyImportParser {
  static List<_ImportedWeeklyRow> parseRows(String rawText) {
    final rows = <_ImportedWeeklyRow>[];
    final lines = _cleanLines(rawText);

    for (final line in lines) {
      final cells = _splitImportedLine(line);
      if (cells.any((cell) => cell.trim().toLowerCase() == 'total')) {
        continue;
      }

      final hasDateColumn = cells.length >= 8;
      if (hasDateColumn) {
        parseDate(cells.first);
      }
      final offset = hasDateColumn ? 1 : 0;
      if (cells.length < offset + 7) {
        continue;
      }

      final values = <int>[];
      for (var index = offset; index < offset + 7; index++) {
        final value = _parseImportedInt(cells[index]);
        if (value == null) {
          values.clear();
          break;
        }
        values.add(value);
      }

      if (values.length == 7) {
        rows.add(
          _ImportedWeeklyRow(
            deliveredTotal: values[0],
            paidDelivered: values[1],
            paidLevel3: values[2],
            reports: values[3],
            returnsCount: values[4],
            debtors: values[5],
            aliDebtors: values[6],
          ),
        );
      }
    }

    return rows.take(7).toList();
  }

  static Iterable<String> _cleanLines(String rawText) {
    return rawText
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty);
  }

  static List<String> _splitImportedLine(String line) {
    if (line.contains('\t')) {
      return line.split('\t').map(_cleanImportedCell).toList();
    }
    final semicolonCount = ';'.allMatches(line).length;
    final commaCount = ','.allMatches(line).length;
    final separator = semicolonCount >= commaCount ? ';' : ',';
    return line.split(separator).map(_cleanImportedCell).toList();
  }

  static String _cleanImportedCell(String value) {
    return value.trim().replaceAll('"', '').replaceAll("'", '');
  }

  static int? _parseImportedInt(String value) {
    final clean = value
        .replaceAll(RegExp(r'[^0-9\-.]'), '')
        .replaceAll(RegExp(r'\.0+$'), '');
    if (clean.isEmpty) {
      return null;
    }
    return double.tryParse(clean)?.round();
  }

  static DateTime? parseDate(String value) {
    final clean = value.trim().toLowerCase().replaceAll('.', '');
    final named = RegExp(
      r'^(\d{1,2})(?:\s*[-\/]\s*|\s+de\s+|\s+)([a-záéíóúñ]+)(?:\s+(\d{2,4}))?$',
    ).firstMatch(clean);
    if (named == null) {
      return null;
    }
    final month = monthNumber(named.group(2)!);
    if (month == null) {
      return null;
    }
    return dateFromParts(
      day: int.parse(named.group(1)!),
      month: month,
      year: parseYear(named.group(3)),
    );
  }

  static DateTime? dateFromParts({
    required int day,
    required int month,
    required int year,
  }) {
    if (month < 1 || month > 12 || day < 1 || day > 31) {
      return null;
    }
    return DateTime(year, month, day);
  }

  static int parseYear(String? value) {
    if (value == null || value.isEmpty) {
      return DateTime.now().year;
    }
    final parsed = int.parse(value);
    return parsed < 100 ? 2000 + parsed : parsed;
  }

  static int? monthNumber(String value) {
    const months = {
      'ene': 1,
      'enero': 1,
      'feb': 2,
      'febrero': 2,
      'mar': 3,
      'marzo': 3,
      'abr': 4,
      'abril': 4,
      'may': 5,
      'mayo': 5,
      'jun': 6,
      'junio': 6,
      'jul': 7,
      'julio': 7,
      'ago': 8,
      'agosto': 8,
      'sep': 9,
      'sept': 9,
      'septiembre': 9,
      'oct': 10,
      'octubre': 10,
      'nov': 11,
      'noviembre': 11,
      'dic': 12,
      'diciembre': 12,
    };
    return months[value];
  }
}
