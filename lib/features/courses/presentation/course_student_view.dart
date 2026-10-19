part of 'courses_page.dart';

/// Courses assigned to the signed-in student (courses.take).
class _StudentCoursesView extends StatefulWidget {
  const _StudentCoursesView({
    required this.repository,
    required this.storeCode,
  });

  final CoursesRepository repository;
  final String? storeCode;

  @override
  State<_StudentCoursesView> createState() => _StudentCoursesViewState();
}

class _StudentCoursesViewState extends State<_StudentCoursesView> {
  List<Course>? _courses;
  var _progressByLessonId = <int, LessonProgress>{};
  String? _error;
  var _loading = true;
  var _selectedCourseIndex = 0;

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
      final results = await Future.wait([
        widget.repository.fetchAssignedCourses(),
        widget.repository.fetchLessonProgress(),
      ]);
      if (!mounted) return;
      setState(() {
        _courses = results[0] as List<Course>;
        _progressByLessonId = results[1] as Map<int, LessonProgress>;
        if (_selectedCourseIndex >= _courses!.length) _selectedCourseIndex = 0;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refreshProgress() async {
    try {
      final progress = await widget.repository.fetchLessonProgress();
      if (!mounted) return;
      setState(() => _progressByLessonId = progress);
    } on ApiException catch (error) {
      if (!mounted) return;
      _showSnack(context, 'No se pudo actualizar tu avance: ${error.message}');
    }
  }

  LessonProgress _lessonProgress(Course course, int lessonIndex) =>
      _progressByLessonId[course.lessons[lessonIndex].id] ??
      const LessonProgress();

  double _courseProgress(Course course) {
    if (course.lessons.isEmpty) return 0;
    var completedTasks = 0;
    for (var index = 0; index < course.lessons.length; index++) {
      final progress = _lessonProgress(course, index);
      if (progress.theoryCompleted) completedTasks++;
      if (progress.practiceApproved) completedTasks++;
    }
    return completedTasks / (course.lessons.length * 2);
  }

  int _approvedLessons(Course course) => [
    for (var index = 0; index < course.lessons.length; index++)
      _lessonProgress(course, index),
  ].where((progress) => progress.practiceApproved).length;

  String _courseStatus(Course course) {
    final progress = _courseProgress(course);
    if (progress == 1) return 'Completado';
    if (progress > 0) return 'En curso';
    return 'Nuevo';
  }

  bool _lessonLocked(Course course, int lessonIndex) {
    if (lessonIndex == 0) return false;
    return !_lessonProgress(course, lessonIndex - 1).completed;
  }

  Future<bool> _completeTheory(Lesson lesson) async {
    try {
      final progress = await widget.repository.markTheoryCompleted(lesson.id!);
      if (!mounted) return false;
      setState(() {
        _progressByLessonId = {..._progressByLessonId, lesson.id!: progress};
      });
      _showSnack(
        context,
        'Teoría marcada como leída. Ya puedes hacer la práctica.',
      );
      return true;
    } on ApiException catch (error) {
      if (!mounted) return false;
      _showSnack(context, 'No se pudo guardar: ${error.message}');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _courses == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _courses == null) {
      return _ErrorRetry(message: _error!, onRetry: _load);
    }

    final courses = _courses ?? const <Course>[];
    if (courses.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(
            title: 'Mis cursos',
            subtitle:
                'Capacitación operativa con teoría y práctica por lección.',
          ),
          Expanded(
            child: _EmptyState(
              icon: Icons.school_outlined,
              message: widget.storeCode == null
                  ? 'No tienes una tienda asignada. Pide a un administrador que te la asigne.'
                  : 'Todavía no hay cursos publicados para ${widget.storeCode}.',
            ),
          ),
          Center(
            child: OutlinedButton.icon(
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Actualizar'),
            ),
          ),
        ],
      );
    }

    final selectedCourse = courses[_selectedCourseIndex];
    final selectedCourseProgress = _courseProgress(selectedCourse);
    final lessonCount = courses.fold<int>(
      0,
      (total, course) => total + course.lessons.length,
    );
    final completedCourses = courses
        .where((course) => _courseProgress(course) == 1)
        .length;

    return Stack(
      children: [
        Positioned.fill(
          child: RefreshIndicator(
            onRefresh: _load,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(top: 76),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const PageHeader(
                    title: 'Mis cursos',
                    subtitle:
                        'Capacitación operativa con teoría, práctica por lección y avance progresivo.',
                  ),
                  const SizedBox(height: 20),
                  MetricCardGrid(
                    cards: [
                      MetricCard(
                        title: 'Cursos asignados',
                        value: '${courses.length}',
                        caption: 'Tienda ${widget.storeCode ?? '—'}',
                        icon: Icons.school_rounded,
                      ),
                      MetricCard(
                        title: 'Lecciones',
                        value: '$lessonCount',
                        caption: 'En tu ruta de capacitación',
                        icon: Icons.menu_book_rounded,
                      ),
                      MetricCard(
                        title: 'Completados',
                        value: '$completedCourses',
                        caption: 'Cursos con todas las lecciones',
                        icon: Icons.verified_rounded,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  AppPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cursos disponibles',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Estos son los cursos asignados a tu tienda.',
                        ),
                        const SizedBox(height: 14),
                        for (final course in courses.indexed) ...[
                          _CourseTile(
                            course: course.$2,
                            statusLabels: [
                              _courseStatus(course.$2),
                              '${(_courseProgress(course.$2) * 100).round()}%',
                              '${_approvedLessons(course.$2)}/${course.$2.lessons.length} prácticas aprobadas',
                            ],
                            selected: course.$1 == _selectedCourseIndex,
                            onTap: () => setState(
                              () => _selectedCourseIndex = course.$1,
                            ),
                          ),
                          if (course.$1 != courses.length - 1)
                            const SizedBox(height: 10),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _StudentCourseDetailPanel(
                    course: selectedCourse,
                    courseProgress: selectedCourseProgress,
                    lessonProgress: (index) =>
                        _lessonProgress(selectedCourse, index),
                    lessonLocked: (index) =>
                        _lessonLocked(selectedCourse, index),
                    onTheoryCompleted: _completeTheory,
                    repository: widget.repository,
                    onPracticeFinished: _refreshProgress,
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          top: 0,
          right: 0,
          child: _StickyCourseProgress(
            title: selectedCourse.title,
            progress: selectedCourseProgress,
            status: _courseStatus(selectedCourse),
          ),
        ),
      ],
    );
  }
}

class _StudentCourseDetailPanel extends StatelessWidget {
  const _StudentCourseDetailPanel({
    required this.course,
    required this.courseProgress,
    required this.lessonProgress,
    required this.lessonLocked,
    required this.onTheoryCompleted,
    required this.repository,
    required this.onPracticeFinished,
  });

  final Course course;
  final double courseProgress;
  final LessonProgress Function(int lessonIndex) lessonProgress;
  final bool Function(int lessonIndex) lessonLocked;
  final Future<bool> Function(Lesson lesson) onTheoryCompleted;
  final CoursesRepository repository;
  final Future<void> Function() onPracticeFinished;

  @override
  Widget build(BuildContext context) {
    if (course.lessons.isEmpty) {
      return const AppPanel(
        child: _EmptyState(
          icon: Icons.menu_book_outlined,
          message: 'Este curso todavía no tiene lecciones.',
        ),
      );
    }

    var nextLessonIndex = 0;
    for (var index = 0; index < course.lessons.length; index++) {
      if (!lessonLocked(index) && !lessonProgress(index).completed) {
        nextLessonIndex = index;
        break;
      }
    }
    final nextLesson = course.lessons[nextLessonIndex];
    final nextProgress = lessonProgress(nextLessonIndex);
    final nextActionText = courseProgress == 1
        ? 'Curso completo. Ya terminaste teoría y práctica de todas las lecciones.'
        : nextProgress.theoryCompleted
        ? 'Siguiente: inicia la práctica de "${nextLesson.title}" para seguir avanzando.'
        : 'Siguiente: abre "${nextLesson.title}" y marca la teoría como leída.';
    final description = course.description?.trim() ?? '';

    void showLockedDialog() {
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.lock_rounded),
          title: const Text('Lección bloqueada'),
          content: const Text(
            'Para abrir esta lección primero completa la teoría y aprueba la práctica de la lección anterior.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
    }

    void showTheoryRequiredDialog() {
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.menu_book_rounded),
          title: const Text('Primero completa la teoría'),
          content: const Text(
            'Para hacer la práctica tienes que abrir la lección y marcar la teoría como leída. Después la práctica queda disponible.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
    }

    Future<void> openPractice(int lessonIndex) async {
      if (!lessonProgress(lessonIndex).theoryCompleted) {
        showTheoryRequiredDialog();
        return;
      }
      final lesson = course.lessons[lessonIndex];
      if (lesson.bankSize == 0) {
        _showSnack(context, 'Esta lección todavía no tiene preguntas.');
        return;
      }
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) =>
            _PracticeDialog(lesson: lesson, repository: repository),
      );
      await onPracticeFinished();
    }

    void openLesson(int lessonIndex) {
      if (lessonLocked(lessonIndex)) {
        showLockedDialog();
        return;
      }

      showDialog<void>(
        context: context,
        builder: (dialogContext) => _LessonTheoryDialog(
          course: course,
          lesson: course.lessons[lessonIndex],
          lessonNumber: lessonIndex + 1,
          theoryCompleted: lessonProgress(lessonIndex).theoryCompleted,
          onTheoryCompleted: () =>
              onTheoryCompleted(course.lessons[lessonIndex]),
          onStartPractice: () {
            Navigator.of(dialogContext).pop();
            openPractice(lessonIndex);
          },
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
              _StatusPill(label: '${(courseProgress * 100).round()}%'),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(description),
          ],
          const SizedBox(height: 8),
          const Text(
            'La teoría no tiene límite de tiempo. Cada lección habilita una práctica con aprobación mínima. La siguiente lección se desbloquea al completar la anterior.',
          ),
          const SizedBox(height: 12),
          _NextActionBanner(message: nextActionText),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: courseProgress == 1
                    ? null
                    : () => openLesson(nextLessonIndex),
                icon: const Icon(Icons.visibility_rounded),
                label: const Text('Ver lección'),
              ),
              OutlinedButton.icon(
                onPressed: courseProgress == 1
                    ? null
                    : () => openPractice(nextLessonIndex),
                icon: const Icon(Icons.quiz_rounded),
                label: const Text('Iniciar práctica'),
              ),
            ],
          ),
          const SizedBox(height: 22),
          if (courseProgress == 1) ...[
            const _CourseCompletedPanel(),
            const SizedBox(height: 22),
          ],
          _CourseRoadmap(
            lessons: course.lessons,
            progressFor: lessonProgress,
            lockedFor: lessonLocked,
            onOpenLesson: openLesson,
          ),
        ],
      ),
    );
  }
}

