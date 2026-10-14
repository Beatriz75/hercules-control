part of 'courses_page.dart';

/// Catalog for staff: read-only for supervisor / consulta gerencial,
/// editable for administrators (courses.manage).
class _StaffCoursesView extends StatefulWidget {
  const _StaffCoursesView({
    required this.repository,
    required this.canManage,
    required this.canViewProgress,
    this.initialCourseId,
  });

  final CoursesRepository repository;
  final bool canManage;
  final bool canViewProgress;
  final int? initialCourseId;

  @override
  State<_StaffCoursesView> createState() => _StaffCoursesViewState();
}

enum _StaffTab { catalog, progress }

class _StaffCoursesViewState extends State<_StaffCoursesView> {
  List<Course>? _courses;
  String? _error;
  var _loading = true;
  int? _selectedCourseId;
  String? _storeFilter;
  var _tab = _StaffTab.catalog;
  var _busy = false;
  var _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedCourseId = widget.initialCourseId;
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _searchQuery = '');
  }

  /// Opens a search result: the editor on that lesson (and question) for
  /// administrators, the lesson preview for read-only staff.
  void _openSearchHit(CourseSearchHit hit, {PracticeQuestion? question}) {
    final course = hit.course;
    final lessonIndex = hit.lessonIndex;
    setState(() => _selectedCourseId = course.id);
    if (widget.canManage) {
      _openEditor(
        course,
        initialLessonIndex: lessonIndex ?? 0,
        highlightQuestionId: question?.id,
      );
      return;
    }
    if (lessonIndex == null) {
      _clearSearch();
      return;
    }
    showDialog<void>(
      context: context,
      builder: (context) => _LessonPreviewDialog(
        course: course,
        lesson: course.lessons[lessonIndex],
        lessonNumber: lessonIndex + 1,
      ),
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final courses = await widget.repository.fetchCourses();
      if (!mounted) return;
      setState(() {
        _courses = courses;
        if (!courses.any((course) => course.id == _selectedCourseId)) {
          _selectedCourseId = courses.isEmpty ? null : courses.first.id;
        }
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Course> get _visibleCourses => [
    for (final course in _courses ?? const <Course>[])
      if (_storeFilter == null || course.stores.contains(_storeFilter)) course,
  ];

  Course? get _selectedCourse {
    final visible = _visibleCourses;
    for (final course in visible) {
      if (course.id == _selectedCourseId) return course;
    }
    return visible.isEmpty ? null : visible.first;
  }

  void _replaceCourse(Course saved) {
    final courses = [...?_courses];
    final index = courses.indexWhere((course) => course.id == saved.id);
    if (index == -1) {
      courses.add(saved);
    } else {
      courses[index] = saved;
    }
    setState(() {
      _courses = courses;
      _selectedCourseId = saved.id;
      if (_storeFilter != null && !saved.stores.contains(_storeFilter)) {
        _storeFilter = null;
      }
    });
  }

  /// Saves an edited or new course. Returns an error message, or null.
  Future<String?> _saveCourse(Course draft) async {
    final errors = draft.validationErrors();
    if (errors.isNotEmpty) return errors.join('\n');

    try {
      final saved = draft.id == null
          ? await widget.repository.createCourse(draft)
          : await widget.repository.updateCourse(draft);
      if (!mounted) return null;
      _replaceCourse(saved);
      _showSnack(context, 'Curso "${saved.title}" guardado.');
      return null;
    } on ApiException catch (error) {
      return error.message;
    }
  }

  Future<void> _runAction(Future<Course> Function() action, String done) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final saved = await action();
      if (!mounted) return;
      _replaceCourse(saved);
      _showSnack(context, done);
    } on ApiException catch (error) {
      if (!mounted) return;
      _showSnack(context, 'No se pudo guardar: ${error.message}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toggleActive(Course course) {
    _runAction(
      () => widget.repository.setCourseActive(course.id!, !course.active),
      course.active ? 'Curso desactivado.' : 'Curso activado.',
    );
  }

  void _changeStatus(Course course, CourseStatus status) {
    if (status == course.status) return;
    _runAction(
      () => widget.repository.updateCourse(course.copyWith(status: status)),
      'Estado cambiado a ${status.label}.',
    );
  }

  void _openEditor(
    Course course, {
    int initialLessonIndex = 0,
    int? highlightQuestionId,
  }) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _CourseTemplateEditorDialog(
        course: course,
        initialLessonIndex: initialLessonIndex,
        highlightQuestionId: highlightQuestionId,
        onSave: _saveCourse,
        findSimilar: (prompt) => widget.repository.findSimilarQuestions(prompt),
      ),
    );
  }

  void _createCourse() {
    _openEditor(
      Course.template(
        stores: _storeFilter == null ? const [] : [_storeFilter!],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeader(
          title: 'Cursos',
          subtitle: widget.canManage
              ? 'Plantillas de capacitación por tienda: teoría, práctica por lección y avance de alumnos.'
              : 'Catálogo de capacitación por tienda (sólo lectura) y avance de alumnos.',
          action: widget.canManage && _tab == _StaffTab.catalog
              ? FilledButton.icon(
                  onPressed: _courses == null ? null : _createCourse,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Nuevo curso'),
                )
              : null,
        ),
        if (widget.canViewProgress) ...[
          const SizedBox(height: 16),
          SegmentedButton<_StaffTab>(
            segments: const [
              ButtonSegment(
                value: _StaffTab.catalog,
                icon: Icon(Icons.school_rounded),
                label: Text('Catálogo'),
              ),
              ButtonSegment(
                value: _StaffTab.progress,
                icon: Icon(Icons.insights_rounded),
                label: Text('Avance de alumnos'),
              ),
            ],
            selected: {_tab},
            onSelectionChanged: (selection) =>
                setState(() => _tab = selection.first),
          ),
        ],
        const SizedBox(height: 20),
        Expanded(
          child: _tab == _StaffTab.progress
              ? _CourseProgressView(repository: widget.repository)
              : _buildCatalog(context),
        ),
      ],
    );
  }

  Widget _buildCatalog(BuildContext context) {
    if (_loading && _courses == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _courses == null) {
      return _ErrorRetry(message: _error!, onRetry: _load);
    }

    final courses = _courses ?? const <Course>[];
    final visible = _visibleCourses;
    final selected = _selectedCourse;
    final searching = _searchQuery.trim().isNotEmpty;
    final published = courses.where((course) => course.visibleToStudents);
    final lessonCount = visible.fold<int>(
      0,
      (total, course) => total + course.lessons.length,
    );

    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = constraints.maxWidth < 720 ? 1 : 3;

                return GridView.count(
                  crossAxisCount: crossAxisCount,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: crossAxisCount == 1 ? 3.6 : 2.65,
                  children: [
                    MetricCard(
                      title: 'Cursos',
                      value: '${visible.length}',
                      caption: _storeFilter == null
                          ? 'Todas las tiendas'
                          : 'Asignados a $_storeFilter',
                      icon: Icons.school_rounded,
                    ),
                    MetricCard(
                      title: 'Publicados',
                      value: '${published.length}',
                      caption: 'Visibles para alumnos',
                      icon: Icons.visibility_rounded,
                    ),
                    MetricCard(
                      title: 'Lecciones',
                      value: '$lessonCount',
                      caption: 'En los cursos filtrados',
                      icon: Icons.menu_book_rounded,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            AppPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Catálogo de cursos',
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
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Todas'),
                        selected: _storeFilter == null,
                        onSelected: (_) => setState(() => _storeFilter = null),
                      ),
                      for (final store in storeCodes)
                        ChoiceChip(
                          label: Text(store),
                          selected: store == _storeFilter,
                          onSelected: (_) =>
                              setState(() => _storeFilter = store),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      isDense: true,
                      prefixIcon: const Icon(Icons.search_rounded),
                      hintText: 'Buscar lección, pregunta o código (P65)',
                      suffixIcon: _searchQuery.isEmpty
                          ? null
                          : IconButton(
                              onPressed: _clearSearch,
                              tooltip: 'Limpiar búsqueda',
                              icon: const Icon(Icons.close_rounded),
                            ),
                    ),
                    onChanged: (value) => setState(() => _searchQuery = value),
                  ),
                  const SizedBox(height: 14),
                  if (searching)
                    _CourseSearchResults(
                      hits: searchCourseCatalog(visible, _searchQuery),
                      canManage: widget.canManage,
                      onOpen: _openSearchHit,
                    )
                  else if (visible.isEmpty)
                    _EmptyState(
                      icon: Icons.school_outlined,
                      message: widget.canManage
                          ? 'No hay cursos para este filtro. Crea uno con "Nuevo curso".'
                          : 'No hay cursos para este filtro.',
                    ),
                  if (!searching)
                    for (final course in visible) ...[
                      _CourseTile(
                        course: course,
                        statusLabels: _statusLabels(course),
                        selected: course.id == selected?.id,
                        onTap: () =>
                            setState(() => _selectedCourseId = course.id),
                      ),
                      if (course != visible.last) const SizedBox(height: 10),
                    ],
                ],
              ),
            ),
            if (selected != null && !searching) ...[
              const SizedBox(height: 16),
              _StaffCourseDetailPanel(
                course: selected,
                canManage: widget.canManage,
                busy: _busy,
                onEdit: (lessonIndex) =>
                    _openEditor(selected, initialLessonIndex: lessonIndex),
                onToggleActive: () => _toggleActive(selected),
                onStatusChanged: (status) => _changeStatus(selected, status),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

List<String> _statusLabels(Course course) => [
  course.status.label,
  if (!course.active) 'Inactivo',
];

class _StaffCourseDetailPanel extends StatelessWidget {
  const _StaffCourseDetailPanel({
    required this.course,
    required this.canManage,
    required this.busy,
    required this.onEdit,
    required this.onToggleActive,
    required this.onStatusChanged,
  });

  final Course course;
  final bool canManage;
  final bool busy;
  final ValueChanged<int> onEdit;
  final VoidCallback onToggleActive;
  final ValueChanged<CourseStatus> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final description = course.description?.trim() ?? '';

    void openLesson(int lessonIndex) {
      showDialog<void>(
        context: context,
        builder: (context) => _LessonPreviewDialog(
          course: course,
          lesson: course.lessons[lessonIndex],
          lessonNumber: lessonIndex + 1,
          onEdit: canManage ? () => onEdit(lessonIndex) : null,
        ),
      );
    }

    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  course.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (busy)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final store in course.stores) _StatusPill(label: store),
              _StatusPill(
                label: course.status.label,
                color: course.status == CourseStatus.active
                    ? BrandColors.success
                    : colorScheme.tertiary,
              ),
              if (!course.active)
                _StatusPill(label: 'Inactivo', color: colorScheme.error),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(description),
          ],
          const SizedBox(height: 12),
          _NextActionBanner(
            message: course.visibleToStudents
                ? 'Visible para los alumnos de ${course.stores.join(' y ')}.'
                : !course.active
                ? 'Curso inactivo: los alumnos no lo ven.'
                : course.status == CourseStatus.draft
                ? 'Borrador: publícalo para que los alumnos lo vean.'
                : 'Archivado: los alumnos ya no lo ven.',
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (canManage) ...[
                FilledButton.icon(
                  onPressed: busy ? null : () => onEdit(0),
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('Editar plantilla'),
                ),
                OutlinedButton.icon(
                  onPressed: busy ? null : onToggleActive,
                  icon: Icon(
                    course.active
                        ? Icons.toggle_on_rounded
                        : Icons.toggle_off_rounded,
                  ),
                  label: Text(course.active ? 'Desactivar' : 'Activar'),
                ),
                PopupMenuButton<CourseStatus>(
                  enabled: !busy,
                  tooltip: 'Cambiar estado',
                  onSelected: onStatusChanged,
                  itemBuilder: (context) => [
                    for (final status in CourseStatus.values)
                      CheckedPopupMenuItem(
                        value: status,
                        checked: status == course.status,
                        child: Text(status.label),
                      ),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.flag_rounded, color: colorScheme.primary),
                        const SizedBox(width: 6),
                        Text(
                          'Estado: ${course.status.label}',
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Icon(
                          Icons.arrow_drop_down_rounded,
                          color: colorScheme.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              TextButton.icon(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (context) => _QuestionExportDialog(course: course),
                ),
                icon: const Icon(Icons.download_rounded),
                label: const Text('Exportar preguntas'),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _CourseRoadmap(
            lessons: course.lessons,
            onOpenLesson: openLesson,
            onEditLesson: canManage ? onEdit : null,
          ),
        ],
      ),
    );
  }
}

/// Results of the catalog search, grouped as "Curso › Lección".
class _CourseSearchResults extends StatelessWidget {
  const _CourseSearchResults({
    required this.hits,
    required this.canManage,
    required this.onOpen,
  });

  /// Questions listed per lesson before collapsing the rest.
  static const _maxQuestions = 6;

  final List<CourseSearchHit> hits;
  final bool canManage;
  final void Function(CourseSearchHit hit, {PracticeQuestion? question}) onOpen;

  @override
  Widget build(BuildContext context) {
    if (hits.isEmpty) {
      return const _EmptyState(
        icon: Icons.search_off_rounded,
        message:
            'Sin resultados. Prueba con otra palabra o con el código (P65).',
      );
    }

    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final questionCount = hits.fold<int>(
      0,
      (total, hit) => total + hit.questions.length,
    );
    final lessonCount = hits.where((hit) => hit.lessonIndex != null).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_plural(lessonCount, 'lección', 'lecciones')} · '
          '${_plural(questionCount, 'pregunta', 'preguntas')}'
          '${canManage ? ' · Toca un resultado para abrir el editor en esa lección.' : ''}',
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 10),
        for (final hit in hits) ...[
          _CourseSearchHitCard(
            hit: hit,
            maxQuestions: _maxQuestions,
            onOpen: onOpen,
          ),
          if (hit != hits.last) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

String _plural(int count, String one, String many) =>
    '$count ${count == 1 ? one : many}';

class _CourseSearchHitCard extends StatelessWidget {
  const _CourseSearchHitCard({
    required this.hit,
    required this.maxQuestions,
    required this.onOpen,
  });

  final CourseSearchHit hit;
  final int maxQuestions;
  final void Function(CourseSearchHit hit, {PracticeQuestion? question}) onOpen;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final lesson = hit.lesson;
    final shown = hit.questions.take(maxQuestions).toList();
    final hidden = hit.questions.length - shown.length;
    final reason = hit.courseTitle
        ? 'Coincide el título del curso.'
        : hit.lessonFields.isEmpty
        ? null
        : 'Coincide en ${_joinLabels([for (final field in hit.lessonFields) field.label])} de la lección.';

    return Material(
      color: hit.hasExactCode
          ? colorScheme.primary.withValues(alpha: 0.08)
          : colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: hit.hasExactCode
              ? colorScheme.primary
              : colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: hit.hasExactCode ? 1.4 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => onOpen(hit),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                children: [
                  Icon(
                    lesson == null
                        ? Icons.school_rounded
                        : Icons.menu_book_rounded,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lesson == null
                              ? hit.course.title
                              : '${hit.course.title} › Lección ${hit.lessonIndex! + 1}: ${lesson.title}',
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (reason != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            reason,
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          for (final match in shown)
            InkWell(
              onTap: () => onOpen(hit, question: match.question),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(48, 6, 14, 6),
                child: Row(
                  children: [
                    if (match.question.code != null) ...[
                      _QuestionCodeChip(code: match.question.code!),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Text(
                        'Pregunta ${match.index + 1}: '
                        '${match.question.prompt.trim().isEmpty ? 'Sin texto' : match.question.prompt.trim()}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (hidden > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(48, 4, 14, 0),
              child: Text(
                'y ${_plural(hidden, 'pregunta más', 'preguntas más')}',
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          if (shown.isNotEmpty) const SizedBox(height: 8),
        ],
      ),
    );
  }
}

String _joinLabels(List<String> labels) {
  if (labels.length <= 1) return labels.join();
  return '${labels.sublist(0, labels.length - 1).join(', ')} y ${labels.last}';
}
