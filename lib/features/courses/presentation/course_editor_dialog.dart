part of 'courses_page.dart';

/// Template editor for a course (courses.manage). Works on a copy of the
/// course; ids of existing lessons/questions/options are kept so the server
/// updates them in place.
class _CourseTemplateEditorDialog extends StatefulWidget {
  const _CourseTemplateEditorDialog({
    required this.course,
    required this.initialLessonIndex,
    required this.onSave,
    this.findSimilar,
    this.highlightQuestionId,
    this.uploadMedia,
  });

  final Course course;
  final int initialLessonIndex;

  /// Question to scroll to and highlight on open (from the catalog search).
  final int? highlightQuestionId;

  /// Persists the draft. Returns an error message, or null on success.
  final Future<String?> Function(Course course) onSave;

  /// Looks for existing questions similar to a new one (optional).
  final Future<List<SimilarQuestion>> Function(String prompt)? findSimilar;

  /// Uploads videos/images from the computer (POST /media). Without it the
  /// "Subir desde la computadora" buttons are hidden.
  final MediaUploader? uploadMedia;

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
  int? _highlightedQuestionId;
  final _formKey = GlobalKey<FormState>();
  final _highlightKey = GlobalKey();

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
    _highlightedQuestionId = widget.highlightQuestionId;
    if (_highlightedQuestionId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final target = _highlightKey.currentContext;
        if (target == null || !target.mounted) return;
        Scrollable.ensureVisible(
          target,
          alignment: 0.1,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      });
    }
  }

  @override
  void dispose() {
    _theoryImagesController.dispose();
    super.dispose();
  }

  Lesson get _selectedLesson => _draft.lessons[_selectedLessonIndex];

  bool _isHighlighted(PracticeQuestion question) =>
      question.id != null && question.id == _highlightedQuestionId;

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
      _highlightedQuestionId = null;
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

  /// Checks the NEW questions (without id) against the bank. Returns false
  /// when the admin chose "Revisar". Network errors never block saving.
  Future<bool> _confirmSimilarQuestions() async {
    final findSimilar = widget.findSimilar;
    if (findSimilar == null) return true;

    final pending = <String, String>{};
    for (final lesson in _draft.lessons.indexed) {
      for (final question in lesson.$2.questions.indexed) {
        final prompt = question.$2.prompt.trim();
        if (question.$2.id != null || prompt.length < 3) continue;
        // The same new text twice in the course is checked only once.
        pending.putIfAbsent(
          normalizeForSearch(prompt),
          () =>
              'Lección ${lesson.$1 + 1}, pregunta ${question.$1 + 1}: $prompt',
        );
      }
    }
    if (pending.isEmpty) return true;

    final groups = <String, List<SimilarQuestion>>{};
    await Future.wait([
      for (final entry in pending.entries)
        () async {
          try {
            final prompt = entry.value.substring(entry.value.indexOf(': ') + 2);
            final matches = await findSimilar(prompt);
            if (matches.isNotEmpty) groups[entry.value] = matches;
          } catch (_) {
            // Don't block saving on a failed check.
          }
        }(),
    ]);
    if (groups.isEmpty || !mounted) return true;

    final ordered = [
      for (final label in pending.values)
        if (groups.containsKey(label)) MapEntry(label, groups[label]!),
    ];
    final total = ordered.length;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          total == 1
              ? 'Hay 1 pregunta nueva parecida a otras del banco'
              : 'Hay $total preguntas nuevas parecidas a otras del banco',
        ),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final group in ordered) ...[
                  Text(
                    group.key,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  for (final match in group.value)
                    Padding(
                      padding: const EdgeInsets.only(left: 12, bottom: 4),
                      child: Text(
                        '• ${match.row.question.prompt} — ${_similarPlace(match.row)} · ${match.percent} % parecida',
                      ),
                    ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Revisar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Guardar de todos modos'),
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
    if (!await _confirmSimilarQuestions()) {
      if (mounted) setState(() => _saving = false);
      return;
    }
    if (!mounted) return;
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
    final compact = context.isCompact;
    const intro = Text(
      'Los cambios se guardan en el servidor al tocar "Guardar curso". Las secciones y preguntas existentes se actualizan sin perder el avance de los alumnos.',
    );

    return MediaUploaderScope(
      uploader: widget.uploadMedia,
      child: PopScope(
        canPop: !_dirty && !_saving,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _requestClose();
        },
        child: ResponsiveDialog(
          maxWidth: 920,
          maxHeightFactor: 0.9,
          child: Padding(
            padding: EdgeInsets.all(context.dialogPadding),
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
                // Phones: the note scrolls with the form to leave room for it.
                if (!compact) ...[const SizedBox(height: 8), intro],
                SizedBox(height: compact ? 8 : 20),
                Expanded(
                  child: Form(
                    key: _formKey,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 112),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (compact) ...[intro, const SizedBox(height: 16)],
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
                                      isExpanded: true,
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
                            isExpanded: true,
                            decoration: _fieldDecoration(),
                            items: [
                              for (final lesson in _draft.lessons.indexed)
                                DropdownMenuItem<int>(
                                  value: lesson.$1,
                                  child: Text(
                                    '${lesson.$1 + 1}. ${lesson.$2.title}',
                                    overflow: TextOverflow.ellipsis,
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
                                    MediaUploadButton(
                                      kind: MediaKind.image,
                                      onUploaded: (url) {
                                        _replaceTheoryImageUrls([
                                          ..._selectedLesson.theoryImageUrls,
                                          url,
                                        ]);
                                        _syncTheoryImagesController();
                                      },
                                    ),
                                    const Text(
                                      'La captura se guarda dentro del curso como data URL.',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                _TheoryVideosEditor(
                                  key: ValueKey(
                                    'theory-videos-$_selectedLessonIndex',
                                  ),
                                  videos: _selectedLesson.theoryVideos,
                                  onChanged: (videos) => _replaceSelectedLesson(
                                    _selectedLesson.copyWith(
                                      theoryVideos: videos,
                                    ),
                                  ),
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
                                  KeyedSubtree(
                                    key: _isHighlighted(question.$2)
                                        ? _highlightKey
                                        : null,
                                    child: _QuestionEditorCard(
                                      key: ValueKey(
                                        'question-$_selectedLessonIndex-${question.$1}-${question.$2.id}',
                                      ),
                                      highlighted: _isHighlighted(question.$2),
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
                // Full-width action bar on phones.
                SizedBox(
                  width: compact ? double.infinity : null,
                  child: DecoratedBox(
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
    this.highlighted = false,
  }) : standalone = false,
       belowPrompt = null;

  /// Edits a single question outside the course editor (question bank):
  /// hides ordering, removal and the lesson picker.
  const _QuestionEditorCard.standalone({
    required this.question,
    required this.onChanged,
    this.belowPrompt,
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
       highlighted = false,
       standalone = true;

  static void _ignoreInt(int _) {}
  static void _noop() {}

  final bool standalone;

  /// Marked as the result picked in the catalog search.
  final bool highlighted;

  /// Extra content right under the question text (similar questions).
  final Widget? belowPrompt;
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

  void _setUploadedImage(String url) =>
      onChanged(question.copyWith(type: QuestionType.image, imageUrl: url));

  void _setUploadedVideo(String url) =>
      onChanged(question.copyWith(videoUrl: url));

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
        color: highlighted
            ? colorScheme.primary.withValues(alpha: 0.08)
            : colorScheme.surface.withValues(alpha: 0.85),
        border: Border.all(
          color: highlighted ? colorScheme.primary : colorScheme.outlineVariant,
          width: highlighted ? 2 : 1,
        ),
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
              isExpanded: true,
              decoration: fieldDecoration(),
              items: [
                for (final lesson in lessons.indexed)
                  DropdownMenuItem<int>(
                    value: lesson.$1,
                    child: Text(
                      '${lesson.$1 + 1}. ${lesson.$2.title}',
                      overflow: TextOverflow.ellipsis,
                    ),
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
          const _EditorFieldLabel('Código (opcional)'),
          const SizedBox(height: 6),
          SizedBox(
            width: 220,
            child: TextFormField(
              initialValue: question.code ?? '',
              textCapitalization: TextCapitalization.characters,
              decoration: fieldDecoration().copyWith(
                hintText: 'Ej. P97',
                prefixIcon: const Icon(Icons.tag_rounded),
                errorMaxLines: 2,
              ),
              validator: (value) {
                final error = validateQuestionCode(value);
                return error == null
                    ? null
                    : '${error[0].toUpperCase()}${error.substring(1)}';
              },
              onChanged: (value) {
                final code = normalizeQuestionCode(value);
                onChanged(
                  code == null
                      ? question.copyWith(clearCode: true)
                      : question.copyWith(code: code),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          const _EditorFieldLabel('Contenido visual de la pregunta'),
          const SizedBox(height: 6),
          DropdownButtonFormField<QuestionType>(
            isExpanded: true,
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
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _pastePracticeImageFromClipboard(context),
                  icon: const Icon(Icons.content_paste_rounded),
                  label: const Text(
                    'Pegar captura y convertir en pregunta con foto',
                  ),
                ),
                MediaUploadButton(
                  kind: MediaKind.image,
                  label: 'Subir foto desde la computadora',
                  onUploaded: _setUploadedImage,
                ),
              ],
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
                MediaUploadButton(
                  kind: MediaKind.image,
                  onUploaded: _setUploadedImage,
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
              _QuestionImage(url: question.imageUrl!),
            ],
          ],
          const SizedBox(height: 12),
          const _EditorFieldLabel('Video de la pregunta (opcional)'),
          const SizedBox(height: 6),
          TextFormField(
            // Rebuilt when an uploaded video fills the field.
            key: ValueKey(
              'practice-video-$lessonIndex-$number-'
              '${uploadedVideoPath.hasMatch(question.videoUrl ?? '') ? question.videoUrl : 'enlace'}',
            ),
            initialValue: question.videoUrl ?? '',
            decoration: fieldDecoration().copyWith(
              hintText:
                  'Enlace de YouTube, Google Drive, Vimeo o .mp4 / .webm, o súbelo desde la computadora',
              prefixIcon: const Icon(Icons.smart_display_rounded),
              errorMaxLines: 2,
            ),
            validator: validateVideoUrl,
            onChanged: (value) => onChanged(
              value.trim().isEmpty
                  ? question.copyWith(clearVideoUrl: true)
                  : question.copyWith(videoUrl: value.trim()),
            ),
          ),
          const SizedBox(height: 8),
          MediaUploadButton(
            kind: MediaKind.video,
            onUploaded: _setUploadedVideo,
          ),
          if (question.hasVideo &&
              validateVideoUrl(question.videoUrl) == null) ...[
            const SizedBox(height: 8),
            VideoEmbed(url: question.videoUrl!),
          ],
          const SizedBox(height: 12),
          const _EditorFieldLabel('Tipo de respuesta'),
          const SizedBox(height: 6),
          DropdownButtonFormField<AnswerMode>(
            isExpanded: true,
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
          if (belowPrompt != null) ...[const SizedBox(height: 8), belowPrompt!],
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
                              // Label on the left, correct-answer actions on
                              // the right; they wrap under it when narrow.
                              SizedBox(
                                width: double.infinity,
                                child: Wrap(
                                  alignment: WrapAlignment.spaceBetween,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    _EditorFieldLabel(
                                      'Opción ${option.$1 + 1}',
                                    ),
                                    Wrap(
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        if (option.$2.isCorrect) ...[
                                          const _OptionTruthPill(correct: true),
                                          if (question.answerMode ==
                                              AnswerMode.multiple)
                                            TextButton.icon(
                                              onPressed:
                                                  correctIndexes.length > 1
                                                  ? () =>
                                                        _toggleMultipleCorrectOption(
                                                          option.$1,
                                                        )
                                                  : null,
                                              icon: const Icon(
                                                Icons
                                                    .remove_circle_outline_rounded,
                                                size: 16,
                                              ),
                                              label: const Text(
                                                'Quitar correcta',
                                              ),
                                            ),
                                        ] else
                                          TextButton.icon(
                                            onPressed:
                                                question.answerMode ==
                                                    AnswerMode.multiple
                                                ? () =>
                                                      _toggleMultipleCorrectOption(
                                                        option.$1,
                                                      )
                                                : () => _setSingleCorrectOption(
                                                    option.$1,
                                                  ),
                                            icon: const Icon(
                                              Icons
                                                  .check_circle_outline_rounded,
                                              size: 16,
                                            ),
                                            label: const Text(
                                              'Marcar correcta',
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
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
          const SizedBox(height: 12),
          const _EditorFieldLabel('Explicación de la respuesta (opcional)'),
          const SizedBox(height: 6),
          TextFormField(
            key: ValueKey('practice-explanation-$lessonIndex-$number'),
            initialValue: question.explanation ?? '',
            minLines: 2,
            maxLines: 5,
            maxLength: 4000,
            decoration: fieldDecoration().copyWith(
              hintText:
                  'Por qué la respuesta correcta es la correcta. El cobrador la ve al terminar la práctica.',
              prefixIcon: const Icon(Icons.lightbulb_outline_rounded),
            ),
            onChanged: (value) => onChanged(
              value.trim().isEmpty
                  ? question.copyWith(clearExplanation: true)
                  : question.copyWith(explanation: value),
            ),
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

/// "Videos de teoría" of a lesson: add, remove, reorder, link + optional
/// title, inline validation and a small preview.
class _TheoryVideosEditor extends StatefulWidget {
  const _TheoryVideosEditor({
    super.key,
    required this.videos,
    required this.onChanged,
  });

  final List<TheoryVideo> videos;
  final ValueChanged<List<TheoryVideo>> onChanged;

  @override
  State<_TheoryVideosEditor> createState() => _TheoryVideosEditorState();
}

class _TheoryVideosEditorState extends State<_TheoryVideosEditor> {
  /// Bumped on structural changes so the text fields are rebuilt.
  var _generation = 0;

  void _update(List<TheoryVideo> videos, {bool structural = false}) {
    if (structural) setState(() => _generation++);
    widget.onChanged(videos);
  }

  void _move(int index, int direction) {
    final videos = [...widget.videos];
    final video = videos.removeAt(index);
    videos.insert(index + direction, video);
    _update(videos, structural: true);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final videos = widget.videos;

    InputDecoration decoration(String label, {String? hint}) => InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: colorScheme.surface,
      border: const OutlineInputBorder(),
      errorMaxLines: 2,
      isDense: true,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _EditorFieldLabel('Videos de teoría'),
        const SizedBox(height: 6),
        if (videos.isEmpty) const Text('Esta lección no tiene videos.'),
        for (final video in videos.indexed)
          Container(
            key: ValueKey('theory-video-$_generation-${video.$1}'),
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Builder(
                  builder: (context) {
                    final urlField = TextFormField(
                      initialValue: video.$2.url,
                      decoration: decoration(
                        'Enlace del video',
                        hint: 'YouTube, Google Drive, Vimeo o .mp4 / .webm',
                      ),
                      validator: (value) => (value ?? '').trim().isEmpty
                          ? 'Pega el enlace del video.'
                          : validateVideoUrl(value),
                      onChanged: (value) {
                        final updated = [...videos];
                        updated[video.$1] = video.$2.copyWith(url: value);
                        _update(updated);
                      },
                    );
                    final titleField = TextFormField(
                      initialValue: video.$2.title ?? '',
                      decoration: decoration('Título (opcional)'),
                      validator: validateVideoTitle,
                      onChanged: (value) {
                        final updated = [...videos];
                        updated[video.$1] = TheoryVideo(
                          url: video.$2.url,
                          title: value,
                        );
                        _update(updated);
                      },
                    );
                    final actions = [
                      IconButton(
                        onPressed: video.$1 > 0
                            ? () => _move(video.$1, -1)
                            : null,
                        icon: const Icon(Icons.arrow_upward_rounded),
                        tooltip: 'Subir video',
                      ),
                      IconButton(
                        onPressed: video.$1 < videos.length - 1
                            ? () => _move(video.$1, 1)
                            : null,
                        icon: const Icon(Icons.arrow_downward_rounded),
                        tooltip: 'Bajar video',
                      ),
                      IconButton(
                        onPressed: () => _update(
                          [...videos]..removeAt(video.$1),
                          structural: true,
                        ),
                        icon: const Icon(Icons.delete_outline_rounded),
                        tooltip: 'Quitar video',
                      ),
                    ];
                    // Phones: fields stacked, actions under them.
                    if (context.isCompact) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          urlField,
                          const SizedBox(height: 8),
                          titleField,
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: actions,
                          ),
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: urlField),
                        const SizedBox(width: 8),
                        Expanded(flex: 2, child: titleField),
                        ...actions,
                      ],
                    );
                  },
                ),
                const SizedBox(height: 8),
                MediaUploadButton(
                  kind: MediaKind.video,
                  onUploaded: (url) {
                    final updated = [...videos];
                    updated[video.$1] = video.$2.copyWith(url: url);
                    _update(updated, structural: true);
                  },
                ),
                if (video.$2.url.trim().isNotEmpty &&
                    validateVideoUrl(video.$2.url) == null) ...[
                  const SizedBox(height: 8),
                  VideoEmbed(url: video.$2.url),
                ],
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () => _update([
              ...videos,
              const TheoryVideo(url: ''),
            ], structural: true),
            icon: const Icon(Icons.video_call_rounded),
            label: const Text('Agregar video'),
          ),
        ),
      ],
    );
  }
}
