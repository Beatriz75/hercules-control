part of 'courses_page.dart';

class _StickyCourseProgress extends StatelessWidget {
  const _StickyCourseProgress({
    required this.title,
    required this.progress,
    required this.status,
  });

  final String title;
  final double progress;
  final String status;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final percent = (progress * 100).round();

    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(18),
      color: colorScheme.surface,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _StatusPill(label: status),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: progress),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Text(
              '$percent%',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CourseTile extends StatelessWidget {
  const _CourseTile({
    required this.course,
    required this.statusLabels,
    required this.selected,
    required this.onTap,
  });

  final Course course;
  final List<String> statusLabels;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final description = course.description?.trim() ?? '';

    return Material(
      color: selected
          ? colorScheme.primary.withValues(alpha: 0.08)
          : colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: selected
              ? colorScheme.primary
              : colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: selected ? 1.4 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final label in statusLabels) _StatusPill(label: label),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                course.title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(description),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final store in course.stores) _StatusPill(label: store),
                  _StatusPill(label: '${course.lessons.length} lecciones'),
                ],
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.arrow_forward_rounded,
                  size: 18,
                  color: selected
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NextActionBanner extends StatelessWidget {
  const _NextActionBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Icon(Icons.route_rounded, color: colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseCompletedPanel extends StatelessWidget {
  const _CourseCompletedPanel();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BrandColors.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: BrandColors.success.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified_rounded, color: BrandColors.success),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Curso completado',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: BrandColors.success,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Terminaste la teoría y la práctica de todas las lecciones. Tu encargada ya puede ver tu avance en el sistema.',
            style: TextStyle(color: colorScheme.onSurface),
          ),
        ],
      ),
    );
  }
}

class _CourseRoadmap extends StatelessWidget {
  const _CourseRoadmap({
    required this.lessons,
    required this.onOpenLesson,
    this.progressFor,
    this.lockedFor,
    this.onEditLesson,
  });

  final List<Lesson> lessons;

