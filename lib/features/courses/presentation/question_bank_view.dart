part of 'courses_page.dart';

/// "Banco de preguntas": every question of every course (courses.view).
/// Administrators (courses.manage) can edit each question.
class QuestionBankPage extends StatelessWidget {
  const QuestionBankPage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    return _QuestionBankView(
      repository: CoursesRepository(auth.api),
      canManage: auth.can(Permissions.coursesManage),
    );
  }
}

class _QuestionBankView extends StatefulWidget {
  const _QuestionBankView({required this.repository, required this.canManage});

  final CoursesRepository repository;
  final bool canManage;

  @override
  State<_QuestionBankView> createState() => _QuestionBankViewState();
}

/// Entry of the flattened list: a course/lesson header or a question.
class _BankItem {
  const _BankItem.header(this.row) : number = null;
  const _BankItem.question(this.row, int this.number);

  final QuestionBankRow row;
  final int? number;

  bool get isHeader => number == null;
}

class _QuestionBankViewState extends State<_QuestionBankView> {
  List<QuestionBankRow>? _rows;
  String? _error;
  var _loading = true;
  var _filter = const QuestionBankFilter();
  var _loadingCourses = false;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await widget.repository.fetchQuestionBank();
      if (!mounted) return;
      setState(() => _rows = rows);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _setFilter(QuestionBankFilter filter) =>
      setState(() => _filter = filter);

  /// Number of each question inside its lesson (over the whole bank).
  Map<int, int> _numbers(List<QuestionBankRow> rows) {
    final counters = <int, int>{};
    return {
      for (final row in rows)
        row.id: counters.update(
          row.lessonId,
          (value) => value + 1,
          ifAbsent: () => 1,
        ),
    };
  }

  List<_BankItem> _items(List<QuestionBankRow> visible, Map<int, int> numbers) {
    final items = <_BankItem>[];
    int? lastLessonId;
    for (final row in visible) {
      if (row.lessonId != lastLessonId) {
        items.add(_BankItem.header(row));
        lastLessonId = row.lessonId;
      }
      items.add(_BankItem.question(row, numbers[row.id] ?? 1));
    }
    return items;
  }

  /// Saves an edited question. Returns an error message, or null.
  Future<String?> _saveQuestion(
    QuestionBankRow row,
    PracticeQuestion question,
  ) async {
    final errors = practiceQuestionErrors(question);
    if (errors.isNotEmpty) return _formatErrors(errors);
    try {
      final saved = await widget.repository.updateBankQuestion(
        row.id,
        question,
      );
      if (!mounted) return null;
      setState(() {
        final rows = [...?_rows];
        final index = rows.indexWhere((item) => item.id == row.id);
        if (index == -1) {
          rows.add(saved);
        } else {
          // The server may answer with a new id (old question retired).
          rows[index] = saved;
        }
        _rows = rows;
      });
      _showSnack(context, 'Pregunta actualizada');
      return null;
    } on ApiException catch (error) {
      return error.message;
    }
  }

  /// Inserts a new row at the end of its lesson group (or course, or list).
  void _insertRow(QuestionBankRow created) {
    final rows = [...?_rows];
    var index = rows.lastIndexWhere((row) => row.lessonId == created.lessonId);
    if (index == -1) {
      index = rows.lastIndexWhere((row) => row.courseId == created.courseId);
    }
    rows.insert(index == -1 ? rows.length : index + 1, created);
    setState(() => _rows = rows);
  }

  /// Creates a question. Returns an error message, or null.
  Future<String?> _createQuestion(
    int lessonId,
    PracticeQuestion question,
  ) async {
    final errors = practiceQuestionErrors(question);
    if (errors.isNotEmpty) return _formatErrors(errors);
    try {
      final created = await widget.repository.createBankQuestion(
        lessonId,
        question,
      );
      if (!mounted) return null;
      _insertRow(created);
      _showSnack(
        context,
        'Pregunta agregada al banco de «Lección ${created.lessonSortOrder}: ${created.lessonTitle}»',
      );
      return null;
    } on ApiException catch (error) {
      return error.message;
    }
  }

