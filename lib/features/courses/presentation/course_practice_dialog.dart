part of 'courses_page.dart';

/// Student practice in two steps:
/// 1. `POST /training-attempts/start` draws a random set of questions from the
///    lesson bank (options already shuffled by the server).
/// 2. The student answers them one at a time (with a timer) and
///    `POST /training-attempts` sends every answer once; the server grades.
/// Each try, including "Intentar de nuevo", starts a new session. Correct
/// answers are never sent to the student.
class _PracticeDialog extends StatefulWidget {
  const _PracticeDialog({required this.lesson, required this.repository});

  final Lesson lesson;
  final CoursesRepository repository;

  @override
  State<_PracticeDialog> createState() => _PracticeDialogState();
}

class _PracticeDialogState extends State<_PracticeDialog> {
  static const _questionDurationSeconds = 60;

  /// Questions with a video get 3 minutes to watch it and answer.
  static const _videoQuestionDurationSeconds = 180;

  PracticeSession? _session;
  var _starting = true;
  String? _startError;

  final _answers = <int, List<int>>{};
  Timer? _questionTimer;
  var _questionSecondsLeft = _questionDurationSeconds;
  var _currentQuestionIndex = 0;
  var _submitting = false;
  TrainingAttemptResult? _result;
  String? _submitError;

  /// The submitted session can't be sent again (409): only a new one works.
  var _sessionClosed = false;

  @override
  void initState() {
    super.initState();
    _startSession();
  }

  @override
  void dispose() {
    _questionTimer?.cancel();
    super.dispose();
  }

