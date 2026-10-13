/// Course models mapping the Hercules Control API (`/courses`).
///
/// The same classes are used for the staff catalog (with correct answers),
/// the student view (`/courses/assigned`, without `is_correct`) and the
/// template editor. Ids are kept so a `PUT /courses/{id}` updates lessons,
/// questions and options in place and preserves student progress.
library;

enum CourseStatus {
  draft('draft', 'Borrador'),
  active('active', 'Publicado'),
  archived('archived', 'Archivado');

  const CourseStatus(this.code, this.label);

  final String code;
  final String label;

  static CourseStatus fromCode(String? code) {
    for (final status in values) {
      if (status.code == code) return status;
    }
    return CourseStatus.active;
  }
}

enum QuestionType {
  text('text'),
  image('image');

  const QuestionType(this.code);

  final String code;

  static QuestionType fromCode(String? code) =>
      code == 'image' ? QuestionType.image : QuestionType.text;
}

enum AnswerMode {
  single('single'),
  multiple('multiple');

  const AnswerMode(this.code);

  final String code;

  static AnswerMode fromCode(String? code) =>
      code == 'multiple' ? AnswerMode.multiple : AnswerMode.single;
}

List<Map<String, dynamic>> _sortedMaps(Object? value) {
  final items = [
    for (final item in (value as List? ?? const []))
      item as Map<String, dynamic>,
  ];
  items.sort(
    (a, b) => ((a['sort_order'] as int?) ?? 0).compareTo(
      (b['sort_order'] as int?) ?? 0,
    ),
  );
  return items;
}

String? _emptyToNull(String? value) =>
    value == null || value.trim().isEmpty ? null : value;

class QuestionOption {
  const QuestionOption({
    this.id,
    required this.label,
    this.mediaUrl,
    this.optionType = 'text',
    this.isCorrect = false,
  });

  factory QuestionOption.fromJson(Map<String, dynamic> json) {
    return QuestionOption(
      id: json['id'] as int?,
      label: (json['label'] as String?) ?? '',
      mediaUrl: json['media_url'] as String?,
      optionType: (json['option_type'] as String?) ?? 'text',
      isCorrect: (json['is_correct'] as bool?) ?? false,
    );
  }

  final int? id;
  final String label;
  final String? mediaUrl;
  final String optionType;
  final bool isCorrect;

  QuestionOption copyWith({
    String? label,
    bool? isCorrect,
    bool clearId = false,
  }) {
    return QuestionOption(
      id: clearId ? null : id,
      label: label ?? this.label,
      mediaUrl: mediaUrl,
      optionType: optionType,
      isCorrect: isCorrect ?? this.isCorrect,
    );
  }

  Map<String, dynamic> toPayload(int sortOrder) => {
    'id': ?id,
    'label': label.trim(),
    'media_url': _emptyToNull(mediaUrl),
    'option_type': optionType,
    'is_correct': isCorrect,
    'sort_order': sortOrder,
  };
}

class PracticeQuestion {
  const PracticeQuestion({
    this.id,
    required this.prompt,
    required this.options,
    this.type = QuestionType.text,
    this.answerMode = AnswerMode.single,
    this.imageUrl,
  });

  factory PracticeQuestion.blank() => const PracticeQuestion(
    prompt: '',
    options: [
      QuestionOption(label: '', isCorrect: true),
      QuestionOption(label: ''),
    ],
  );

  /// With [keepOptionOrder] the options stay in the order received (the
  /// practice session already shuffles them on the server).
  factory PracticeQuestion.fromJson(
    Map<String, dynamic> json, {
    bool keepOptionOrder = false,
  }) {
    final options = keepOptionOrder
        ? [
            for (final option in (json['options'] as List? ?? const []))
              option as Map<String, dynamic>,
          ]
        : _sortedMaps(json['options']);
    return PracticeQuestion(
      id: json['id'] as int?,
      prompt: (json['prompt'] as String?) ?? '',
      type: QuestionType.fromCode(json['question_type'] as String?),
      answerMode: AnswerMode.fromCode(json['answer_mode'] as String?),
      imageUrl: json['image_url'] as String?,
      options: [for (final option in options) QuestionOption.fromJson(option)],
    );
  }

  final int? id;
  final String prompt;
  final List<QuestionOption> options;
  final QuestionType type;
  final AnswerMode answerMode;
  final String? imageUrl;

  List<int> get correctOptionIndexes => [
    for (final option in options.indexed)
      if (option.$2.isCorrect) option.$1,
  ];

  bool isCorrectOption(int optionIndex) => options[optionIndex].isCorrect;

