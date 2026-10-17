part of 'courses_page.dart';

/// "Avance de alumnos" table from `GET /courses/progress`.
class _CourseProgressView extends StatefulWidget {
  const _CourseProgressView({required this.repository});

  final CoursesRepository repository;

  @override
  State<_CourseProgressView> createState() => _CourseProgressViewState();
}

class _CourseProgressViewState extends State<_CourseProgressView> {
  List<CourseProgressRow>? _rows;
  String? _error;
  var _loading = true;
  String? _storeFilter;
  var _search = '';

  /// Shows "Preguntas más falladas" instead of the students table.
  var _showMissed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await widget.repository.fetchProgressSummary();
      if (!mounted) return;
      setState(() => _rows = rows);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<CourseProgressRow> get _visibleRows {
    final query = _search.trim().toLowerCase();
    return [
      for (final row in _rows ?? const <CourseProgressRow>[])
        if ((_storeFilter == null || row.storeCode == _storeFilter) &&
            (query.isEmpty ||
                row.username.toLowerCase().contains(query) ||
                row.fullName.toLowerCase().contains(query) ||
                row.courseTitle.toLowerCase().contains(query)))
          row,
    ];
  }

  void _openAttempts(CourseProgressRow row) {
    showDialog<void>(
      context: context,
      builder: (context) =>
          _StudentAttemptsDialog(repository: widget.repository, row: row),
    );
  }

  Map<int, String> get _courses => {
    for (final row in _rows ?? const <CourseProgressRow>[])
      row.courseId: row.courseTitle,
  };

  @override
  Widget build(BuildContext context) {
    if (_loading && _rows == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _rows == null) {
      return _ErrorRetry(message: _error!, onRetry: _load);
    }

    final rows = _visibleRows;
    final dateFormat = DateFormat('dd/MM/yyyy h:mm a', 'en_US');

    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Avance de alumnos',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                onPressed: _loading ? null : _load,
                tooltip: 'Actualizar',
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: false,
                icon: Icon(Icons.people_alt_rounded),
                label: Text('Alumnos'),
              ),
              ButtonSegment(
                value: true,
                icon: Icon(Icons.quiz_rounded),
                label: Text('Preguntas más falladas'),
              ),
            ],
            selected: {_showMissed},
            onSelectionChanged: (selection) =>
                setState(() => _showMissed = selection.single),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ChoiceChip(
                label: const Text('Todas'),
                selected: _storeFilter == null,
                onSelected: (_) => setState(() => _storeFilter = null),
              ),
              for (final store in storeCodes)
                ChoiceChip(
                  label: Text(store),
                  selected: _storeFilter == store,
                  onSelected: (_) => setState(() => _storeFilter = store),
                ),
              if (!_showMissed)
                SizedBox(
                  width: context.isCompact ? double.infinity : 280,
                  child: TextField(
                    decoration: const InputDecoration(
                      isDense: true,
                      prefixIcon: Icon(Icons.search_rounded),
                      hintText: 'Buscar alumno o curso',
                    ),
                    onChanged: (value) => setState(() => _search = value),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_showMissed)
            Expanded(
              child: _MissedQuestionsPanel(
                repository: widget.repository,
                storeCode: _storeFilter,
                courses: _courses,
              ),
            )
          else
            Expanded(
              // Phones and tablets get cards; the table needs ~860 px.
              child: LayoutBuilder(
                builder: (context, constraints) => rows.isEmpty
                    ? const _EmptyState(
                        icon: Icons.insights_rounded,
                        message:
                            'Todavía no hay avance registrado para este filtro.',
                      )
                    : constraints.maxWidth < 860
                    ? ListView.separated(
                        itemCount: rows.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 20),
                        itemBuilder: (context, index) => _ProgressRowCard(
                          row: rows[index],
                          onOpenAttempts: () => _openAttempts(rows[index]),
                          lastActivity: rows[index].lastActivity == null
                              ? 'Sin actividad'
                              : _formatDateTime(
                                  dateFormat,
                                  rows[index].lastActivity!.toLocal(),
                                ),
                        ),
                      )
                    : SingleChildScrollView(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('Alumno')),
                              DataColumn(label: Text('Notas')),
                              DataColumn(label: Text('Tienda')),
                              DataColumn(label: Text('Curso')),
                              DataColumn(label: Text('Lecciones completadas')),
                              DataColumn(label: Text('Última actividad')),
                            ],
                            rows: [
                              for (final row in rows)
                                DataRow(
                                  cells: [
                                    DataCell(
                                      Text(
                                        row.fullName.isEmpty
                                            ? row.username
                                            : '${row.fullName} (${row.username})',
                                      ),
                                    ),
                                    DataCell(
                                      TextButton.icon(
                                        onPressed: () => _openAttempts(row),
                                        icon: const Icon(
                                          Icons.fact_check_rounded,
                                          size: 18,
                                        ),
                                        label: const Text('Ver intentos'),
                                      ),
                                    ),
                                    DataCell(Text(row.storeCode ?? '—')),
                                    DataCell(Text(row.courseTitle)),
                                    DataCell(
                                      SizedBox(
                                        width: 180,
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: LinearProgressIndicator(
                                                value: row.lessonsTotal == 0
                                                    ? 0
                                                    : row.lessonsCompleted /
                                                          row.lessonsTotal,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Text(
                                              '${row.lessonsCompleted}/${row.lessonsTotal}',
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        row.lastActivity == null
                                            ? 'Sin actividad'
                                            : _formatDateTime(
                                                dateFormat,
                                                row.lastActivity!.toLocal(),
                                              ),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One student's progress as a card, used instead of the table when narrow.
class _ProgressRowCard extends StatelessWidget {
  const _ProgressRowCard({
    required this.row,
    required this.lastActivity,
    required this.onOpenAttempts,
  });

  final CourseProgressRow row;
  final String lastActivity;
  final VoidCallback onOpenAttempts;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          row.fullName.isEmpty
              ? row.username
              : '${row.fullName} (${row.username})',
          style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        Text('${row.storeCode ?? '—'} · ${row.courseTitle}'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: LinearProgressIndicator(
                value: row.lessonsTotal == 0
                    ? 0
                    : row.lessonsCompleted / row.lessonsTotal,
              ),
            ),
            const SizedBox(width: 10),
            Text('${row.lessonsCompleted}/${row.lessonsTotal}'),
          ],
        ),
        const SizedBox(height: 4),
        Text('Última actividad: $lastActivity', style: textTheme.bodySmall),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onOpenAttempts,
            icon: const Icon(Icons.fact_check_rounded, size: 18),
            label: const Text('Ver intentos'),
          ),
        ),
      ],
    );
  }
}

/// `dd/MM/yyyy h:mm a. m.` in 12-hour format, Spanish style.
String _formatDateTime(DateFormat format, DateTime value) {
  return format
      .format(value)
      .replaceAll('AM', 'a. m.')
      .replaceAll('PM', 'p. m.');
}
