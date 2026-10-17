part of 'courses_page.dart';

/// One student's practice attempts for a course: score, approved or not, and
/// question by question what was answered and what was right.
class _StudentAttemptsDialog extends StatefulWidget {
  const _StudentAttemptsDialog({required this.repository, required this.row});

  final CoursesRepository repository;
  final CourseProgressRow row;

  @override
  State<_StudentAttemptsDialog> createState() => _StudentAttemptsDialogState();
}

class _StudentAttemptsDialogState extends State<_StudentAttemptsDialog> {
  List<AttemptReview>? _attempts;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final attempts = await widget.repository.fetchStudentAttempts(
        widget.row.username,
        courseId: widget.row.courseId,
      );
      if (!mounted) return;
      setState(() => _attempts = attempts);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    final attempts = _attempts;
    final dateFormat = DateFormat('dd/MM/yyyy h:mm a', 'en_US');

    final Widget body;
    if (_error != null && attempts == null) {
      body = _ErrorRetry(message: _error!, onRetry: _load);
    } else if (attempts == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (attempts.isEmpty) {
      body = const _EmptyState(
        icon: Icons.quiz_outlined,
        message: 'Este alumno todavía no ha hecho ninguna práctica.',
      );
    } else {
      body = ListView.separated(
        itemCount: attempts.length,
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (context, index) => _AttemptReviewTile(
          attempt: attempts[index],
          date: attempts[index].createdAt == null
              ? ''
              : _formatDateTime(
                  dateFormat,
                  attempts[index].createdAt!.toLocal(),
                ),
        ),
      );
    }

    return ResponsiveDialog(
      maxWidth: 820,
      maxHeightFactor: 0.9,
      child: Padding(
        padding: EdgeInsets.all(context.dialogPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _DialogTitle(
                    overline: '${row.courseTitle} · ${row.storeCode ?? '—'}',
                    title: row.fullName.isEmpty
                        ? 'Intentos de ${row.username}'
                        : 'Intentos de ${row.fullName}',
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Cerrar',
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (attempts != null && attempts.isNotEmpty)
              Text(
                '${attempts.length} intento${attempts.length == 1 ? '' : 's'} · '
                '${attempts.where((attempt) => attempt.approved).length} aprobado'
                '${attempts.where((attempt) => attempt.approved).length == 1 ? '' : 's'}',
              ),
            const SizedBox(height: 12),
            Flexible(child: body),
          ],
        ),
      ),
    );
  }
}

class _AttemptReviewTile extends StatelessWidget {
  const _AttemptReviewTile({required this.attempt, required this.date});

  final AttemptReview attempt;
  final String date;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = attempt.approved ? BrandColors.success : colorScheme.error;
    final failed = attempt.answers.where((answer) => !answer.isCorrect).length;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        leading: Icon(
          attempt.approved ? Icons.check_circle_rounded : Icons.cancel_rounded,
          color: color,
        ),
        title: Text(
          'Lección ${attempt.lessonSortOrder}: ${attempt.lessonTitle}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          'Intento ${attempt.attemptNumber}${date.isEmpty ? '' : ' · $date'}\n'
          '${attempt.approved ? 'Aprobado' : 'No aprobado'}: '
          '${attempt.scorePercent.round()}% '
          '(${attempt.correctAnswers}/${attempt.answers.length} correctas, '
          'mínimo ${attempt.requiredApprovalPercent}%)'
          '${failed == 0 ? '' : ' · falló $failed'}',
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          for (final answer in attempt.answers) ...[
            _AnswerReviewLine(answer: answer),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _AnswerReviewLine extends StatelessWidget {
  const _AnswerReviewLine({required this.answer});

  final AnswerReviewRow answer;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = answer.isCorrect ? BrandColors.success : colorScheme.error;
    final code = answer.code == null ? '' : '${answer.code} · ';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          answer.isCorrect ? Icons.check_rounded : Icons.close_rounded,
          size: 18,
          color: color,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$code${answer.prompt}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                'Respondió: ${answer.selectedLabels.join(', ')}',
                style: TextStyle(color: color),
              ),
              if (!answer.isCorrect)
                Text(
                  'Correcta: ${answer.correctLabels.join(', ')}',
                  style: const TextStyle(color: BrandColors.success),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Questions students fail the most, filtered by store and course.
class _MissedQuestionsPanel extends StatefulWidget {
  const _MissedQuestionsPanel({
    required this.repository,
    required this.storeCode,
    required this.courses,
  });

  final CoursesRepository repository;
  final String? storeCode;

  /// Courses to filter by: id → title.
  final Map<int, String> courses;

  @override
  State<_MissedQuestionsPanel> createState() => _MissedQuestionsPanelState();
}

class _MissedQuestionsPanelState extends State<_MissedQuestionsPanel> {
  List<MissedQuestionRow>? _rows;
  String? _error;
  int? _courseId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _MissedQuestionsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.storeCode != widget.storeCode) _load();
  }

  Future<void> _load() async {
    setState(() {
      _rows = null;
      _error = null;
    });
    try {
      final rows = await widget.repository.fetchMissedQuestions(
        courseId: _courseId,
        storeCode: widget.storeCode,
      );
      if (!mounted) return;
      setState(() => _rows = rows);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    final Widget body;
    if (_error != null && rows == null) {
      body = _ErrorRetry(message: _error!, onRetry: _load);
    } else if (rows == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (rows.isEmpty) {
      body = const _EmptyState(
        icon: Icons.quiz_outlined,
        message: 'Todavía no hay prácticas de alumnos para este filtro.',
      );
    } else {
      body = ListView.separated(
        itemCount: rows.length,
        separatorBuilder: (context, index) => const Divider(height: 18),
        itemBuilder: (context, index) => _MissedQuestionLine(row: rows[index]),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: context.isCompact ? double.infinity : 360,
          child: DropdownButtonFormField<int?>(
            isExpanded: true,
            initialValue: _courseId,
            decoration: const InputDecoration(
              isDense: true,
              labelText: 'Curso',
            ),
            items: [
              const DropdownMenuItem<int?>(
                value: null,
                child: Text('Todos los cursos'),
              ),
              for (final course in widget.courses.entries)
                DropdownMenuItem<int?>(
                  value: course.key,
                  child: Text(course.value, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (value) {
              _courseId = value;
              _load();
            },
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Cuenta solo las prácticas de alumnos. Ordenadas de la más fallada a la menos.',
        ),
        const SizedBox(height: 12),
        Expanded(child: body),
      ],
    );
  }
}

class _MissedQuestionLine extends StatelessWidget {
  const _MissedQuestionLine({required this.row});

  final MissedQuestionRow row;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final color = row.timesFailed == 0
        ? BrandColors.success
        : row.failPercent >= 50
        ? colorScheme.error
        : colorScheme.tertiary;
    final code = row.code == null ? '' : '${row.code} · ';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 64,
          child: Text(
            '${row.failPercent.round()}%',
            style: textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$code${row.prompt}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                'Falló ${row.timesFailed} de ${row.timesAnswered} · '
                '${row.courseTitle} · ${row.lessonTitle}',
                style: textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
