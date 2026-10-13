import 'package:hercules_control/core/api/api_client.dart';
import 'package:hercules_control/features/courses/data/course_models.dart';
import 'package:hercules_control/features/courses/data/question_bank.dart';

class CoursesRepository {
  const CoursesRepository(this._api);

  final ApiClient _api;

  List<Course> _courses(Object? json) => [
    for (final item in (json as List))
      Course.fromJson(item as Map<String, dynamic>),
  ];

  /// Full catalog with correct answers (`courses.view`).
  Future<List<Course>> fetchCourses() async =>
      _courses(await _api.get('/courses'));

  Future<Course> fetchCourse(int id) async =>
      Course.fromJson(await _api.get('/courses/$id') as Map<String, dynamic>);

  Future<Course> createCourse(Course course) async => Course.fromJson(
    await _api.post('/courses', body: course.toPayload())
        as Map<String, dynamic>,
  );

  Future<Course> updateCourse(Course course) async => Course.fromJson(
    await _api.put('/courses/${course.id}', body: course.toPayload())
        as Map<String, dynamic>,
  );

  Future<Course> setCourseActive(int id, bool active) async => Course.fromJson(
    await _api.patch('/courses/$id/active', body: {'is_active': active})
        as Map<String, dynamic>,
  );

  /// Courses assigned to the signed-in student (`courses.take`).
  Future<List<Course>> fetchAssignedCourses() async =>
      _courses(await _api.get('/courses/assigned'));

  /// Own lesson progress, keyed by lesson id.
  Future<Map<int, LessonProgress>> fetchLessonProgress({int? courseId}) async {
    final json = await _api.get(
      '/lesson-progress',
      query: courseId == null ? null : {'course_id': '$courseId'},
    );
    final progress = <int, LessonProgress>{};
    for (final item in (json as List)) {
      final row = LessonProgress.fromJson(item as Map<String, dynamic>);
      if (row.lessonId != null) progress[row.lessonId!] = row;
    }
    return progress;
  }

  Future<LessonProgress> markTheoryCompleted(int lessonId) async =>
      LessonProgress.fromJson(
        await _api.patch('/lesson-progress/$lessonId/theory-completed')
            as Map<String, dynamic>,
      );

  /// Draws a new random practice for the lesson. Every attempt (including a
  /// retry) needs a new session.
  Future<PracticeSession> startPractice(int lessonId) async =>
      PracticeSession.fromJson(
        await _api.post(
              '/training-attempts/start',
              body: {'lesson_id': lessonId},
            )
            as Map<String, dynamic>,
      );

  /// Sends the answers of a practice session; the server grades them.
  Future<TrainingAttemptResult> submitAttempt(
    int sessionId,
    List<AttemptAnswer> answers,
  ) async => TrainingAttemptResult.fromJson(
    await _api.post(
          '/training-attempts',
          body: {
            'session_id': sessionId,
            'answers': [for (final answer in answers) answer.toJson()],
          },
        )
        as Map<String, dynamic>,
  );

  Future<List<CourseProgressRow>> fetchProgressSummary() async {
    final json = await _api.get('/courses/progress') as List;
    return [
      for (final item in json)
        CourseProgressRow.fromJson(item as Map<String, dynamic>),
    ];
  }

  /// Every active question of every course (courses.view).
  Future<List<QuestionBankRow>> fetchQuestionBank({
    int? courseId,
    int? lessonId,
  }) async {
    final json =
        await _api.get(
              '/questions',
              query: {
                if (courseId != null) 'course_id': '$courseId',
                if (lessonId != null) 'lesson_id': '$lessonId',
              },
            )
            as List;
    return [
      for (final item in json)
        QuestionBankRow.fromJson(item as Map<String, dynamic>),
    ];
  }

  /// Updates one question (courses.manage). The returned row may have a new
  /// id when the server had to retire the old question to keep history.
  Future<QuestionBankRow> updateBankQuestion(
    int id,
    PracticeQuestion question,
  ) async => QuestionBankRow.fromJson(
    await _api.put(
          '/questions/$id',
          body: QuestionBankRow.updatePayload(question),
        )
        as Map<String, dynamic>,
  );

  /// Adds a question at the end of a lesson's bank (courses.manage).
  Future<QuestionBankRow> createBankQuestion(
    int lessonId,
    PracticeQuestion question,
  ) async => QuestionBankRow.fromJson(
    await _api.post(
          '/questions',
          body: {
            'lesson_id': lessonId,
            ...QuestionBankRow.updatePayload(question.withoutIds()),
          },
        )
        as Map<String, dynamic>,
  );

  /// Existing questions similar to [prompt] in every course (courses.manage).
  Future<List<SimilarQuestion>> findSimilarQuestions(
    String prompt, {
    int? excludeId,
    int? limit,
  }) async {
    final json =
        await _api.get(
              '/questions/similar',
              query: {
                'prompt': prompt.trim(),
                if (excludeId != null) 'exclude_id': '$excludeId',
                if (limit != null) 'limit': '$limit',
              },
            )
            as List;
    return [
      for (final item in json)
        SimilarQuestion.fromJson(item as Map<String, dynamic>),
    ];
  }
}