  Future<void> _startSession() async {
    _questionTimer?.cancel();
    setState(() {
      _starting = true;
      _startError = null;
      _session = null;
      _result = null;
      _submitError = null;
      _sessionClosed = false;
      _answers.clear();
      _currentQuestionIndex = 0;
    });

    try {
      final session = await widget.repository.startPractice(widget.lesson.id!);
      if (!mounted) return;
      if (session.questions.isEmpty) {
        setState(
          () => _startError = 'Esta lección todavía no tiene preguntas.',
        );
        return;
      }
      setState(() => _session = session);
      _startQuestionTimer();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _startError = error.message);
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  List<PracticeQuestion> get _questions => _session?.questions ?? const [];
  int get _currentDuration => _questions.isNotEmpty && _currentQuestion.hasVideo
      ? _videoQuestionDurationSeconds
      : _questionDurationSeconds;
  double get _timerProgress => _questionSecondsLeft / _currentDuration;
  bool get _isLastQuestion => _currentQuestionIndex == _questions.length - 1;
  bool get _timeUp => _questionSecondsLeft == 0;

  PracticeQuestion get _currentQuestion => _questions[_currentQuestionIndex];
  List<int> get _currentAnswers => _answers[_currentQuestionIndex] ?? [];

  /// True while there are answers that would be lost by closing.
  bool get _inProgress =>
      _session != null && _result == null && !_sessionClosed;

  void _startQuestionTimer() {
    _questionTimer?.cancel();
    _questionSecondsLeft = _currentDuration;
    _questionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_result != null || _submitting) {
        timer.cancel();
        return;
      }

      if (_questionSecondsLeft <= 1) {
        timer.cancel();
        setState(() => _questionSecondsLeft = 0);
        // With an answer chosen, time up moves on automatically. Without one
        // the student must still pick an option: the API needs an answer for
        // every drawn question.
        if (_currentAnswers.isNotEmpty) _goNext();
        return;
      }

      setState(() => _questionSecondsLeft--);
    });
  }

  void _selectSingleAnswer(int optionIndex) {
    setState(() => _answers[_currentQuestionIndex] = [optionIndex]);
  }

  void _toggleMultipleAnswer(int optionIndex) {
    final selected = [..._currentAnswers];
    if (selected.contains(optionIndex)) {
      selected.remove(optionIndex);
    } else {
      selected.add(optionIndex);
      selected.sort();
    }
    setState(() => _answers[_currentQuestionIndex] = selected);
  }

  void _goNext() {
    if (_currentAnswers.isEmpty || _submitting) return;
    if (_isLastQuestion) {
      _submit();
      return;
    }
    setState(() {
      _currentQuestionIndex++;
      _startQuestionTimer();
    });
  }

  Future<void> _submit() async {
    final session = _session;
    if (session == null) return;
    _questionTimer?.cancel();
    setState(() {
      _submitting = true;
      _submitError = null;
    });

    final answers = [
      for (final question in _questions.indexed)
        AttemptAnswer(
          questionId: question.$2.id!,
          selectedOptionIds: [
            for (final optionIndex in _answers[question.$1] ?? const <int>[])
              question.$2.options[optionIndex].id!,
          ],
        ),
    ];

    try {
      final result = await widget.repository.submitAttempt(
        session.sessionId,
        answers,
      );
      if (!mounted) return;
      setState(() => _result = result);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _submitError = error.message;
        _sessionClosed = error.statusCode == 409;
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<bool> _confirmLeave() async {
    if (!_inProgress) return true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Salir de la práctica?'),
        content: const Text('Perderás las respuestas de esta práctica.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Seguir respondiendo'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
    return leave ?? false;
  }

  Future<void> _close() async {
    if (_submitting) return;
    if (!await _confirmLeave() || !mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _restart() async {
    if (!await _confirmLeave() || !mounted) return;
    await _startSession();
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final textTheme = Theme.of(context).textTheme;
    final lesson = widget.lesson;

    final List<Widget> body;
    if (_starting) {
      body = const [
        SizedBox(
          height: 160,
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    } else if (_startError != null) {
      body = _buildStartError(context);
    } else if (result != null) {
      body = _buildResult(context, result);
    } else {
      body = _buildQuestionStep(context);
    }

    return PopScope(
      canPop: !_inProgress && !_submitting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: ResponsiveDialog(
        maxWidth: 960,
        child: Padding(
          padding: EdgeInsets.all(context.dialogPadding),
          child: SingleChildScrollView(
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
                          Text('Práctica', style: textTheme.labelLarge),
                          const SizedBox(height: 6),
                          Text(lesson.title, style: textTheme.headlineSmall),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _submitting ? null : _close,
                      icon: const Icon(Icons.close_rounded),
                      tooltip: 'Cerrar',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  result == null
                      ? '${_practiceDescription(lesson)}. Responde una pregunta a la vez; al terminar se envían todas tus respuestas y el sistema calcula la nota.'
                      : 'Resultado de tu intento.',
                ),
                const SizedBox(height: 20),
                ...body,
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildStartError(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colorScheme.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline_rounded, color: colorScheme.error),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'No se pudo iniciar la práctica: $_startError',
                style: TextStyle(
                  color: colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          FilledButton.icon(
            onPressed: _startSession,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reintentar'),
          ),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
            label: const Text('Cerrar'),
          ),
        ],
      ),
    ];
  }

  List<Widget> _buildQuestionStep(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return [
      LinearProgressIndicator(value: _currentQuestionIndex / _questions.length),
      const SizedBox(height: 8),
      Text('Pregunta ${_currentQuestionIndex + 1} de ${_questions.length}'),
      const SizedBox(height: 8),
      _QuestionTimerBar(
        secondsLeft: _questionSecondsLeft,
        progress: _timerProgress,
        hasVideo: _currentQuestion.hasVideo,
      ),
      const SizedBox(height: 16),
      _PracticeQuestionCard(
        number: _currentQuestionIndex + 1,
        question: _currentQuestion,
        selectedIndexes: _currentAnswers,
        onSingleSelected: _submitting || _sessionClosed
            ? null
            : _selectSingleAnswer,
        onMultipleToggled: _submitting || _sessionClosed
            ? null
            : _toggleMultipleAnswer,
      ),
      if (_currentAnswers.isEmpty) ...[
        const SizedBox(height: 12),
        Text(
          _timeUp
              ? 'Se acabó el tiempo. Elige una respuesta para continuar.'
              : 'Elige una respuesta para continuar.',
          style: TextStyle(
            color: _timeUp ? colorScheme.error : colorScheme.onSurfaceVariant,
            fontWeight: _timeUp ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
      if (_submitError != null) ...[
        const SizedBox(height: 12),
        Text(
          'No se pudo enviar la práctica: $_submitError',
          style: TextStyle(color: colorScheme.error),
        ),
      ],
      const SizedBox(height: 20),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          if (_sessionClosed)
            FilledButton.icon(
              onPressed: _startSession,
              icon: const Icon(Icons.restart_alt_rounded),
              label: const Text('Empezar una nueva práctica'),
            )
          else
            FilledButton.icon(
              onPressed: _currentAnswers.isEmpty || _submitting
                  ? null
                  : _goNext,
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      _isLastQuestion
                          ? Icons.send_rounded
                          : Icons.arrow_forward_rounded,
                    ),
              label: Text(
                _submitting
                    ? 'Enviando...'
                    : _isLastQuestion
                    ? (_submitError == null
                          ? 'Enviar respuestas'
                          : 'Reintentar envío')
                    : 'Siguiente pregunta',
              ),
            ),
          if (!_sessionClosed)
            OutlinedButton.icon(
              onPressed: _submitting ? null : _restart,
              icon: const Icon(Icons.restart_alt_rounded),
              label: const Text('Empezar de nuevo'),
            ),
          TextButton.icon(
            onPressed: _submitting ? null : _close,
            icon: const Icon(Icons.close_rounded),
            label: const Text('Salir'),
          ),
        ],
      ),
    ];
  }

  List<Widget> _buildResult(
    BuildContext context,
    TrainingAttemptResult result,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return [
      _PracticeResultBanner(
        scorePercent: result.scorePercent,
        correctAnswers: result.correctAnswers,
        totalQuestions: result.correctByQuestionId.length,
        requiredApprovalPercent: result.requiredApprovalPercent,
        approved: result.approved,
      ),
      const SizedBox(height: 16),
      for (final question in _questions.indexed) ...[
        Builder(
          builder: (context) {
            final correct = result.correctByQuestionId[question.$2.id] ?? false;
            final color = correct ? BrandColors.success : colorScheme.error;
            final selected = [
              for (final optionIndex in _answers[question.$1] ?? const <int>[])
                question.$2.options[optionIndex].label,
            ];

            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withValues(alpha: 0.25)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    correct ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    color: color,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${question.$1 + 1}. ${question.$2.prompt}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text('Tu respuesta: ${selected.join(', ')}'),
                        Text(
                          correct ? 'Correcta' : 'Incorrecta',
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 8),
      ],
      const SizedBox(height: 12),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          if (!result.approved)
            FilledButton.icon(
              onPressed: _startSession,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Intentar de nuevo'),
            ),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
            label: const Text('Cerrar'),
          ),
        ],
      ),
    ];
  }
}

/// "X preguntas al azar de un banco de N · aprueba con Y%".
String _practiceDescription(Lesson lesson) {
  final size = lesson.practiceSize;
  final questions = size == 1 ? '1 pregunta' : '$size preguntas';
  return 'Práctica: $questions al azar de un banco de ${lesson.bankSize} · '
      'aprueba con ${lesson.requiredApprovalPercent}%';
}

class _QuestionTimerBar extends StatelessWidget {
  const _QuestionTimerBar({
    required this.secondsLeft,
    required this.progress,
    this.hasVideo = false,
  });

  final int secondsLeft;
  final double progress;
  final bool hasVideo;

  String get _remaining {
    if (secondsLeft < 60) return '${secondsLeft}s';
    final seconds = (secondsLeft % 60).toString().padLeft(2, '0');
    return '${secondsLeft ~/ 60}:$seconds min';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final urgent = secondsLeft <= 10;
    final color = urgent ? colorScheme.error : colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timer_rounded, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  secondsLeft == 0
                      ? 'Tiempo agotado'
                      : hasVideo
                      ? 'Pregunta con video: tienes 3 minutos · Tiempo restante: $_remaining'
                      : 'Tiempo restante: $_remaining',
                  style: TextStyle(color: color, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress.clamp(0, 1),
            color: color,
            backgroundColor: color.withValues(alpha: 0.16),
          ),
        ],
      ),
    );
  }
}

class _PracticeQuestionCard extends StatelessWidget {
  const _PracticeQuestionCard({
    required this.number,
    required this.question,
    required this.selectedIndexes,
    required this.onSingleSelected,
    required this.onMultipleToggled,
  });

  final int number;
  final PracticeQuestion question;
  final List<int> selectedIndexes;
  final ValueChanged<int>? onSingleSelected;
  final ValueChanged<int>? onMultipleToggled;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$number. ${question.prompt}',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (question.type == QuestionType.image) ...[
            const SizedBox(height: 8),
            if (question.imageUrl != null && question.imageUrl!.isNotEmpty)
              _QuestionImage(url: question.imageUrl!)
            else
              const _StatusPill(label: 'Pregunta con foto pendiente'),
          ],
          if (question.hasVideo) ...[
            const SizedBox(height: 10),
            VideoEmbed(url: question.videoUrl!),
          ],
          const SizedBox(height: 10),
          Text(
            question.answerMode == AnswerMode.multiple
                ? 'Selecciona todas las respuestas correctas.'
                : 'Selecciona una respuesta.',
          ),
          const SizedBox(height: 6),
          RadioGroup<int>(
            groupValue: selectedIndexes.isEmpty ? null : selectedIndexes.first,
            onChanged: (value) {
              if (value != null && onSingleSelected != null) {
                onSingleSelected!(value);
              }
            },
            child: Column(
              children: [
                for (
                  var optionIndex = 0;
                  optionIndex < question.options.length;
                  optionIndex++
                )
                  question.answerMode == AnswerMode.multiple
                      ? CheckboxListTile(
                          value: selectedIndexes.contains(optionIndex),
                          enabled: onMultipleToggled != null,
                          onChanged: (_) =>
                              onMultipleToggled?.call(optionIndex),
                          title: Text(question.options[optionIndex].label),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                        )
                      : RadioListTile<int>(
                          value: optionIndex,
                          enabled: onSingleSelected != null,
                          title: Text(question.options[optionIndex].label),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PracticeResultBanner extends StatelessWidget {
  const _PracticeResultBanner({
    required this.scorePercent,
    required this.correctAnswers,
    required this.totalQuestions,
    required this.requiredApprovalPercent,
    required this.approved,
  });

  final double scorePercent;
  final int correctAnswers;
  final int totalQuestions;
  final int requiredApprovalPercent;
  final bool approved;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final score = scorePercent.round();
    final color = approved ? BrandColors.success : colorScheme.error;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            approved ? Icons.verified_rounded : Icons.error_rounded,
            color: color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              approved
                  ? 'Aprobado: $score% ($correctAnswers/$totalQuestions correctas). Mínimo requerido: $requiredApprovalPercent%.'
                  : 'No aprobado: $score% ($correctAnswers/$totalQuestions correctas). Mínimo requerido: $requiredApprovalPercent%. Repasa la teoría e inténtalo de nuevo.',
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
