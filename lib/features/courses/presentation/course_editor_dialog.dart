part of 'courses_page.dart';

/// Template editor for a course (courses.manage). Works on a copy of the
/// course; ids of existing lessons/questions/options are kept so the server
/// updates them in place.
class _CourseTemplateEditorDialog extends StatefulWidget {
  const _CourseTemplateEditorDialog({
    required this.course,
    required this.initialLessonIndex,
    required this.onSave,
  });

  final Course course;
  final int initialLessonIndex;

  /// Persists the draft. Returns an error message, or null on success.
  final Future<String?> Function(Course course) onSave;

  @override
  State<_CourseTemplateEditorDialog> createState() =>
      _CourseTemplateEditorDialogState();
}

class _CourseTemplateEditorDialogState
    extends State<_CourseTemplateEditorDialog> {
  late Course _draft;
  late final TextEditingController _theoryImagesController;
  var _selectedLessonIndex = 0;
  var _questionSearchQuery = '';
  var _isPastingTheoryImage = false;
  var _saving = false;
  var _dirty = false;
  String? _saveError;
  final _formKey = GlobalKey<FormState>();

  bool get _isNew => widget.course.id == null;

  @override
  void initState() {
    super.initState();
    _draft = widget.course;
    _selectedLessonIndex = widget.initialLessonIndex.clamp(
      0,
      _draft.lessons.length - 1,
    );
    _theoryImagesController = TextEditingController(
      text: _selectedLesson.theoryImageUrls.join('\n'),
    );
  }

  @override
  void dispose() {
    _theoryImagesController.dispose();
    super.dispose();
  }

  Lesson get _selectedLesson => _draft.lessons[_selectedLessonIndex];

  bool _questionMatchesSearch(PracticeQuestion question) {
    final query = _questionSearchQuery.trim().toLowerCase();
    if (query.isEmpty) return true;

    final searchableText = [
      question.prompt,
      for (final option in question.options) option.label,
    ].join(' ').toLowerCase();

    return searchableText.contains(query);
  }

  List<({int lessonIndex, int questionIndex, PracticeQuestion question})>
  get _questionSearchMatches {
    final query = _questionSearchQuery.trim();
    if (query.isEmpty) return const [];

    return [
      for (final lesson in _draft.lessons.indexed)
        for (final question in lesson.$2.questions.indexed)
          if (_questionMatchesSearch(question.$2))
            (
              lessonIndex: lesson.$1,
              questionIndex: question.$1,
              question: question.$2,
            ),
    ];
  }

  void _replaceCourse(Course course) => setState(() {
    _draft = course;
    _dirty = true;
  });

  void _replaceSelectedLesson(Lesson lesson) {
    final lessons = [..._draft.lessons];
    lessons[_selectedLessonIndex] = lesson;
    _replaceCourse(_draft.copyWith(lessons: lessons));
  }

  void _syncTheoryImagesController() {
    final text = _selectedLesson.theoryImageUrls.join('\n');
    _theoryImagesController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _selectLesson(int lessonIndex) {
    setState(() {
      _selectedLessonIndex = lessonIndex;
      _syncTheoryImagesController();
    });
  }

  List<String> _theoryImageUrlsFromText(String value) {
    return value
        .split('\n')
        .map((url) => url.trim())
        .where((url) => url.isNotEmpty)
        .toList();
  }

  void _replaceTheoryImageUrls(List<String> imageUrls) {
    _replaceSelectedLesson(
      _selectedLesson.copyWith(theoryImageUrls: imageUrls),
    );
  }

  Future<void> _pasteTheoryImageFromClipboard() async {
    setState(() => _isPastingTheoryImage = true);

    try {
      final dataUrl = await readClipboardImageDataUrl();
      if (!mounted) return;

      if (dataUrl == null) {
        _showSnack(
          context,
          'No se encontró una imagen en el portapapeles. Copia una captura y pégala desde Chrome.',
        );
        return;
      }

      final imageUrls = [..._selectedLesson.theoryImageUrls, dataUrl];
      _replaceTheoryImageUrls(imageUrls);
      _syncTheoryImagesController();
      _showSnack(context, 'Imagen pegada en la teoría.');
    } catch (_) {
      if (!mounted) return;
      _showSnack(
        context,
        'Chrome no permitió leer la imagen. Usa el botón después de copiar la captura y acepta el permiso del portapapeles.',
      );
    } finally {
      if (mounted) setState(() => _isPastingTheoryImage = false);
    }
  }

  void _replaceQuestion(int questionIndex, PracticeQuestion question) {
    final questions = [..._selectedLesson.questions];
    questions[questionIndex] = question;
    _replaceSelectedLesson(_selectedLesson.copyWith(questions: questions));
  }

  void _moveQuestionToLesson(int questionIndex, int targetLessonIndex) {
    if (targetLessonIndex == _selectedLessonIndex) return;
    if (_selectedLesson.questions.length == 1) return;

    final lessons = [..._draft.lessons];
    final sourceLesson = lessons[_selectedLessonIndex];
    final targetLesson = lessons[targetLessonIndex];
    final sourceQuestions = [...sourceLesson.questions];
    // A question belongs to one lesson on the server: moving it creates a
    // new question in the target lesson and retires the old one.
    final question = sourceQuestions.removeAt(questionIndex).withoutIds();

    lessons[_selectedLessonIndex] = sourceLesson.copyWith(
      questions: sourceQuestions,
    );
    lessons[targetLessonIndex] = targetLesson.copyWith(
      questions: [...targetLesson.questions, question],
    );

    setState(() {
      _draft = _draft.copyWith(lessons: lessons);
      _dirty = true;
      _selectedLessonIndex = targetLessonIndex;
      _syncTheoryImagesController();
    });
  }

  void _addLesson() {
    final lessons = [..._draft.lessons, Lesson.template()];
    setState(() {
      _draft = _draft.copyWith(lessons: lessons);
      _dirty = true;
      _selectedLessonIndex = lessons.length - 1;
      _syncTheoryImagesController();
    });
  }

  Future<void> _removeSelectedLesson() async {
    if (_draft.lessons.length == 1) return;

    final confirmed = await _confirm(
      title: '¿Eliminar la lección "${_selectedLesson.title}"?',
      message: _selectedLesson.id == null
          ? 'Se quitará esta lección nueva con sus preguntas.'
          : 'Al guardar, la lección dejará de verse para los alumnos. El avance ya registrado se conserva en el historial.',
      action: 'Eliminar',
    );
    if (!confirmed || !mounted) return;

    final lessons = [..._draft.lessons]..removeAt(_selectedLessonIndex);
    setState(() {
      _draft = _draft.copyWith(lessons: lessons);
      _dirty = true;
      _selectedLessonIndex = _selectedLessonIndex.clamp(0, lessons.length - 1);
      _syncTheoryImagesController();
    });
  }

  void _moveSelectedLesson(int direction) {
    final toIndex = _selectedLessonIndex + direction;
    if (toIndex < 0 || toIndex >= _draft.lessons.length) return;

    final lessons = [..._draft.lessons];
    final lesson = lessons.removeAt(_selectedLessonIndex);
    lessons.insert(toIndex, lesson);
    setState(() {
      _draft = _draft.copyWith(lessons: lessons);
      _dirty = true;
      _selectedLessonIndex = toIndex;
    });
  }

  void _moveQuestion(int fromIndex, int direction) {
    final toIndex = fromIndex + direction;
    if (toIndex < 0 || toIndex >= _selectedLesson.questions.length) {
      return;
    }

    final questions = [..._selectedLesson.questions];
    final question = questions.removeAt(fromIndex);
    questions.insert(toIndex, question);
    _replaceSelectedLesson(_selectedLesson.copyWith(questions: questions));
  }

  void _addQuestion() {
    _replaceSelectedLesson(
      _selectedLesson.copyWith(
        questions: [..._selectedLesson.questions, PracticeQuestion.blank()],
      ),
    );
  }

  Future<void> _removeQuestion(int questionIndex) async {
    if (_selectedLesson.questions.length == 1) return;
    final confirmed = await _confirm(
      title: '¿Eliminar la pregunta ${questionIndex + 1}?',
      message:
          'Se quitará de la lección ${_selectedLessonIndex + 1}. Las respuestas ya registradas se conservan en el historial.',
      action: 'Eliminar',
    );
    if (!confirmed || !mounted) return;

    final questions = [..._selectedLesson.questions]..removeAt(questionIndex);
    _replaceSelectedLesson(_selectedLesson.copyWith(questions: questions));
  }

  void _toggleStore(String store, bool selected) {
    final stores = [..._draft.stores];
    if (selected) {
      if (!stores.contains(store)) stores.add(store);
    } else {
      stores.remove(store);
    }
    _replaceCourse(_draft.copyWith(stores: stores));
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String action,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(action),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _requestClose() async {
    if (_saving) return;
    if (_dirty) {
      final discard = await _confirm(
        title: '¿Descartar los cambios?',
        message:
            'Tienes cambios sin guardar en este curso. Si cierras, se pierden.',
        action: 'Descartar',
      );
      if (!discard || !mounted) return;
    }
    Navigator.of(context).pop();
  }

  Future<void> _save() async {
    if (_saving) return;
    _formKey.currentState?.validate();
    final errors = _draft.validationErrors();
    if (errors.isNotEmpty) {
      setState(
        () => _saveError =
            'Revisa estos puntos antes de guardar:\n${errors.map((error) => '• $error').join('\n')}',
      );
      return;
    }
    setState(() {
      _saving = true;
      _saveError = null;
    });
    final error = await widget.onSave(_draft);
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _saving = false;
      _saveError = error;
    });
  }

  InputDecoration _fieldDecoration() {
    final colorScheme = Theme.of(context).colorScheme;

    return InputDecoration(
      filled: true,
      fillColor: colorScheme.surface,
      border: const OutlineInputBorder(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final bankSize = _selectedLesson.questions.length;

    return PopScope(
      canPop: !_dirty && !_saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _requestClose();
      },
      child: Dialog(
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 920,
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
                            _isNew
                                ? 'Nuevo curso'
                                : 'Editor · Lección ${_selectedLessonIndex + 1}',
                            style: textTheme.labelLarge,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _isNew
                                ? 'Crear plantilla de curso'
                                : 'Editar ${_draft.title}',
                            style: textTheme.headlineSmall,
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
                const SizedBox(height: 8),
                const Text(
                  'Los cambios se guardan en el servidor al tocar "Guardar curso". Las secciones y preguntas existentes se actualizan sin perder el avance de los alumnos.',
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: Form(
                    key: _formKey,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 112),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _EditorFieldLabel('Título del curso/módulo'),
                          const SizedBox(height: 6),
                          TextFormField(
                            initialValue: _draft.title,
                            decoration: _fieldDecoration(),
                            validator: (value) =>
                                _requiredText(value, max: 120),
                            onChanged: (value) =>
                                _replaceCourse(_draft.copyWith(title: value)),
                          ),
                          const SizedBox(height: 12),
                          const _EditorFieldLabel('Descripción'),
                          const SizedBox(height: 6),
                          TextFormField(
                            initialValue: _draft.description ?? '',
                            decoration: _fieldDecoration(),
                            minLines: 1,
                            maxLines: 3,
                            onChanged: (value) => _replaceCourse(
                              _draft.copyWith(description: value),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 24,
                            runSpacing: 12,
                            crossAxisAlignment: WrapCrossAlignment.end,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const _EditorFieldLabel('Tiendas asignadas'),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 8,
                                    children: [
                                      for (final store in storeCodes)
                                        FilterChip(
                                          label: Text(store),
                                          selected: _draft.stores.contains(
                                            store,
                                          ),
                                          onSelected: (selected) =>
                                              _toggleStore(store, selected),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                              SizedBox(
                                width: 220,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const _EditorFieldLabel('Estado'),
                                    const SizedBox(height: 6),
                                    DropdownButtonFormField<CourseStatus>(
                                      initialValue: _draft.status,
                                      decoration: _fieldDecoration(),
                                      items: [
                                        for (final status
                                            in CourseStatus.values)
                                          DropdownMenuItem(
                                            value: status,
                                            child: Text(status.label),
                                          ),
                                      ],
                                      onChanged: (value) {
                                        if (value != null) {
                                          _replaceCourse(
                                            _draft.copyWith(status: value),
                                          );
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 32),
                          const _EditorFieldLabel('Sección/lección a editar'),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<int>(
                            key: ValueKey(
                              'lesson-select-$_selectedLessonIndex-${_draft.lessons.length}',
                            ),
                            initialValue: _selectedLessonIndex,
                            decoration: _fieldDecoration(),
                            items: [
                              for (final lesson in _draft.lessons.indexed)
                                DropdownMenuItem<int>(
                                  value: lesson.$1,
                                  child: Text(
                                    '${lesson.$1 + 1}. ${lesson.$2.title}',
                                  ),
                                ),
                            ],
                            onChanged: (value) {
                              if (value != null) _selectLesson(value);
                            },
                          ),
                          const SizedBox(height: 10),
                          const _EditorFieldLabel('Buscar preguntas del curso'),
                          const SizedBox(height: 6),
                          TextField(
                            decoration: _fieldDecoration().copyWith(
                              prefixIcon: const Icon(Icons.search_rounded),
                              hintText:
                                  'Buscar por texto u opción de respuesta',
                              suffixIcon: _questionSearchQuery.isEmpty
                                  ? null
                                  : IconButton(
                                      onPressed: () => setState(
                                        () => _questionSearchQuery = '',
                                      ),
                                      icon: const Icon(Icons.close_rounded),
                                      tooltip: 'Limpiar búsqueda',
                                    ),
                            ),
                            onChanged: (value) =>
                                setState(() => _questionSearchQuery = value),
                          ),
                          if (_questionSearchQuery.trim().isNotEmpty) ...[
                            const SizedBox(height: 8),
                            _QuestionSearchResults(
                              matches: _questionSearchMatches,
                              lessons: _draft.lessons,
                              onSelected: _selectLesson,
                            ),
                          ],
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed: _addLesson,
                                icon: const Icon(Icons.add_rounded),
                                label: const Text('Agregar sección'),
                              ),
                              IconButton.outlined(
                                onPressed: _selectedLessonIndex > 0
                                    ? () => _moveSelectedLesson(-1)
                                    : null,
                                icon: const Icon(Icons.arrow_upward_rounded),
                                tooltip: 'Subir sección',
                              ),
                              IconButton.outlined(
                                onPressed:
                                    _selectedLessonIndex <
                                        _draft.lessons.length - 1
                                    ? () => _moveSelectedLesson(1)
                                    : null,
                                icon: const Icon(Icons.arrow_downward_rounded),
                                tooltip: 'Bajar sección',
                              ),
                              IconButton.outlined(
                                onPressed: _draft.lessons.length > 1
                                    ? _removeSelectedLesson
                                    : null,
                                icon: const Icon(Icons.delete_outline_rounded),
                                tooltip: 'Eliminar sección',
                              ),
                            ],
                          ),
                          KeyedSubtree(
                            key: ValueKey(
                              'lesson-editor-$_selectedLessonIndex-${_selectedLesson.id}-${_draft.lessons.length}',
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 16),
                                const _EditorFieldLabel(
                                  'Título de la sección/lección',
                                ),
                                const SizedBox(height: 6),
                                TextFormField(
                                  initialValue: _selectedLesson.title,
                                  decoration: _fieldDecoration(),
                                  validator: (value) =>
                                      _requiredText(value, max: 160),
                                  onChanged: (value) => _replaceSelectedLesson(
                                    _selectedLesson.copyWith(title: value),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const _EditorFieldLabel('Resultado/resumen'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  initialValue: _selectedLesson.summary,
                                  decoration: _fieldDecoration(),
                                  validator: _requiredText,
                                  minLines: 2,
                                  maxLines: 4,
                                  onChanged: (value) => _replaceSelectedLesson(
                                    _selectedLesson.copyWith(summary: value),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const _EditorFieldLabel('Texto de teoría'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  initialValue: _selectedLesson.theory,
                                  decoration: _fieldDecoration(),
                                  validator: _requiredText,
                                  minLines: 4,
                                  maxLines: 8,
                                  onChanged: (value) => _replaceSelectedLesson(
                                    _selectedLesson.copyWith(theory: value),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const _EditorFieldLabel(
                                  'Imágenes de teoría por URL',
                                ),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: _theoryImagesController,
                                  decoration: _fieldDecoration().copyWith(
                                    hintText:
                                        'Pega una URL o data URL por línea. Se muestran debajo del contenido teórico.',
                                  ),
                                  minLines: 2,
                                  maxLines: 5,
                                  onChanged: (value) => _replaceTheoryImageUrls(
                                    _theoryImageUrlsFromText(value),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: _isPastingTheoryImage
                                          ? null
                                          : _pasteTheoryImageFromClipboard,
                                      icon: Icon(
                                        _isPastingTheoryImage
                                            ? Icons.hourglass_top_rounded
                                            : Icons.content_paste_rounded,
                                      ),
                                      label: Text(
                                        _isPastingTheoryImage
                                            ? 'Pegando imagen...'
                                            : 'Pegar imagen capturada',
                                      ),
                                    ),
                                    const Text(
                                      'La captura se guarda dentro del curso como data URL.',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 16,
                                  runSpacing: 12,
                                  children: [
                                    SizedBox(
                                      width: 220,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const _EditorFieldLabel(
                                            '% de aprobación',
                                          ),
                                          const SizedBox(height: 6),
                                          TextFormField(
                                            initialValue:
                                                '${_selectedLesson.requiredApprovalPercent}',
                                            decoration: _fieldDecoration()
                                                .copyWith(suffixText: '%'),
                                            keyboardType: TextInputType.number,
                                            inputFormatters: [
                                              FilteringTextInputFormatter
                                                  .digitsOnly,
                                            ],
                                            validator: _approvalPercentError,
                                            onChanged: (value) =>
                                                _replaceSelectedLesson(
                                                  _selectedLesson.copyWith(
                                                    requiredApprovalPercent:
                                                        int.tryParse(value) ??
                                                        0,
                                                  ),
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(
                                      width: 320,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const _EditorFieldLabel(
                                            'Preguntas por práctica',
                                          ),
                                          const SizedBox(height: 6),
                                          TextFormField(
                                            key: ValueKey(
                                              'per-attempt-$_selectedLessonIndex-$bankSize',
                                            ),
                                            initialValue:
                                                _selectedLesson
                                                    .questionsPerAttempt
                                                    ?.toString() ??
                                                '',
                                            decoration: _fieldDecoration().copyWith(
                                              hintText: 'Vacío = todas',
                                              helperText:
                                                  'Banco: $bankSize preguntas. Cada práctica toma ${_selectedLesson.practiceSize} al azar.',
                                              helperMaxLines: 2,
                                              errorMaxLines: 2,
                                            ),
                                            keyboardType: TextInputType.number,
                                            inputFormatters: [
                                              FilteringTextInputFormatter
                                                  .digitsOnly,
                                            ],
                                            validator: (value) =>
                                                _questionsPerAttemptFieldError(
                                                  value,
                                                  bankSize,
                                                ),
                                            onChanged: (value) {
                                              final parsed = int.tryParse(
                                                value.trim(),
                                              );
                                              _replaceSelectedLesson(
                                                parsed == null
                                                    ? _selectedLesson.copyWith(
                                                        clearQuestionsPerAttempt:
                                                            true,
                                                      )
                                                    : _selectedLesson.copyWith(
                                                        questionsPerAttempt:
                                                            parsed,
                                                      ),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  'Preguntas de práctica',
                                  style: textTheme.titleMedium,
                                ),
                                const SizedBox(height: 12),
                                for (final question
                                    in _selectedLesson.questions.indexed.where(
                                      (entry) =>
                                          _questionMatchesSearch(entry.$2),
                                    )) ...[
                                  _QuestionEditorCard(
                                    key: ValueKey(
                                      'question-$_selectedLessonIndex-${question.$1}-${question.$2.id}',
                                    ),
                                    number: question.$1 + 1,
                                    question: question.$2,
                                    lessonIndex: _selectedLessonIndex,
                                    lessons: _draft.lessons,
                                    canMoveUp: question.$1 > 0,
                                    canMoveDown:
                                        question.$1 <
                                        _selectedLesson.questions.length - 1,
                                    canRemove:
                                        _selectedLesson.questions.length > 1,
                                    canChangeLesson:
                                        _selectedLesson.questions.length > 1,
                                    onChanged: (updatedQuestion) =>
                                        _replaceQuestion(
                                          question.$1,
                                          updatedQuestion,
                                        ),
                                    onLessonChanged: (lessonIndex) =>
                                        _moveQuestionToLesson(
                                          question.$1,
                                          lessonIndex,
                                        ),
                                    onMoveUp: () =>
                                        _moveQuestion(question.$1, -1),
                                    onMoveDown: () =>
                                        _moveQuestion(question.$1, 1),
                                    onRemove: () =>
                                        _removeQuestion(question.$1),
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                if (_selectedLesson.questions.every(
                                  (question) =>
                                      !_questionMatchesSearch(question),
                                ))
                                  const Padding(
                                    padding: EdgeInsets.only(bottom: 12),
                                    child: Text(
                                      'No hay preguntas en esta lección que coincidan con la búsqueda.',
                                    ),
                                  ),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: OutlinedButton.icon(
                                    onPressed: _addQuestion,
                                    icon: const Icon(Icons.add_rounded),
                                    label: const Text('Agregar pregunta'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    border: Border(
                      top: BorderSide(color: colorScheme.outlineVariant),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_saveError != null) ...[
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 120),
                            child: SingleChildScrollView(
                              child: Text(
                                _saveError!,
                                style: TextStyle(
                                  color: colorScheme.error,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
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
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.save_rounded),
                              label: Text(
                                _saving ? 'Guardando...' : 'Guardar curso',
                              ),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String? _requiredText(String? value, {int? max}) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return 'Este campo es obligatorio.';
  if (max != null && text.length > max) return 'Máximo $max caracteres.';
  return null;
}

String? _approvalPercentError(String? value) {
  final percent = int.tryParse(value?.trim() ?? '');
  if (percent == null || percent < 1 || percent > 100) {
    return 'Escribe un número entre 1 y 100.';
  }
  return null;
}

/// Inline validator for "Preguntas por práctica" (empty = all the bank).
String? _questionsPerAttemptFieldError(String? value, int bankSize) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return null;
  final parsed = int.tryParse(text);
  if (parsed == null) return 'Escribe un número entero.';
  if (parsed < 1 || parsed > bankSize) {
    return 'Debe estar entre 1 y $bankSize (tamaño del banco).';
  }
  return null;
}

class _QuestionSearchResults extends StatelessWidget {
  const _QuestionSearchResults({
    required this.matches,
    required this.lessons,
    required this.onSelected,
  });

  final List<({int lessonIndex, int questionIndex, PracticeQuestion question})>
  matches;
  final List<Lesson> lessons;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (matches.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.errorContainer.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'No encontré preguntas con esa palabra clave.',
          style: TextStyle(color: colorScheme.onErrorContainer),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final match in matches)
          ActionChip(
            avatar: const Icon(Icons.search_rounded, size: 18),
            label: Text(
              'L${match.lessonIndex + 1} · P${match.questionIndex + 1}: ${match.question.prompt.isEmpty ? 'Sin texto' : match.question.prompt}',
              overflow: TextOverflow.ellipsis,
            ),
            tooltip: lessons[match.lessonIndex].title,
            onPressed: () => onSelected(match.lessonIndex),
          ),
      ],
    );
  }
}

class _QuestionEditorCard extends StatelessWidget {
  const _QuestionEditorCard({
    super.key,
    required this.number,
    required this.question,
    required this.lessonIndex,
    required this.lessons,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.canRemove,
    required this.canChangeLesson,
    required this.onChanged,
    required this.onLessonChanged,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onRemove,
  }) : standalone = false;

  /// Edits a single question outside the course editor (question bank):
  /// hides ordering, removal and the lesson picker.
  const _QuestionEditorCard.standalone({
    required this.question,
    required this.onChanged,
  }) : number = 1,
       lessonIndex = 0,
       lessons = const [],
       canMoveUp = false,
       canMoveDown = false,
       canRemove = false,
       canChangeLesson = false,
       onLessonChanged = _ignoreInt,
       onMoveUp = _noop,
       onMoveDown = _noop,
       onRemove = _noop,
       standalone = true;

  static void _ignoreInt(int _) {}
  static void _noop() {}

  final bool standalone;
  final int number;
  final PracticeQuestion question;
  final int lessonIndex;
  final List<Lesson> lessons;
  final bool canMoveUp;
  final bool canMoveDown;
  final bool canRemove;
  final bool canChangeLesson;
  final ValueChanged<PracticeQuestion> onChanged;
  final ValueChanged<int> onLessonChanged;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onRemove;

  List<QuestionOption> _withCorrect(Set<int> correctIndexes) => [
    for (final option in question.options.indexed)
      option.$2.copyWith(isCorrect: correctIndexes.contains(option.$1)),
  ];

  void _replaceOption(int optionIndex, String value) {
    final options = [...question.options];
    options[optionIndex] = options[optionIndex].copyWith(label: value);
    onChanged(question.copyWith(options: options));
  }

  void _addOption() {
    onChanged(
      question.copyWith(
        options: [
          ...question.options,
          const QuestionOption(label: ''),
        ],
      ),
    );
  }

  void _removeOption(int optionIndex) {
    if (question.options.length <= 2) return;

    final options = [...question.options]..removeAt(optionIndex);
    if (!options.any((option) => option.isCorrect)) {
      options[0] = options[0].copyWith(isCorrect: true);
    }
    onChanged(question.copyWith(options: options));
  }

  void _setAnswerMode(AnswerMode mode) {
    var options = question.options;
    final correct = question.correctOptionIndexes;
    if (mode == AnswerMode.single && correct.length != 1) {
      options = _withCorrect({correct.isEmpty ? 0 : correct.first});
    }
    onChanged(question.copyWith(answerMode: mode, options: options));
  }

  void _setSingleCorrectOption(int optionIndex) {
    onChanged(question.copyWith(options: _withCorrect({optionIndex})));
  }

  void _toggleMultipleCorrectOption(int optionIndex) {
    final correct = question.correctOptionIndexes.toSet();

    if (correct.contains(optionIndex)) {
      if (correct.length == 1) return;
      correct.remove(optionIndex);
    } else {
      correct.add(optionIndex);
    }
    onChanged(question.copyWith(options: _withCorrect(correct)));
  }

  Future<void> _pastePracticeImageFromClipboard(BuildContext context) async {
    try {
      final dataUrl = await readClipboardImageDataUrl();
      if (!context.mounted) return;

      if (dataUrl == null) {
        _showSnack(
          context,
          'No se encontró una imagen en el portapapeles. Copia una captura y vuelve a intentar.',
        );
        return;
      }

      onChanged(question.copyWith(type: QuestionType.image, imageUrl: dataUrl));
      _showSnack(context, 'Imagen pegada en la pregunta.');
    } catch (_) {
      if (!context.mounted) return;
      _showSnack(
        context,
        'Chrome no permitió leer la imagen. Copia la captura, toca el botón y acepta el permiso del portapapeles.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    InputDecoration fieldDecoration() {
      return InputDecoration(
        filled: true,
        fillColor: colorScheme.surface,
        border: const OutlineInputBorder(),
      );
    }

    final correctIndexes = question.correctOptionIndexes;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.85),
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!standalone) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Lección ${lessonIndex + 1} · Pregunta $number',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: canMoveUp ? onMoveUp : null,
                  icon: const Icon(Icons.arrow_upward_rounded),
                  tooltip: 'Subir pregunta',
                ),
                IconButton(
                  onPressed: canMoveDown ? onMoveDown : null,
                  icon: const Icon(Icons.arrow_downward_rounded),
                  tooltip: 'Bajar pregunta',
                ),
                IconButton(
                  onPressed: canRemove ? onRemove : null,
                  icon: const Icon(Icons.delete_outline_rounded),
                  tooltip: 'Eliminar pregunta',
                ),
              ],
            ),
            const SizedBox(height: 12),
            const _EditorFieldLabel('Lección asociada'),
            const SizedBox(height: 6),
            DropdownButtonFormField<int>(
              initialValue: lessonIndex,
              decoration: fieldDecoration(),
              items: [
                for (final lesson in lessons.indexed)
                  DropdownMenuItem<int>(
                    value: lesson.$1,
                    child: Text('${lesson.$1 + 1}. ${lesson.$2.title}'),
                  ),
              ],
              onChanged: canChangeLesson
                  ? (value) {
                      if (value != null) onLessonChanged(value);
                    }
                  : null,
            ),
            if (!canChangeLesson) ...[
              const SizedBox(height: 8),
              const Text(
                'Esta pregunta no se puede mover porque la sección quedaría sin preguntas.',
              ),
            ],
            const SizedBox(height: 12),
          ],
          const _EditorFieldLabel('Contenido visual de la pregunta'),
          const SizedBox(height: 6),
          DropdownButtonFormField<QuestionType>(
            initialValue: question.type,
            decoration: fieldDecoration(),
            items: const [
              DropdownMenuItem(value: QuestionType.text, child: Text('Texto')),
              DropdownMenuItem(
                value: QuestionType.image,
                child: Text('Imagen'),
              ),
            ],
            onChanged: (value) {
              if (value != null) onChanged(question.copyWith(type: value));
            },
          ),
          if (question.type == QuestionType.text) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _pastePracticeImageFromClipboard(context),
              icon: const Icon(Icons.content_paste_rounded),
              label: const Text(
                'Pegar captura y convertir en pregunta con foto',
              ),
            ),
          ],
          if (question.type == QuestionType.image) ...[
            const SizedBox(height: 8),
            const _EditorFieldLabel('Foto de práctica'),
            const SizedBox(height: 6),
            TextFormField(
              key: ValueKey(
                'practice-image-$lessonIndex-$number-${question.imageUrl ?? ''}',
              ),
              initialValue: question.imageUrl ?? '',
              decoration: fieldDecoration().copyWith(
                hintText:
                    'Pega una URL o usa el botón para pegar una captura copiada.',
              ),
              onChanged: (value) => onChanged(
                question.copyWith(
                  imageUrl: value.trim().isEmpty ? null : value,
                  clearImageUrl: value.trim().isEmpty,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _pastePracticeImageFromClipboard(context),
                  icon: const Icon(Icons.content_paste_rounded),
                  label: const Text('Pegar captura copiada'),
                ),
                if (question.imageUrl != null && question.imageUrl!.isNotEmpty)
                  TextButton.icon(
                    onPressed: () =>
                        onChanged(question.copyWith(clearImageUrl: true)),
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Quitar foto'),
                  ),
              ],
            ),
            if (question.imageUrl != null && question.imageUrl!.isNotEmpty) ...[
              const SizedBox(height: 8),
              _QuestionImage(url: question.imageUrl!, height: 160),
            ],
          ],
          const SizedBox(height: 12),
          const _EditorFieldLabel('Tipo de respuesta'),
          const SizedBox(height: 6),
          DropdownButtonFormField<AnswerMode>(
            initialValue: question.answerMode,
            decoration: fieldDecoration(),
            items: const [
              DropdownMenuItem(
                value: AnswerMode.single,
                child: Text('Una respuesta correcta'),
              ),
              DropdownMenuItem(
                value: AnswerMode.multiple,
                child: Text('Varias respuestas correctas'),
              ),
            ],
            onChanged: (value) {
              if (value != null) _setAnswerMode(value);
            },
          ),
          const SizedBox(height: 12),
          const _EditorFieldLabel('Texto de la pregunta'),
          const SizedBox(height: 6),
          TextFormField(
            initialValue: question.prompt,
            decoration: fieldDecoration(),
            minLines: 2,
            maxLines: 4,
            validator: (value) => (value ?? '').trim().isEmpty
                ? 'Escribe el enunciado de la pregunta.'
                : null,
            onChanged: (value) => onChanged(question.copyWith(prompt: value)),
          ),
          const SizedBox(height: 12),
          RadioGroup<int>(
            groupValue: correctIndexes.isEmpty ? null : correctIndexes.first,
            onChanged: (value) {
              if (value != null) _setSingleCorrectOption(value);
            },
            child: Column(
              children: [
                for (final option in question.options.indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 28),
                          child: question.answerMode == AnswerMode.multiple
                              ? Checkbox(
                                  value: option.$2.isCorrect,
                                  onChanged: (_) =>
                                      _toggleMultipleCorrectOption(option.$1),
                                )
                              : Radio<int>(value: option.$1),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _EditorFieldLabel(
                                      'Opción ${option.$1 + 1}',
                                    ),
                                  ),
                                  if (option.$2.isCorrect) ...[
                                    const _OptionTruthPill(correct: true),
                                    if (question.answerMode ==
                                        AnswerMode.multiple)
                                      TextButton.icon(
                                        onPressed: correctIndexes.length > 1
                                            ? () =>
                                                  _toggleMultipleCorrectOption(
                                                    option.$1,
                                                  )
                                            : null,
                                        icon: const Icon(
                                          Icons.remove_circle_outline_rounded,
                                          size: 16,
                                        ),
                                        label: const Text('Quitar correcta'),
                                      ),
                                  ] else
                                    TextButton.icon(
                                      onPressed:
                                          question.answerMode ==
                                              AnswerMode.multiple
                                          ? () => _toggleMultipleCorrectOption(
                                              option.$1,
                                            )
                                          : () => _setSingleCorrectOption(
                                              option.$1,
                                            ),
                                      icon: const Icon(
                                        Icons.check_circle_outline_rounded,
                                        size: 16,
                                      ),
                                      label: const Text('Marcar correcta'),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                initialValue: option.$2.label,
                                decoration: fieldDecoration(),
                                validator: (value) =>
                                    (value ?? '').trim().isEmpty
                                    ? 'La opción no puede quedar vacía.'
                                    : null,
                                onChanged: (value) =>
                                    _replaceOption(option.$1, value),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          padding: const EdgeInsets.only(top: 22),
                          onPressed: question.options.length > 2
                              ? () => _removeOption(option.$1)
                              : null,
                          icon: const Icon(Icons.delete_outline_rounded),
                          tooltip: 'Eliminar opción',
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _addOption,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Agregar opción'),
            ),
          ),
          const Text(
            'En respuesta simple, sólo una opción queda como Correcta. En selección múltiple, puedes marcar varias opciones correctas.',
          ),
        ],
      ),
    );
  }
}

class _EditorFieldLabel extends StatelessWidget {
  const _EditorFieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: Theme.of(context).colorScheme.onSurface,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _OptionTruthPill extends StatelessWidget {
  const _OptionTruthPill({required this.correct});

  final bool correct;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = correct ? colorScheme.primary : colorScheme.error;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        correct ? 'Correcta' : 'Incorrecta',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}