  PracticeQuestion copyWith({
    String? prompt,
    List<QuestionOption>? options,
    QuestionType? type,
    AnswerMode? answerMode,
    String? imageUrl,
    bool clearImageUrl = false,
  }) {
    return PracticeQuestion(
      id: id,
      prompt: prompt ?? this.prompt,
      options: options ?? this.options,
      type: type ?? this.type,
      answerMode: answerMode ?? this.answerMode,
      imageUrl: clearImageUrl ? null : imageUrl ?? this.imageUrl,
    );
  }

  /// Copy that the server will treat as a brand new question (used when a
  /// question is moved to another lesson).
  PracticeQuestion withoutIds() {
    return PracticeQuestion(
      prompt: prompt,
      type: type,
      answerMode: answerMode,
      imageUrl: imageUrl,
      options: [for (final option in options) option.copyWith(clearId: true)],
    );
  }

  Map<String, dynamic> toPayload(int sortOrder) => {
    'id': ?id,
    'prompt': prompt.trim(),
    'question_type': type.code,
    'answer_mode': answerMode.code,
    'image_url': type == QuestionType.image ? _emptyToNull(imageUrl) : null,
    'sort_order': sortOrder,
    'options': [
      for (final option in options.indexed) option.$2.toPayload(option.$1 + 1),
    ],
  };
}

class Lesson {
  const Lesson({
    this.id,
    required this.title,
    required this.summary,
    required this.theory,
    required this.questions,
    this.theoryImageUrls = const [],
    this.requiredApprovalPercent = 80,
    this.questionsPerAttempt,
    this.questionBankSize,
  });

  factory Lesson.template() => Lesson(
    title: 'Nueva sección',
    summary: 'Describe el resultado esperado de esta sección.',
    theory:
        'Pega aquí la teoría de la guía para esta sección. Evita contenido inventado fuera de Ofertas/Mexi.',
    questions: [
      const PracticeQuestion(
        prompt: 'Escribe una pregunta basada en la guía.',
        options: [
          QuestionOption(label: 'Opción correcta', isCorrect: true),
          QuestionOption(label: 'Opción incorrecta'),
        ],
      ),
    ],
  );

  factory Lesson.fromJson(Map<String, dynamic> json) {
    return Lesson(
      id: json['id'] as int?,
      title: (json['title'] as String?) ?? '',
      summary: (json['summary'] as String?) ?? '',
      theory: (json['theory'] as String?) ?? '',
      requiredApprovalPercent:
          (json['required_approval_percent'] as int?) ?? 80,
      questionsPerAttempt: json['questions_per_attempt'] as int?,
      questionBankSize: json['question_bank_size'] as int?,
      theoryImageUrls: [
        for (final image in _sortedMaps(json['theory_images']))
          (image['url'] as String?) ?? '',
      ],
      questions: [
        for (final question in _sortedMaps(json['questions']))
          PracticeQuestion.fromJson(question),
      ],
    );
  }

  final int? id;
  final String title;
  final String summary;
  final String theory;
  final List<PracticeQuestion> questions;
  final List<String> theoryImageUrls;
  final int requiredApprovalPercent;

  /// Questions drawn at random for each practice. Null = the whole bank.
  /// For students the server already resolves it to a number.
  final int? questionsPerAttempt;

  /// Size of the question bank as reported to students (who don't receive
  /// the questions themselves). Staff use [questions].
  final int? questionBankSize;

  int get bankSize => questionBankSize ?? questions.length;

  int get practiceSize {
    final perAttempt = questionsPerAttempt;
    if (perAttempt == null || perAttempt > bankSize) return bankSize;
    return perAttempt;
  }

  Lesson copyWith({
    String? title,
    String? summary,
    String? theory,
    List<PracticeQuestion>? questions,
    List<String>? theoryImageUrls,
    int? requiredApprovalPercent,
    int? questionsPerAttempt,
    bool clearQuestionsPerAttempt = false,
  }) {
    return Lesson(
      id: id,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      theory: theory ?? this.theory,
      questions: questions ?? this.questions,
      theoryImageUrls: theoryImageUrls ?? this.theoryImageUrls,
      requiredApprovalPercent:
          requiredApprovalPercent ?? this.requiredApprovalPercent,
      questionsPerAttempt: clearQuestionsPerAttempt
          ? null
          : questionsPerAttempt ?? this.questionsPerAttempt,
      questionBankSize: questionBankSize,
    );
  }

  Map<String, dynamic> toPayload(int sortOrder) {
    final images = [
      for (final url in theoryImageUrls)
        if (url.trim().isNotEmpty) url.trim(),
    ];
    return {
      'id': ?id,
      'title': title.trim(),
      'summary': summary.trim(),
      'theory': theory.trim(),
      'required_approval_percent': requiredApprovalPercent,
      'questions_per_attempt': questionsPerAttempt,
      'sort_order': sortOrder,
      'theory_images': [
        for (final image in images.indexed)
          {'url': image.$2, 'sort_order': image.$1 + 1},
      ],
      'questions': [
        for (final question in questions.indexed)
          question.$2.toPayload(question.$1 + 1),
      ],
    };
  }
}

