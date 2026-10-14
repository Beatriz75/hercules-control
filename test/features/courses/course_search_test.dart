import 'package:flutter_test/flutter_test.dart';
import 'package:hercules_control/features/courses/data/course_models.dart';
import 'package:hercules_control/features/courses/data/course_search.dart';

Map<String, dynamic> _question(int id, String prompt, {String? code}) => {
  'id': id,
  'lesson_id': id ~/ 10,
  'prompt': prompt,
  'code': code,
  'question_type': 'text',
  'answer_mode': 'single',
  'image_url': null,
  'sort_order': id % 10,
  'active': true,
  'options': [
    {
      'id': id * 10 + 1,
      'label': 'Sí',
      'option_type': 'text',
      'is_correct': true,
    },
    {
      'id': id * 10 + 2,
      'label': 'No',
      'option_type': 'text',
      'is_correct': false,
    },
  ],
};

Map<String, dynamic> _lesson(
  int id,
  String title, {
  String theory = '',
  List<Map<String, dynamic>> questions = const [],
}) => {
  'id': id,
  'course_id': 1,
  'title': title,
  'summary': 'Resumen',
  'theory': theory,
  'required_approval_percent': 80,
  'sort_order': id,
  'active': true,
  'theory_images': [],
  'questions': questions,
};

List<Course> _catalog() => [
  Course.fromJson({
    'id': 1,
    'title': 'Ruta Mexi',
    'status': 'active',
    'sort_order': 1,
    'active': true,
    'stores': ['Mexi'],
    'lessons': [
      _lesson(
        1,
        'Bienvenida',
        theory: 'Cómo usar el teléfono',
        questions: [
          _question(11, '¿Qué es una transferencia?', code: 'P650'),
          _question(12, 'Saludo inicial'),
        ],
      ),
      _lesson(
        2,
        'Cobranza básica',
        questions: [
          _question(21, '¿Cuándo se valida un pago?', code: 'P65'),
          _question(22, '¿Qué hago si no paga?', code: 'P66'),
        ],
      ),
    ],
  }),
  Course.fromJson({
    'id': 2,
    'title': 'Ruta Ofertas Logística',
    'status': 'draft',
    'sort_order': 2,
    'active': true,
    'stores': ['Ofertas'],
    'lessons': [_lesson(3, 'Entregas')],
  }),
];

void main() {
  test('empty query returns nothing', () {
    expect(searchCourseCatalog(_catalog(), '   '), isEmpty);
  });

  test('exact code goes first and inside its lesson', () {
    final hits = searchCourseCatalog(_catalog(), 'p65');

    // "P650" also contains "p65", but the exact P65 group is first.
    expect(hits, hasLength(2));
    expect(hits.first.lesson!.title, 'Cobranza básica');
    expect(hits.first.hasExactCode, isTrue);
    expect(hits.first.questions.single.question.code, 'P65');
    expect(hits.last.lesson!.title, 'Bienvenida');
    expect(hits.last.questions.single.question.code, 'P650');
  });

  test('text search ignores case and accents', () {
    final withoutAccent = searchCourseCatalog(_catalog(), 'COBRANZA BASICA');
    expect(withoutAccent.single.lessonFields, [LessonMatchField.title]);
    expect(withoutAccent.single.lessonIndex, 1);

    final prompt = searchCourseCatalog(_catalog(), 'cuando se valida');
    expect(prompt.single.questions.single.question.id, 21);

    final accented = searchCourseCatalog(_catalog(), 'teléfono');
    expect(accented.single.lessonFields, [LessonMatchField.theory]);
    expect(searchCourseCatalog(_catalog(), 'telefono'), hasLength(1));
  });

  test('course title alone gives a course-level result', () {
    final hits = searchCourseCatalog(_catalog(), 'logistica');
    expect(hits.single.courseTitle, isTrue);
    expect(hits.single.lessonIndex, isNull);
    expect(hits.single.course.id, 2);
  });
}
