import 'package:flutter_test/flutter_test.dart';
import 'package:hercules_control/features/courses/data/course_models.dart';
import 'package:hercules_control/features/courses/data/question_bank.dart';

Map<String, dynamic> bankRowJson({
  int id = 1,
  String prompt = '¿Qué validación aplica?',
  String answerMode = 'single',
  int lessonId = 10,
  int courseId = 1,
  List<String> stores = const ['Ofertas'],
  List<String> labels = const ['Revisar en Banxico', 'Aceptarlo'],
  String? videoUrl,
}) => {
  'id': id,
  'prompt': prompt,
  'question_type': 'text',
  'answer_mode': answerMode,
  'image_url': null,
  'video_url': videoUrl,
  'sort_order': 3,
  'options': [
    for (final label in labels.indexed)
      {
        'id': id * 10 + label.$1,
        'label': label.$2,
        'media_url': null,
        'option_type': 'text',
        'is_correct': label.$1 == 0,
        'sort_order': label.$1 + 1,
      },
  ],
  'lesson_id': lessonId,
  'lesson_title': 'Transferencias',
  'lesson_sort_order': 2,
  'course_id': courseId,
  'course_title': 'Ruta Ofertas',
  'course_status': 'draft',
  'course_active': false,
  'stores': stores,
};

void main() {
  test('parses a GET /questions row', () {
    final row = QuestionBankRow.fromJson(bankRowJson());

    expect(row.id, 1);
    expect(row.sortOrder, 3);
    expect(row.lessonTitle, 'Transferencias');
    expect(row.lessonSortOrder, 2);
    expect(row.courseStatus, CourseStatus.draft);
    expect(row.courseActive, isFalse);
    expect(row.stores, ['Ofertas']);
    expect(row.question.correctOptionIndexes, [0]);
  });

  test('PUT payload keeps option ids and leaves out question id/order', () {
    final row = QuestionBankRow.fromJson(bankRowJson());
    final edited = row.question.copyWith(
      prompt: 'Nuevo enunciado',
      options: [
        ...row.question.options,
        const QuestionOption(label: 'Nueva'),
      ],
    );
    final payload = QuestionBankRow.updatePayload(edited);

    expect(payload.containsKey('id'), isFalse);
    expect(payload.containsKey('sort_order'), isFalse);
    expect(payload['prompt'], 'Nuevo enunciado');
    final options = payload['options'] as List;
    expect(options.map((option) => option['id']), [10, 11, null]);
    expect(options.map((option) => option['sort_order']), [1, 2, 3]);
  });

  test('accent and case insensitive search over prompt and options', () {
    expect(normalizeForSearch('Validación ÑANDÚ'), 'validacion nandu');

    final rows = [
      QuestionBankRow.fromJson(bankRowJson(id: 1)),
      QuestionBankRow.fromJson(
        bankRowJson(id: 2, prompt: 'Pago en OXXO', labels: ['Código', 'No']),
      ),
    ];

    List<int> ids(String search) => QuestionBankFilter(
      search: search,
    ).apply(rows).map((row) => row.id).toList();

    expect(ids('VALIDACION'), [1]);
    expect(ids('banxico'), [1]);
    expect(ids('codigo'), [2]);
    expect(ids('  '), [1, 2]);
    expect(ids('inexistente'), isEmpty);
  });

  test('filters by store, course, lesson and answer mode', () {
    final rows = [
      QuestionBankRow.fromJson(bankRowJson(id: 1)),
      QuestionBankRow.fromJson(
        bankRowJson(
          id: 2,
          answerMode: 'multiple',
          stores: ['Mexi'],
          courseId: 2,
          lessonId: 20,
        ),
      ),
      QuestionBankRow.fromJson(bankRowJson(id: 3, lessonId: 11)),
    ];

    List<int> ids(QuestionBankFilter filter) =>
        filter.apply(rows).map((row) => row.id).toList();

    expect(ids(const QuestionBankFilter()), [1, 2, 3]);
    expect(ids(const QuestionBankFilter(store: 'Mexi')), [2]);
    expect(ids(const QuestionBankFilter(courseId: 1)), [1, 3]);
    expect(ids(const QuestionBankFilter(courseId: 1, lessonId: 11)), [3]);
    expect(ids(const QuestionBankFilter(answerMode: AnswerMode.multiple)), [2]);
    expect(
      ids(
        const QuestionBankFilter(
          store: 'Mexi',
        ).copyWith(clearStore: true, answerMode: AnswerMode.single),
      ),
      [1, 3],
    );
  });

  test('single-question validation mirrors the course editor', () {
    const question = PracticeQuestion(
      prompt: ' ',
      answerMode: AnswerMode.single,
      options: [
        QuestionOption(label: 'A', isCorrect: true),
        QuestionOption(label: 'B', isCorrect: true),
      ],
    );

    expect(practiceQuestionErrors(question), [
      'falta el enunciado.',
      'marca exactamente una opción correcta.',
    ]);
  });
}