class Course {
  const Course({
    this.id,
    required this.title,
    required this.lessons,
    this.description,
    this.status = CourseStatus.draft,
    this.sortOrder = 1,
    this.active = true,
    this.stores = const [],
  });

  factory Course.template({List<String> stores = const []}) => Course(
    title: 'Nuevo curso',
    description: '',
    stores: stores,
    lessons: [Lesson.template()],
  );

  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      id: json['id'] as int?,
      title: (json['title'] as String?) ?? '',
      description: json['description'] as String?,
      status: CourseStatus.fromCode(json['status'] as String?),
      sortOrder: (json['sort_order'] as int?) ?? 1,
      active: (json['active'] as bool?) ?? true,
      stores: [
        for (final store in (json['stores'] as List? ?? const []))
          store is Map ? '${store['store_code']}' : '$store',
      ],
      lessons: [
        for (final lesson in _sortedMaps(json['lessons']))
          Lesson.fromJson(lesson),
      ],
    );
  }

  final int? id;
  final String title;
  final String? description;
  final CourseStatus status;
  final int sortOrder;
  final bool active;
  final List<String> stores;
  final List<Lesson> lessons;

  /// Whether students can currently see the course.
  bool get visibleToStudents => active && status == CourseStatus.active;

  Course copyWith({
    String? title,
    String? description,
    CourseStatus? status,
    int? sortOrder,
    bool? active,
    List<String>? stores,
    List<Lesson>? lessons,
  }) {
    return Course(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      sortOrder: sortOrder ?? this.sortOrder,
      active: active ?? this.active,
      stores: stores ?? this.stores,
      lessons: lessons ?? this.lessons,
    );
  }

  /// Body for `POST /courses` and `PUT /courses/{id}`. Sort orders follow the
  /// current list order; existing ids are sent back so the server updates in
  /// place.
  Map<String, dynamic> toPayload() => {
    'title': title.trim(),
    'description': _emptyToNull(description?.trim()),
    'status': status.code,
    'sort_order': sortOrder < 1 ? 1 : sortOrder,
    'active': active,
    'stores': stores.toSet().toList(),
    'lessons': [
      for (final lesson in lessons.indexed) lesson.$2.toPayload(lesson.$1 + 1),
    ],
  };

  /// Client-side checks mirroring the API validation, in Spanish.
  List<String> validationErrors() {
    final errors = <String>[];
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) errors.add('El curso necesita un título.');
    if (trimmedTitle.length > 120) {
      errors.add('El título del curso admite máximo 120 caracteres.');
    }
    if (stores.isEmpty) errors.add('Elige al menos una tienda.');
    if (lessons.isEmpty) errors.add('El curso necesita al menos una lección.');

    for (final lesson in lessons.indexed) {
      final n = lesson.$1 + 1;
      final l = lesson.$2;
      if (l.title.trim().isEmpty) errors.add('Lección $n: falta el título.');
      if (l.title.trim().length > 160) {
        errors.add('Lección $n: el título admite máximo 160 caracteres.');
      }
      if (l.summary.trim().isEmpty) errors.add('Lección $n: falta el resumen.');
      if (l.theory.trim().isEmpty) errors.add('Lección $n: falta la teoría.');
      if (l.requiredApprovalPercent < 1 || l.requiredApprovalPercent > 100) {
        errors.add('Lección $n: el % de aprobación debe estar entre 1 y 100.');
      }
      if (l.questions.isEmpty) {
        errors.add('Lección $n: agrega al menos una pregunta.');
      }
      final perAttemptError = questionsPerAttemptError(
        l.questionsPerAttempt,
        l.questions.length,
      );
      if (perAttemptError != null) errors.add('Lección $n: $perAttemptError');
      for (final question in l.questions.indexed) {
        final label = 'Lección $n, pregunta ${question.$1 + 1}';
        for (final error in practiceQuestionErrors(question.$2)) {
          errors.add('$label: $error');
        }
      }
    }
    return errors;
  }
}

/// Checks of a single question (lower-case messages, to be prefixed).
List<String> practiceQuestionErrors(PracticeQuestion q) {
  final errors = <String>[];
  if (q.prompt.trim().isEmpty) errors.add('falta el enunciado.');
  if (q.options.length < 2) errors.add('necesita al menos 2 opciones.');
  if (q.options.any((option) => option.label.trim().isEmpty)) {
    errors.add('hay opciones vacías.');
  }
  final correct = q.correctOptionIndexes.length;
  if (q.answerMode == AnswerMode.single && correct != 1) {
    errors.add('marca exactamente una opción correcta.');
  }
  if (q.answerMode == AnswerMode.multiple && correct < 1) {
    errors.add('marca al menos una opción correcta.');
  }
  return errors;
}

