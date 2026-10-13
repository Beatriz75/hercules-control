import 'package:hercules_control/features/courses/data/course_models.dart';

/// Row of `GET /questions`: one question with its lesson and course context.
class QuestionBankRow {
  const QuestionBankRow({
    required this.question,
    required this.sortOrder,
    required this.lessonId,
    required this.lessonTitle,
    required this.lessonSortOrder,
    required this.courseId,
    required this.courseTitle,
    required this.courseStatus,
    required this.courseActive,
    required this.stores,
  });

  factory QuestionBankRow.fromJson(Map<String, dynamic> json) {
    return QuestionBankRow(
      question: PracticeQuestion.fromJson(json),
      sortOrder: (json['sort_order'] as int?) ?? 1,
      lessonId: json['lesson_id'] as int,
      lessonTitle: (json['lesson_title'] as String?) ?? '',
      lessonSortOrder: (json['lesson_sort_order'] as int?) ?? 1,
      courseId: json['course_id'] as int,
      courseTitle: (json['course_title'] as String?) ?? '',
      courseStatus: CourseStatus.fromCode(json['course_status'] as String?),
      courseActive: (json['course_active'] as bool?) ?? true,
      stores: [
        for (final store in (json['stores'] as List? ?? const []))
          store is Map ? '${store['store_code']}' : '$store',
      ],
    );
  }

  final PracticeQuestion question;
  final int sortOrder;
  final int lessonId;
  final String lessonTitle;
  final int lessonSortOrder;
  final int courseId;
  final String courseTitle;
  final CourseStatus courseStatus;
  final bool courseActive;
  final List<String> stores;

  int get id => question.id!;

  /// Body of `PUT /questions/{id}`: option ids are kept so they are updated
  /// in place; the question's sort order stays on the server.
  static Map<String, dynamic> updatePayload(PracticeQuestion question) {
    final payload = question.toPayload(1)
      ..remove('id')
      ..remove('sort_order');
    return payload;
  }
}

/// Lowercase and without accents, for accent-insensitive search.
String normalizeForSearch(String value) {
  const from = 'áàäâãéèëêíìïîóòöôõúùüûñç';
  const to = 'aaaaaeeeeiiiiooooouuuunc';
  final buffer = StringBuffer();
  for (final rune in value.toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    final index = from.indexOf(char);
    buffer.write(index == -1 ? char : to[index]);
  }
  return buffer.toString();
}

/// Filters of the "Banco de preguntas" page.
class QuestionBankFilter {
  const QuestionBankFilter({
    this.store,
    this.courseId,
    this.lessonId,
    this.answerMode,
    this.search = '',
  });

  final String? store;
  final int? courseId;
  final int? lessonId;
  final AnswerMode? answerMode;
  final String search;

  QuestionBankFilter copyWith({
    String? store,
    bool clearStore = false,
    int? courseId,
    bool clearCourse = false,
    int? lessonId,
    bool clearLesson = false,
    AnswerMode? answerMode,
    bool clearAnswerMode = false,
    String? search,
  }) {
    return QuestionBankFilter(
      store: clearStore ? null : store ?? this.store,
      courseId: clearCourse ? null : courseId ?? this.courseId,
      lessonId: clearLesson ? null : lessonId ?? this.lessonId,
      answerMode: clearAnswerMode ? null : answerMode ?? this.answerMode,
      search: search ?? this.search,
    );
  }

  bool matches(QuestionBankRow row) {
    if (store != null && !row.stores.contains(store)) return false;
    if (courseId != null && row.courseId != courseId) return false;
    if (lessonId != null && row.lessonId != lessonId) return false;
    if (answerMode != null && row.question.answerMode != answerMode) {
      return false;
    }
    final query = normalizeForSearch(search.trim());
    if (query.isEmpty) return true;
    final text = normalizeForSearch(
      [
        row.question.prompt,
        for (final option in row.question.options) option.label,
      ].join(' '),
    );
    return text.contains(query);
  }

  List<QuestionBankRow> apply(List<QuestionBankRow> rows) => [
    for (final row in rows)
      if (matches(row)) row,
  ];
}