class _LessonTheoryDialog extends StatefulWidget {
  const _LessonTheoryDialog({
    required this.course,
    required this.lesson,
    required this.lessonNumber,
    required this.theoryCompleted,
    required this.onStartPractice,
    required this.onTheoryCompleted,
  });

  final Course course;
  final Lesson lesson;
  final int lessonNumber;
  final bool theoryCompleted;
  final VoidCallback onStartPractice;
  final Future<bool> Function() onTheoryCompleted;

  @override
  State<_LessonTheoryDialog> createState() => _LessonTheoryDialogState();
}

class _LessonTheoryDialogState extends State<_LessonTheoryDialog> {
  late var _theoryCompleted = widget.theoryCompleted;
  var _saving = false;

  Future<void> _markTheory() async {
    setState(() => _saving = true);
    final ok = await widget.onTheoryCompleted();
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (ok) _theoryCompleted = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final lesson = widget.lesson;

    return ResponsiveDialog(
      maxWidth: 720,
      child: Padding(
        padding: EdgeInsets.all(context.dialogPadding),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DialogTitle(
                overline:
                    '${widget.course.title} · Lección ${widget.lessonNumber}',
                title: lesson.title,
              ),
              const SizedBox(height: 16),
              Text(lesson.summary),
              const SizedBox(height: 20),
              const _TheoryBlock(
                title: 'Objetivo',
                body:
                    'Entender el criterio operativo de la lección antes de avanzar a la práctica.',
              ),
              const SizedBox(height: 12),
              _TheoryBlock(title: 'Contenido', body: lesson.theory),
              if (lesson.theoryVideos.isNotEmpty) ...[
                const SizedBox(height: 12),
                _TheoryVideosBlock(videos: lesson.theoryVideos),
              ],
              if (lesson.theoryImageUrls.isNotEmpty) ...[
                const SizedBox(height: 12),
                _TheoryImagesBlock(imageUrls: lesson.theoryImageUrls),
              ],
              const SizedBox(height: 12),
              _TheoryBlock(
                title: 'Regla de avance',
                body:
                    'Cuando marques esta teoría como leída, la práctica queda disponible. ${_practiceDescription(lesson)}.',
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  if (!_theoryCompleted)
                    FilledButton.icon(
                      onPressed: _saving ? null : _markTheory,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check_rounded),
                      label: const Text('Marcar teoría como leída'),
                    ),
                  FilledButton.tonalIcon(
                    onPressed: _theoryCompleted ? widget.onStartPractice : null,
                    icon: const Icon(Icons.quiz_rounded),
                    label: Text(
                      _theoryCompleted
                          ? 'Iniciar práctica'
                          : 'Primero marca la teoría como leída',
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Cerrar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
