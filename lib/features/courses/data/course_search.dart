import 'package:hercules_control/features/courses/data/course_models.dart';
import 'package:hercules_control/features/courses/data/question_bank.dart';

/// Parts of a lesson that can match the catalog search.
enum LessonMatchField {
  title('título'),
  summary('resumen'),
  theory('teoría'),
  videos('videos de teoría');

  const LessonMatchField(this.label);

  final String label;
}

/// A question that matched the catalog search, with its position.
class QuestionSearchMatch {
  const QuestionSearchMatch({
    required this.index,
    required this.question,
    required this.exactCode,
  });

  final int index;
  final PracticeQuestion question;

  /// The query is exactly the question's code (e.g. "p65" -> P65).
  final bool exactCode;
}

/// One group of results: a course, and optionally one of its lessons.
class CourseSearchHit {
  const CourseSearchHit({
    required this.course,
    required this.lessonIndex,
    this.lessonFields = const [],
    this.questions = const [],
    this.courseTitle = false,
  });

  final Course course;

  /// Null when only the course title matched.
  final int? lessonIndex;
  final List<LessonMatchField> lessonFields;
  final List<QuestionSearchMatch> questions;
  final bool courseTitle;

  Lesson? get lesson =>
      lessonIndex == null ? null : course.lessons[lessonIndex!];

  bool get hasExactCode => questions.any((match) => match.exactCode);
}

/// Searches courses, lessons and questions (case and accent insensitive).
/// Groups with an exact code match go first; the rest keep catalog order.
List<CourseSearchHit> searchCourseCatalog(List<Course> courses, String query) {
  final needle = normalizeForSearch(query.trim());
  if (needle.isEmpty) return const [];
  final exactCode = normalizeQuestionCode(query);

  bool matches(String? value) =>
      value != null && normalizeForSearch(value).contains(needle);

  final hits = <CourseSearchHit>[];
  for (final course in courses) {
    final lessonHits = <CourseSearchHit>[];
    for (final (lessonIndex, lesson) in course.lessons.indexed) {
      final fields = [
        if (matches(lesson.title)) LessonMatchField.title,
        if (matches(lesson.summary)) LessonMatchField.summary,
        if (matches(lesson.theory)) LessonMatchField.theory,
        if (lesson.theoryVideos.any((video) => matches(video.title)))
          LessonMatchField.videos,
      ];
      final questions = <QuestionSearchMatch>[
        for (final (index, question) in lesson.questions.indexed)
          if (matches(question.prompt) || matches(question.code))
            QuestionSearchMatch(
              index: index,
              question: question,
              exactCode: exactCode != null && question.code == exactCode,
            ),
      ]..sort((a, b) => (b.exactCode ? 1 : 0) - (a.exactCode ? 1 : 0));
      if (fields.isNotEmpty || questions.isNotEmpty) {
        lessonHits.add(
          CourseSearchHit(
            course: course,
            lessonIndex: lessonIndex,
            lessonFields: fields,
            questions: questions,
          ),
        );
      }
    }
    if (lessonHits.isEmpty && matches(course.title)) {
      hits.add(
        CourseSearchHit(course: course, lessonIndex: null, courseTitle: true),
      );
    }
    hits.addAll(lessonHits);
  }

  final exact = hits.where((hit) => hit.hasExactCode);
  return [...exact, ...hits.where((hit) => !hit.hasExactCode)];
}