  /// Student progress per lesson index. Null in the staff catalog.
  final LessonProgress Function(int lessonIndex)? progressFor;
  final bool Function(int lessonIndex)? lockedFor;
  final ValueChanged<int> onOpenLesson;
  final ValueChanged<int>? onEditLesson;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            progressFor == null ? 'Lecciones del curso' : 'Camino de avance',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1320),
              child: Wrap(
                alignment: WrapAlignment.start,
                runAlignment: WrapAlignment.start,
                spacing: 14,
                runSpacing: 14,
                children: [
                  for (final lesson in lessons.indexed)
                    _RoadmapStep(
                      number: lesson.$1 + 1,
                      lesson: lesson.$2,
                      locked: lockedFor?.call(lesson.$1) ?? false,
                      progress: progressFor?.call(lesson.$1),
                      onOpen: () => onOpenLesson(lesson.$1),
                      onEdit: onEditLesson == null
                          ? null
                          : () => onEditLesson!(lesson.$1),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoadmapStep extends StatelessWidget {
  const _RoadmapStep({
    required this.number,
    required this.lesson,
    required this.locked,
    required this.progress,
    required this.onOpen,
    required this.onEdit,
  });

  final int number;
  final Lesson lesson;
  final bool locked;

  /// Null in the staff catalog (no personal progress).
  final LessonProgress? progress;
  final VoidCallback onOpen;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final progress = this.progress;
    final completed = progress?.completed ?? false;
    final active = progress != null && !locked && !completed;
    final statusLabel = progress == null
        ? 'Lección $number'
        : locked
        ? 'Bloqueada'
        : completed
        ? 'Completa'
        : progress.theoryCompleted
        ? 'Falta práctica'
        : 'Falta teoría';
    final color = progress == null
        ? colorScheme.primary
        : completed
        ? BrandColors.success
        : active
        ? colorScheme.tertiary
        : colorScheme.onSurfaceVariant;

    return Material(
      color: completed || active
          ? color.withValues(alpha: 0.1)
          : colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          // Full width on phones, cards side by side elsewhere.
          width: context.isCompact ? double.infinity : 310,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 15,
                    backgroundColor: color,
                    child: Text(
                      '$number',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(
                    locked ? Icons.lock_rounded : Icons.open_in_new_rounded,
                    size: 18,
                    color: color,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                lesson.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                lesson.summary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              if (progress == null)
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _StatusPill(
                      label: 'Aprueba con ${lesson.requiredApprovalPercent}%',
                    ),
                    _StatusPill(label: _bankLabel(lesson)),
                    if (lesson.hasVideo) const _VideoChip(),
                  ],
                )
              else
                Text(
                  _practiceDescription(lesson),
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              if (progress != null) ...[
                const SizedBox(height: 8),
                _MiniTaskStatus(
                  label: 'Teoría',
                  completed: progress.theoryCompleted,
                  locked: locked,
                ),
                const SizedBox(height: 4),
                _MiniTaskStatus(
                  label: progress.bestScorePercent == null
                      ? 'Práctica'
                      : 'Práctica (mejor nota ${progress.bestScorePercent!.round()}%)',
                  completed: progress.practiceApproved,
                  locked: locked || !progress.theoryCompleted,
                ),
              ],
              if (onEdit != null) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_note_rounded, size: 18),
                    label: const Text('Editar'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniTaskStatus extends StatelessWidget {
  const _MiniTaskStatus({
    required this.label,
    required this.completed,
    required this.locked,
  });

  final String label;
  final bool completed;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final icon = completed
        ? Icons.check_circle_rounded
        : locked
        ? Icons.lock_rounded
        : Icons.radio_button_unchecked_rounded;
    final color = completed
        ? BrandColors.success
        : locked
        ? colorScheme.onSurfaceVariant
        : colorScheme.tertiary;

    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _TheoryBlock extends StatelessWidget {
  const _TheoryBlock({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          SelectableText(body),
        ],
      ),
    );
  }
}

class _TheoryImagesBlock extends StatelessWidget {
  const _TheoryImagesBlock({required this.imageUrls});

  final List<String> imageUrls;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Imágenes de apoyo',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          for (final imageUrl in imageUrls.indexed) ...[
            _FullImage(
              url: imageUrl.$2,
              maxHeight: 420,
              errorText: 'No se pudo cargar la imagen ${imageUrl.$1 + 1}.',
            ),
            if (imageUrl.$1 != imageUrls.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

/// Whole image (never cropped): as wide as available, at most [maxHeight]
/// tall, keeping its proportions over a neutral background.
class _FullImage extends StatelessWidget {
  const _FullImage({
    required this.url,
    required this.maxHeight,
    required this.errorText,
  });

  final String url;
  final double maxHeight;
  final String errorText;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        color: colorScheme.surfaceContainerHighest,
        alignment: Alignment.center,
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Image.network(
          resolveMediaUrl(url),
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => Container(
            height: 100,
            width: double.infinity,
            alignment: Alignment.center,
            color: colorScheme.errorContainer,
            child: Text(
              errorText,
              style: TextStyle(color: colorScheme.onErrorContainer),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuestionImage extends StatelessWidget {
  const _QuestionImage({required this.url, this.maxHeight = 360});

  final String url;
  final double maxHeight;

  @override
  Widget build(BuildContext context) => _FullImage(
    url: url,
    maxHeight: maxHeight,
    errorText: 'No se pudo cargar la foto de esta pregunta.',
  );
}

/// Theory + questions of a lesson for staff, showing the correct answers.
class _LessonPreviewDialog extends StatelessWidget {
  const _LessonPreviewDialog({
    required this.course,
    required this.lesson,
    required this.lessonNumber,
    this.onEdit,
  });

  final Course course;
  final Lesson lesson;
  final int lessonNumber;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return ResponsiveDialog(
      maxWidth: 760,
      child: Padding(
        padding: EdgeInsets.all(context.dialogPadding),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DialogTitle(
                overline: '${course.title} · Lección $lessonNumber',
                title: lesson.title,
              ),
              const SizedBox(height: 16),
              Text(lesson.summary),
              const SizedBox(height: 16),
              _TheoryBlock(title: 'Teoría', body: lesson.theory),
              if (lesson.theoryVideos.isNotEmpty) ...[
                const SizedBox(height: 12),
                _TheoryVideosBlock(videos: lesson.theoryVideos),
              ],
              if (lesson.theoryImageUrls.isNotEmpty) ...[
                const SizedBox(height: 12),
                _TheoryImagesBlock(imageUrls: lesson.theoryImageUrls),
              ],
              const SizedBox(height: 20),
              Text(
                'Banco de preguntas · ${_bankLabel(lesson)} · aprueba con ${lesson.requiredApprovalPercent}%',
                style: textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              for (final question in lesson.questions.indexed) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    border: Border.all(color: colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${question.$1 + 1}. ${question.$2.prompt}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      if (question.$2.hasVideo) ...[
                        const SizedBox(height: 6),
                        const _VideoChip(),
                        const SizedBox(height: 8),
                        VideoEmbed(url: question.$2.videoUrl!),
                      ],
                      if (question.$2.type == QuestionType.image &&
                          (question.$2.imageUrl ?? '').isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _QuestionImage(
                          url: question.$2.imageUrl!,
                          maxHeight: 240,
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        question.$2.answerMode == AnswerMode.multiple
                            ? 'Selección múltiple'
                            : 'Selección simple',
                        style: textTheme.labelMedium,
                      ),
                      const SizedBox(height: 6),
                      for (final option in question.$2.options)
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
                              Expanded(child: Text(option.label)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  if (onEdit != null)
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        onEdit!();
                      },
                      icon: const Icon(Icons.edit_note_rounded),
                      label: const Text('Editar lección'),
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

class _DialogTitle extends StatelessWidget {
  const _DialogTitle({required this.overline, required this.title});

  final String overline;
  final String title;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(overline, style: textTheme.labelLarge),
              const SizedBox(height: 6),
              Text(title, style: textTheme.headlineSmall),
            ],
          ),
        ),
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Cerrar',
        ),
      ],
    );
  }
}

class _QuestionExportDialog extends StatefulWidget {
  const _QuestionExportDialog({required this.course});

  final Course course;

  @override
  State<_QuestionExportDialog> createState() => _QuestionExportDialogState();
}

class _QuestionExportDialogState extends State<_QuestionExportDialog> {
  late final Set<int> _selectedLessonIndexes = {0};

  String _buildExportText() {
    final buffer = StringBuffer()
      ..writeln('# Preguntas exportadas: ${widget.course.title}')
      ..writeln();

    for (final lessonEntry in widget.course.lessons.indexed) {
      if (!_selectedLessonIndexes.contains(lessonEntry.$1)) continue;

      final lessonNumber = lessonEntry.$1 + 1;
      final lesson = lessonEntry.$2;
      buffer
        ..writeln('## Lección $lessonNumber: ${lesson.title}')
        ..writeln('Aprobación mínima: ${lesson.requiredApprovalPercent}%')
        ..writeln();

      for (final questionEntry in lesson.questions.indexed) {
        final questionNumber = questionEntry.$1 + 1;
        final question = questionEntry.$2;
        buffer
          ..writeln('### Pregunta $questionNumber')
          ..writeln(question.prompt.isEmpty ? '_Sin texto_' : question.prompt);

        if (question.imageUrl != null && question.imageUrl!.isNotEmpty) {
          buffer.writeln('Foto: ${question.imageUrl}');
        }

        buffer
          ..writeln(
            'Tipo: ${question.answerMode == AnswerMode.multiple ? 'selección múltiple' : 'selección simple'}',
          )
          ..writeln('Opciones:');

        for (final option in question.options) {
          final marker = option.isCorrect ? '[correcta]' : '';
          buffer.writeln('- ${option.label} $marker'.trimRight());
        }

        buffer.writeln();
      }
    }

    return buffer.toString().trimRight();
  }

  Future<void> _copyExport(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: _buildExportText()));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Preguntas exportadas al portapapeles.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveDialog(
      maxWidth: 720,
      child: Padding(
        padding: EdgeInsets.all(context.dialogPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _DialogTitle(
              overline: 'Exportador',
              title: 'Exportar preguntas por lección',
            ),
            const SizedBox(height: 12),
            const Text(
              'Selecciona una o varias lecciones. El export se copia en formato Markdown.',
            ),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (final lesson in widget.course.lessons.indexed)
                      CheckboxListTile(
                        value: _selectedLessonIndexes.contains(lesson.$1),
                        onChanged: (selected) {
                          setState(() {
                            if (selected ?? false) {
                              _selectedLessonIndexes.add(lesson.$1);
                            } else if (_selectedLessonIndexes.length > 1) {
                              _selectedLessonIndexes.remove(lesson.$1);
                            }
                          });
                        },
                        title: Text(
                          'Lección ${lesson.$1 + 1}: ${lesson.$2.title}',
                        ),
                        subtitle: Text(
                          '${lesson.$2.questions.length} preguntas',
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: _selectedLessonIndexes.isEmpty
                      ? null
                      : () => _copyExport(context),
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('Copiar export'),
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
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  const _ErrorRetry({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 40,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

/// Staff label for the bank draw: "X de N al azar".
String _bankLabel(Lesson lesson) =>
    '${lesson.practiceSize} de ${lesson.bankSize} al azar';

void _showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

/// Theory videos of a lesson, each with its optional title.
class _TheoryVideosBlock extends StatelessWidget {
  const _TheoryVideosBlock({required this.videos});

  final List<TheoryVideo> videos;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            videos.length == 1 ? 'Video' : 'Videos',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          for (final video in videos.indexed) ...[
            VideoEmbed(url: video.$2.url, title: video.$2.title),
            if (video.$1 != videos.length - 1) const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

class _VideoChip extends StatelessWidget {
  const _VideoChip();

  @override
  Widget build(BuildContext context) => _StatusPill(
    label: 'Video',
    color: Theme.of(context).colorScheme.tertiary,
  );
}