  Future<void> _openCreate() async {
    if (_loadingCourses) return;
    setState(() => _loadingCourses = true);
    List<Course> courses;
    try {
      courses = await widget.repository.fetchCourses();
    } on ApiException catch (error) {
      if (mounted) {
        _showSnack(
          context,
          'No se pudieron cargar los cursos: ${error.message}',
        );
      }
      return;
    } finally {
      if (mounted) setState(() => _loadingCourses = false);
    }
    if (!mounted) return;

    final withLessons = [
      for (final course in courses)
        if (course.lessons.any((lesson) => lesson.id != null)) course,
    ];
    if (withLessons.isEmpty) {
      _showSnack(
        context,
        'Primero crea un curso con al menos una lección en Cursos.',
      );
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _BankQuestionEditDialog.create(
        courses: withLessons,
        initialCourseId: _filter.courseId,
        initialLessonId: _filter.lessonId,
        onCreate: _createQuestion,
      ),
    );
  }

  void _openEditor(QuestionBankRow row) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _BankQuestionEditDialog(
        row: row,
        onSave: (question) => _saveQuestion(row, question),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeader(
          title: 'Banco de preguntas',
          subtitle:
              'Todas las preguntas de todos los cursos. Cada práctica toma preguntas al azar del banco de su lección.',
          action: widget.canManage
              ? FilledButton.icon(
                  onPressed: _rows == null || _loadingCourses
                      ? null
                      : _openCreate,
                  icon: _loadingCourses
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_rounded),
                  label: const Text('Nueva pregunta'),
                )
              : null,
        ),
        const SizedBox(height: 20),
        Expanded(child: _buildBody(context)),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading && _rows == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _rows == null) {
      return _ErrorRetry(message: _error!, onRetry: _load);
    }

    final rows = _rows ?? const <QuestionBankRow>[];
    final visible = _filter.apply(rows);
    final items = _items(visible, _numbers(rows));
    final navigation = ShellNavigation.maybeOf(context);

    return RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _metrics(visible)),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
          SliverToBoxAdapter(child: _filters(context, rows, visible.length)),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          if (items.isEmpty)
            const SliverToBoxAdapter(
              child: _EmptyState(
                icon: Icons.quiz_outlined,
                message: 'No hay preguntas con estos filtros',
              ),
            )
          else
            SliverList.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                if (item.isHeader) {
                  return Padding(
                    padding: EdgeInsets.only(
                      top: index == 0 ? 0 : 18,
                      bottom: 10,
                    ),
                    child: _BankGroupHeader(row: item.row),
                  );
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _BankQuestionCard(
                    row: item.row,
                    number: item.number!,
                    onEdit: widget.canManage
                        ? () => _openEditor(item.row)
                        : null,
                    onOpenCourse: navigation == null
                        ? null
                        : () => navigation.goTo(
                            AppSection.courses,
                            courseId: item.row.courseId,
                          ),
                  ),
                );
              },
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  Widget _metrics(List<QuestionBankRow> visible) {
    final courses = {for (final row in visible) row.courseId}.length;
    final lessons = {for (final row in visible) row.lessonId}.length;

    return LayoutBuilder(
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
              title: 'Preguntas',
              value: '${visible.length}',
              caption: 'Con los filtros aplicados',
              icon: Icons.quiz_rounded,
            ),
            MetricCard(
              title: 'Cursos',
              value: '$courses',
              caption: 'Con preguntas en el resultado',
              icon: Icons.school_rounded,
            ),
            MetricCard(
              title: 'Lecciones',
              value: '$lessons',
              caption: 'Con preguntas en el resultado',
              icon: Icons.menu_book_rounded,
            ),
          ],
        );
      },
    );
  }

  Widget _filters(
    BuildContext context,
    List<QuestionBankRow> rows,
    int resultCount,
  ) {
    final storeRows = [
      for (final row in rows)
        if (_filter.store == null || row.stores.contains(_filter.store)) row,
    ];
    final courses = <int, String>{
      for (final row in storeRows) row.courseId: row.courseTitle,
    };
    final lessons = <int, String>{
      for (final row in storeRows)
        if (row.courseId == _filter.courseId)
          row.lessonId: 'Lección ${row.lessonSortOrder}: ${row.lessonTitle}',
    };

    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ChoiceChip(
                label: const Text('Todas'),
                selected: _filter.store == null,
                onSelected: (_) => _setFilter(
                  _filter.copyWith(
                    clearStore: true,
                    clearCourse: true,
                    clearLesson: true,
                  ),
                ),
              ),
              for (final store in storeCodes)
                ChoiceChip(
                  label: Text(store),
                  selected: _filter.store == store,
                  onSelected: (_) => _setFilter(
                    _filter.copyWith(
                      store: store,
                      clearCourse: true,
                      clearLesson: true,
                    ),
                  ),
                ),
              IconButton(
                onPressed: _loading ? null : _load,
                tooltip: 'Actualizar',
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 260,
                child: DropdownButtonFormField<int?>(
                  key: ValueKey('course-${_filter.store}-${_filter.courseId}'),
                  initialValue: courses.containsKey(_filter.courseId)
                      ? _filter.courseId
                      : null,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Curso',
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Todos'),
                    ),
                    for (final course in courses.entries)
                      DropdownMenuItem<int?>(
                        value: course.key,
                        child: Text(
                          course.value,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) => _setFilter(
                    _filter.copyWith(
                      courseId: value,
                      clearCourse: value == null,
                      clearLesson: true,
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 280,
                child: DropdownButtonFormField<int?>(
                  key: ValueKey(
                    'lesson-${_filter.courseId}-${_filter.lessonId}',
                  ),
                  initialValue: lessons.containsKey(_filter.lessonId)
                      ? _filter.lessonId
                      : null,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Lección',
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Todas'),
                    ),
                    for (final lesson in lessons.entries)
                      DropdownMenuItem<int?>(
                        value: lesson.key,
                        child: Text(
                          lesson.value,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: _filter.courseId == null
                      ? null
                      : (value) => _setFilter(
                          _filter.copyWith(
                            lessonId: value,
                            clearLesson: value == null,
                          ),
                        ),
                ),
              ),
              SizedBox(
                width: 210,
                child: DropdownButtonFormField<AnswerMode?>(
                  initialValue: _filter.answerMode,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de respuesta',
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem<AnswerMode?>(
                      value: null,
                      child: Text('Todas'),
                    ),
                    DropdownMenuItem<AnswerMode?>(
                      value: AnswerMode.single,
                      child: Text('Una correcta'),
                    ),
                    DropdownMenuItem<AnswerMode?>(
                      value: AnswerMode.multiple,
                      child: Text('Varias correctas'),
                    ),
                  ],
                  onChanged: (value) => _setFilter(
                    _filter.copyWith(
                      answerMode: value,
                      clearAnswerMode: value == null,
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 320,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    isDense: true,
                    prefixIcon: const Icon(Icons.search_rounded),
                    hintText: 'Buscar en enunciados y opciones',
                    suffixIcon: _filter.search.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchController.clear();
                              _setFilter(_filter.copyWith(search: ''));
                            },
                            icon: const Icon(Icons.close_rounded),
                            tooltip: 'Limpiar búsqueda',
                          ),
                  ),
                  onChanged: (value) =>
                      _setFilter(_filter.copyWith(search: value)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            resultCount == 1 ? '1 pregunta' : '$resultCount preguntas',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _BankGroupHeader extends StatelessWidget {
  const _BankGroupHeader({required this.row});

  final QuestionBankRow row;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          '${row.courseTitle} · Lección ${row.lessonSortOrder}: ${row.lessonTitle}',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        _StatusPill(
          label: row.courseStatus.label,
          color: row.courseStatus == CourseStatus.active
              ? BrandColors.success
              : colorScheme.tertiary,
        ),
        if (!row.courseActive)
          _StatusPill(label: 'Inactivo', color: colorScheme.error),
        for (final store in row.stores) _StatusPill(label: store),
      ],
    );
  }
}

class _BankQuestionCard extends StatelessWidget {
  const _BankQuestionCard({
    required this.row,
    required this.number,
    required this.onEdit,
    required this.onOpenCourse,
  });

  final QuestionBankRow row;
  final int number;
  final VoidCallback? onEdit;
  final VoidCallback? onOpenCourse;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final question = row.question;
    final imageUrl = question.imageUrl ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: colorScheme.primary,
                child: Text(
                  '$number',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      question.prompt,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _StatusPill(
                          label: question.type == QuestionType.image
                              ? 'Imagen'
                              : 'Texto',
                        ),
                        _StatusPill(
                          label: question.answerMode == AnswerMode.multiple
                              ? 'Varias correctas'
                              : 'Una correcta',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (onOpenCourse != null)
                TextButton.icon(
                  onPressed: onOpenCourse,
                  icon: const Icon(Icons.school_outlined, size: 18),
                  label: const Text('Ir al curso'),
                ),
              if (onEdit != null)
                OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_rounded, size: 18),
                  label: const Text('Editar'),
                ),
            ],
          ),
          if (imageUrl.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: 240,
              child: _QuestionImage(url: imageUrl, height: 130),
            ),
          ],
          const SizedBox(height: 10),
          for (final option in question.options)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(
                    option.isCorrect
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 18,
                    color: option.isCorrect
                        ? BrandColors.success
                        : colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      option.label,
                      style: TextStyle(
                        color: option.isCorrect ? BrandColors.success : null,
                        fontWeight: option.isCorrect
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

String _formatErrors(List<String> errors) =>
    'Revisa estos puntos antes de guardar:\n'
    '${errors.map((error) => '• ${error[0].toUpperCase()}${error.substring(1)}').join('\n')}';

/// Edits one question of the bank, or creates a new one in a chosen
/// lesson, reusing the course editor's question card.
class _BankQuestionEditDialog extends StatefulWidget {
  const _BankQuestionEditDialog({
    required QuestionBankRow this.row,
    required this.onSave,
  }) : courses = const [],
       initialCourseId = null,
       initialLessonId = null,
       onCreate = null;

  const _BankQuestionEditDialog.create({
    required this.courses,
    required this.initialCourseId,
    required this.initialLessonId,
    required this.onCreate,
  }) : row = null,
       onSave = null;

  final QuestionBankRow? row;
  final Future<String?> Function(PracticeQuestion question)? onSave;

  /// Create mode: courses (with lessons) to choose from.
  final List<Course> courses;
  final int? initialCourseId;
  final int? initialLessonId;
  final Future<String?> Function(int lessonId, PracticeQuestion question)?
  onCreate;

  bool get isCreate => row == null;

  @override
  State<_BankQuestionEditDialog> createState() =>
      _BankQuestionEditDialogState();
}

class _BankQuestionEditDialogState extends State<_BankQuestionEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late PracticeQuestion _draft =
      widget.row?.question ?? PracticeQuestion.blank();
  var _dirty = false;
  var _saving = false;
  var _generation = 0;
  String? _error;
  int? _courseId;
  int? _lessonId;

  @override
  void initState() {
    super.initState();
    if (widget.isCreate) {
      final course = _courseById(widget.initialCourseId);
      _courseId = course?.id;
      if (course != null &&
          course.lessons.any((lesson) => lesson.id == widget.initialLessonId)) {
        _lessonId = widget.initialLessonId;
      }
    }
  }

  Course? _courseById(int? id) {
    for (final course in widget.courses) {
      if (course.id == id) return course;
    }
    return null;
  }

  Future<void> _requestClose() async {
    if (_saving) return;
    if (_dirty) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('¿Descartar los cambios?'),
          content: const Text(
            'Tienes cambios sin guardar en esta pregunta. Si cierras, se pierden.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Descartar'),
            ),
          ],
        ),
      );
      if (discard != true || !mounted) return;
    }
    Navigator.of(context).pop();
  }

  Future<void> _save({bool addAnother = false}) async {
    if (_saving) return;
    _formKey.currentState?.validate();
    if (widget.isCreate && (_courseId == null || _lessonId == null)) {
      setState(() => _error = 'Elige el curso y la lección.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final error = widget.isCreate
        ? await widget.onCreate!(_lessonId!, _draft)
        : await widget.onSave!(_draft);
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _saving = false;
        _error = error;
      });
      return;
    }
    if (!addAnother) {
      Navigator.of(context).pop();
      return;
    }
    // Same course and lesson, empty question.
    setState(() {
      _saving = false;
      _dirty = false;
      _draft = PracticeQuestion.blank();
      _generation++;
    });
  }

  Widget _lessonPickers() {
    final course = _courseById(_courseId);
    final lessons = [
      for (final lesson in (course?.lessons ?? const <Lesson>[]).indexed)
        if (lesson.$2.id != null) lesson,
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        SizedBox(
          width: 340,
          child: DropdownButtonFormField<int>(
            initialValue: _courseId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Curso'),
            items: [
              for (final course in widget.courses)
                DropdownMenuItem(
                  value: course.id,
                  child: Text(course.title, overflow: TextOverflow.ellipsis),
                ),
            ],
            validator: (value) =>
                value == null ? 'Elige el curso y la lección.' : null,
            onChanged: _saving
                ? null
                : (value) => setState(() {
                    _courseId = value;
                    _lessonId = null;
                  }),
          ),
        ),
        SizedBox(
          width: 360,
          child: DropdownButtonFormField<int>(
            key: ValueKey('bank-lesson-$_courseId'),
            initialValue: _lessonId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Lección'),
            items: [
              for (final lesson in lessons)
                DropdownMenuItem(
                  value: lesson.$2.id,
                  child: Text(
                    'Lección ${lesson.$1 + 1}: ${lesson.$2.title}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            validator: (value) =>
                value == null ? 'Elige el curso y la lección.' : null,
            onChanged: _saving || course == null
                ? null
                : (value) => setState(() => _lessonId = value),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    final colorScheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: !_dirty && !_saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _requestClose();
      },
      child: Dialog(
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 820,
            maxHeight: MediaQuery.sizeOf(context).height * 0.9,
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            row == null
                                ? 'Banco de preguntas'
                                : '${row.courseTitle} · Lección ${row.lessonSortOrder}: ${row.lessonTitle}',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            row == null ? 'Nueva pregunta' : 'Editar pregunta',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _saving ? null : _requestClose,
                      icon: const Icon(Icons.close_rounded),
                      tooltip: 'Cerrar',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: Form(
                    key: _formKey,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (widget.isCreate) ...[
                            _lessonPickers(),
                            const SizedBox(height: 16),
                          ],
                          KeyedSubtree(
                            key: ValueKey('bank-question-$_generation'),
                            child: _QuestionEditorCard.standalone(
                              question: _draft,
                              onChanged: (question) => setState(() {
                                _draft = question;
                                _dirty = true;
                              }),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 120),
                    child: SingleChildScrollView(
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: colorScheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_rounded),
                      label: Text(
                        _saving ? 'Guardando...' : 'Guardar pregunta',
                      ),
                    ),
                    if (widget.isCreate)
                      OutlinedButton.icon(
                        onPressed: _saving
                            ? null
                            : () => _save(addAnother: true),
                        icon: const Icon(Icons.playlist_add_rounded),
                        label: const Text('Guardar y agregar otra'),
                      ),
                    OutlinedButton.icon(
                      onPressed: _saving ? null : _requestClose,
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('Cancelar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