/// Validates "Preguntas por práctica" against the bank size (null = all).
/// Returns a message in lower case to be prefixed with the lesson.
String? questionsPerAttemptError(int? value, int bankSize) {
  if (value == null) return null;
  if (value < 1) return 'las preguntas por práctica deben ser al menos 1.';
  if (value > bankSize) {
    return 'pide $value preguntas por práctica pero el banco tiene $bankSize.';
  }
  return null;
}

/// Practice drawn by `POST /training-attempts/start`.
class PracticeSession {
  const PracticeSession({
    required this.sessionId,
    required this.lessonId,
    required this.requiredApprovalPercent,
    required this.questions,
  });

  factory PracticeSession.fromJson(Map<String, dynamic> json) {
    return PracticeSession(
      sessionId: json['session_id'] as int,
      lessonId: json['lesson_id'] as int,
      requiredApprovalPercent:
          (json['required_approval_percent'] as int?) ?? 80,
      // Kept in the order the server sent them (already randomized).
      questions: [
        for (final question in (json['questions'] as List? ?? const []))
          PracticeQuestion.fromJson(
            question as Map<String, dynamic>,
            keepOptionOrder: true,
          ),
      ],
    );
  }

  final int sessionId;
  final int lessonId;
  final int requiredApprovalPercent;
  final List<PracticeQuestion> questions;
}

/// Row of `GET /lesson-progress` for the signed-in student.
class LessonProgress {
  const LessonProgress({
    this.lessonId,
    this.theoryCompleted = false,
    this.practiceApproved = false,
    this.bestScorePercent,
  });

  factory LessonProgress.fromJson(Map<String, dynamic> json) {
    return LessonProgress(
      lessonId: json['lesson_id'] as int?,
      theoryCompleted: (json['theory_completed'] as bool?) ?? false,
      practiceApproved: (json['practice_approved'] as bool?) ?? false,
      bestScorePercent: (json['best_score_percent'] as num?)?.toDouble(),
    );
  }

  final int? lessonId;
  final bool theoryCompleted;
  final bool practiceApproved;
  final double? bestScorePercent;

  bool get completed => theoryCompleted && practiceApproved;
}

/// Answer sent in `POST /training-attempts`.
class AttemptAnswer {
  const AttemptAnswer({
    required this.questionId,
    required this.selectedOptionIds,
  });

  final int questionId;
  final List<int> selectedOptionIds;

  Map<String, dynamic> toJson() => {
    'question_id': questionId,
    'selected_option_ids': selectedOptionIds,
  };
}

/// Server-graded result of a practice attempt.
class TrainingAttemptResult {
  const TrainingAttemptResult({
    required this.lessonId,
    required this.scorePercent,
    required this.requiredApprovalPercent,
    required this.approved,
    required this.correctByQuestionId,
  });

  factory TrainingAttemptResult.fromJson(Map<String, dynamic> json) {
    return TrainingAttemptResult(
      lessonId: json['lesson_id'] as int,
      scorePercent: (json['score_percent'] as num).toDouble(),
      requiredApprovalPercent: json['required_approval_percent'] as int,
      approved: json['approved'] as bool,
      correctByQuestionId: {
        for (final answer in (json['answers'] as List? ?? const []))
          (answer as Map<String, dynamic>)['question_id'] as int:
              answer['is_correct'] as bool,
      },
    );
  }

  final int lessonId;
  final double scorePercent;
  final int requiredApprovalPercent;
  final bool approved;
  final Map<int, bool> correctByQuestionId;

  int get correctAnswers =>
      correctByQuestionId.values.where((correct) => correct).length;
}

/// Row of `GET /courses/progress`.
class CourseProgressRow {
  const CourseProgressRow({
    required this.username,
    required this.fullName,
    required this.storeCode,
    required this.courseId,
    required this.courseTitle,
    required this.lessonsTotal,
    required this.lessonsCompleted,
    required this.lastActivity,
  });

  factory CourseProgressRow.fromJson(Map<String, dynamic> json) {
    final lastActivity = json['last_activity'];
    return CourseProgressRow(
      username: json['username'] as String,
      fullName: (json['full_name'] as String?) ?? '',
      storeCode: json['store_code'] as String?,
      courseId: json['course_id'] as int,
      courseTitle: (json['course_title'] as String?) ?? '',
      lessonsTotal: (json['lessons_total'] as int?) ?? 0,
      lessonsCompleted: (json['lessons_completed'] as int?) ?? 0,
      lastActivity: lastActivity == null
          ? null
          : DateTime.tryParse('$lastActivity'),
    );
  }

  final String username;
  final String fullName;
  final String? storeCode;
  final int courseId;
  final String courseTitle;
  final int lessonsTotal;
  final int lessonsCompleted;
  final DateTime? lastActivity;
}
