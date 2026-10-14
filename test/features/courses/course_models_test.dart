import 'package:flutter_test/flutter_test.dart';
import 'package:hercules_control/features/courses/data/course_models.dart';

Map<String, dynamic> _courseReadJson() => {
  'id': 7,
  'title': 'Ruta Ofertas',
  'description': 'Cobranza segura',
  'status': 'active',
  'sort_order': 2,
  'active': true,
  'created_at': '2026-10-01T10:00:00',
  'updated_at': '2026-10-01T10:00:00',
  'stores': [
    {'id': 1, 'store_code': 'Ofertas'},
  ],
  'lessons': [
    {
      'id': 21,
      'course_id': 7,
      'title': 'Segunda',
      'summary': 'Resumen 2',
      'theory': 'Teoría 2',
      'required_approval_percent': 70,
      'sort_order': 2,
      'active': true,
      'created_at': '2026-10-01T10:00:00',
      'updated_at': '2026-10-01T10:00:00',
      'theory_images': [],
      'questions': [
        {
          'id': 301,
          'lesson_id': 21,
          'prompt': '¿Cuál?',
          'question_type': 'text',
          'answer_mode': 'multiple',
          'image_url': null,
          'sort_order': 1,
          'active': true,
          'created_at': '2026-10-01T10:00:00',
          'updated_at': '2026-10-01T10:00:00',
          'options': [
            {
              'id': 3002,
              'label': 'B',
              'media_url': null,
              'option_type': 'text',
              'is_correct': true,
              'sort_order': 2,
            },
            {
              'id': 3001,
              'label': 'A',
              'media_url': null,
              'option_type': 'text',
              'is_correct': true,
              'sort_order': 1,
            },
            {
              'id': 3003,
              'label': 'C',
              'media_url': null,
              'option_type': 'text',
              'is_correct': false,
              'sort_order': 3,
            },
          ],
        },
      ],
    },
    {
      'id': 20,
      'course_id': 7,
      'title': 'Primera',
      'summary': 'Resumen 1',
      'theory': 'Teoría 1',
      'required_approval_percent': 80,
      'sort_order': 1,
      'active': true,
      'created_at': '2026-10-01T10:00:00',
      'updated_at': '2026-10-01T10:00:00',
      'theory_images': [
        {'id': 5, 'url': 'data:image/png;base64,BBB', 'sort_order': 2},
        {'id': 4, 'url': 'https://example.com/a.png', 'sort_order': 1},
      ],
      'questions': [
        {
          'id': 200,
          'lesson_id': 20,
          'prompt': '¿Foto?',
          'question_type': 'image',
          'answer_mode': 'single',
          'image_url': 'https://example.com/q.png',
          'sort_order': 1,
          'active': true,
          'created_at': '2026-10-01T10:00:00',
          'updated_at': '2026-10-01T10:00:00',
          'options': [
            {
              'id': 2001,
              'label': 'Sí',
              'media_url': null,
              'option_type': 'text',
              'is_correct': true,
              'sort_order': 1,
            },
            {
              'id': 2002,
              'label': 'No',
              'media_url': null,
              'option_type': 'text',
              'is_correct': false,
              'sort_order': 2,
            },
          ],
        },
      ],
    },
  ],
};

void main() {
  test('maps CourseRead JSON ordered by sort_order', () {
    final course = Course.fromJson(_courseReadJson());

    expect(course.id, 7);
    expect(course.status, CourseStatus.active);
    expect(course.stores, ['Ofertas']);
    expect(course.lessons.map((lesson) => lesson.id), [20, 21]);
    expect(course.lessons.first.theoryImageUrls, [
      'https://example.com/a.png',
      'data:image/png;base64,BBB',
    ]);
    final multiple = course.lessons[1].questions.single;
    expect(multiple.answerMode, AnswerMode.multiple);
    expect(multiple.options.map((option) => option.id), [3001, 3002, 3003]);
    expect(multiple.correctOptionIndexes, [0, 1]);
  });

  test('PUT payload keeps ids and renumbers sort orders', () {
    final course = Course.fromJson(_courseReadJson());
    final payload = course.toPayload();

    expect(payload['title'], 'Ruta Ofertas');
    expect(payload['status'], 'active');
    expect(payload['stores'], ['Ofertas']);

    final lessons = payload['lessons'] as List;
    expect(lessons.map((lesson) => lesson['id']), [20, 21]);
    expect(lessons.map((lesson) => lesson['sort_order']), [1, 2]);

    final firstLesson = lessons.first as Map<String, dynamic>;
    expect(firstLesson['theory_images'], [
      {'url': 'https://example.com/a.png', 'sort_order': 1},
      {'url': 'data:image/png;base64,BBB', 'sort_order': 2},
    ]);
    final imageQuestion = (firstLesson['questions'] as List).single as Map;
    expect(imageQuestion['id'], 200);
    expect(imageQuestion['question_type'], 'image');
    expect(imageQuestion['image_url'], 'https://example.com/q.png');
    expect((imageQuestion['options'] as List).map((option) => option['id']), [
      2001,
      2002,
    ]);

    final options =
        ((lessons[1]['questions'] as List).single as Map)['options'] as List;
    expect(options.map((option) => option['id']), [3001, 3002, 3003]);
    expect(options.map((option) => option['sort_order']), [1, 2, 3]);
    expect(options.map((option) => option['is_correct']), [true, true, false]);
  });

  test('new items are sent without id and edits keep the original ids', () {
    final course = Course.fromJson(_courseReadJson());
    final first = course.lessons.first;
    final edited = course.copyWith(
      title: 'Ruta Ofertas v2',
      lessons: [
        first.copyWith(
          title: 'Primera editada',
          questions: [
            first.questions.single.copyWith(prompt: '¿Foto nueva?'),
            PracticeQuestion.blank().copyWith(
              prompt: 'Nueva',
              options: const [
                QuestionOption(label: 'Uno', isCorrect: true),
                QuestionOption(label: 'Dos'),
              ],
            ),
          ],
        ),
        Lesson.template(),
      ],
    );

    final lessons = edited.toPayload()['lessons'] as List;
    expect(lessons, hasLength(2));
    expect(lessons[0]['id'], 20);
    expect(lessons[0]['title'], 'Primera editada');
    expect(lessons[1].containsKey('id'), isFalse);

    final questions = lessons[0]['questions'] as List;
    expect(questions[0]['id'], 200);
    expect(questions[0]['prompt'], '¿Foto nueva?');
    expect(questions[1].containsKey('id'), isFalse);
    expect(questions.map((question) => question['sort_order']), [1, 2]);
    expect(edited.validationErrors(), isEmpty);
  });

  test('a moved question loses its ids so the server recreates it', () {
    final question = Course.fromJson(
      _courseReadJson(),
    ).lessons.first.questions.single.withoutIds();
    final payload = question.toPayload(1);

    expect(payload.containsKey('id'), isFalse);
    expect(
      (payload['options'] as List).every(
        (option) => !(option as Map).containsKey('id'),
      ),
      isTrue,
    );
  });

  test('student JSON carries bank size instead of questions', () {
    final course = Course.fromJson({
      'id': 1,
      'title': 'Curso',
      'description': null,
      'sort_order': 1,
      'stores': [
        {'id': 1, 'store_code': 'Mexi'},
      ],
      'lessons': [
        {
          'id': 2,
          'course_id': 1,
          'title': 'L',
          'summary': 'S',
          'theory': 'T',
          'required_approval_percent': 80,
          'sort_order': 1,
          'theory_images': [],
          'question_bank_size': 12,
          'questions_per_attempt': 5,
        },
      ],
    });

    final lesson = course.lessons.single;
    expect(course.status, CourseStatus.active);
    expect(lesson.questions, isEmpty);
    expect(lesson.bankSize, 12);
    expect(lesson.practiceSize, 5);
  });

  test('questions_per_attempt round-trips and null means the whole bank', () {
    final json = _courseReadJson();
    // Lesson 20 (sort_order 1) has a bank of one question.
    (json['lessons'] as List).firstWhere(
      (lesson) => lesson['id'] == 20,
    )['questions_per_attempt'] = 1;
    final course = Course.fromJson(json);

    expect(course.lessons.first.questionsPerAttempt, 1);
    expect(course.lessons[1].questionsPerAttempt, isNull);
    expect(course.lessons[1].practiceSize, 1);

    final lessons = course.toPayload()['lessons'] as List;
    expect(lessons[0]['questions_per_attempt'], 1);
    expect(lessons[1]['questions_per_attempt'], isNull);

    final cleared = course.lessons.first.copyWith(
      clearQuestionsPerAttempt: true,
    );
    expect(cleared.questionsPerAttempt, isNull);
  });

  test('bank validation: per-attempt must be within 1..bank size', () {
    expect(questionsPerAttemptError(null, 3), isNull);
    expect(questionsPerAttemptError(3, 3), isNull);
    expect(questionsPerAttemptError(0, 3), isNotNull);
    expect(questionsPerAttemptError(4, 3), isNotNull);

    final course = Course.fromJson(_courseReadJson());
    final tooMany = course.copyWith(
      lessons: [
        course.lessons.first,
        course.lessons[1].copyWith(questionsPerAttempt: 2),
      ],
    );
    expect(tooMany.validationErrors(), [
      'Lección 2: pide 2 preguntas por práctica pero el banco tiene 1.',
    ]);
  });

  test('validation points to lesson and question and checks lengths', () {
    final course = Course.fromJson(_courseReadJson());
    final broken = course.copyWith(
      title: 'x' * 121,
      lessons: [
        course.lessons.first.copyWith(
          title: '',
          requiredApprovalPercent: 0,
          questions: [
            course.lessons.first.questions.single.copyWith(
              prompt: ' ',
              options: const [
                QuestionOption(label: 'A', isCorrect: true),
                QuestionOption(label: ' '),
              ],
            ),
          ],
        ),
      ],
    );

    expect(
      broken.validationErrors(),
      containsAll([
        'El título del curso admite máximo 120 caracteres.',
        'Lección 1: falta el título.',
        'Lección 1: el % de aprobación debe estar entre 1 y 100.',
        'Lección 1, pregunta 1: falta el enunciado.',
        'Lección 1, pregunta 1: hay opciones vacías.',
      ]),
    );
  });

  test('practice session keeps the server order of questions and options', () {
    final session = PracticeSession.fromJson({
      'session_id': 55,
      'lesson_id': 20,
      'required_approval_percent': 70,
      'questions': [
        {
          'id': 9,
          'prompt': 'Segunda',
          'question_type': 'text',
          'answer_mode': 'single',
          'image_url': null,
          'sort_order': 2,
          'options': [
            {
              'id': 92,
              'label': 'B',
              'media_url': null,
              'option_type': 'text',
              'sort_order': 2,
            },
            {
              'id': 91,
              'label': 'A',
              'media_url': null,
              'option_type': 'text',
              'sort_order': 1,
            },
          ],
        },
        {
          'id': 8,
          'prompt': 'Primera',
          'question_type': 'text',
          'answer_mode': 'single',
          'image_url': null,
          'sort_order': 1,
          'options': [],
        },
      ],
    });

    expect(session.sessionId, 55);
    expect(session.requiredApprovalPercent, 70);
    expect(session.questions.map((question) => question.id), [9, 8]);
    expect(session.questions.first.options.map((option) => option.id), [
      92,
      91,
    ]);
  });

  test('validation reports missing stores and wrong correct answers', () {
    final course = Course.template().copyWith(
      lessons: [
        Lesson.template().copyWith(
          questions: [
            const PracticeQuestion(
              prompt: 'P',
              options: [
                QuestionOption(label: 'A', isCorrect: true),
                QuestionOption(label: 'B', isCorrect: true),
              ],
            ),
          ],
        ),
      ],
    );

    expect(
      course.validationErrors(),
      containsAll([
        'Elige al menos una tienda.',
        'Lección 1, pregunta 1: marca exactamente una opción correcta.',
      ]),
    );
  });

  test('attempt result maps per-question correctness', () {
    final result = TrainingAttemptResult.fromJson({
      'id': 1,
      'employee_reference': 'ana',
      'lesson_id': 20,
      'score_percent': 50.0,
      'required_approval_percent': 80,
      'approved': false,
      'created_at': '2026-10-01T10:00:00',
      'answers': [
        {
          'id': 1,
          'question_id': 200,
          'is_correct': true,
          'selected_options': [
            {'id': 1, 'option_id': 2001},
          ],
        },
        {
          'id': 2,
          'question_id': 201,
          'is_correct': false,
          'selected_options': [
            {'id': 2, 'option_id': 2011},
          ],
        },
      ],
    });

    expect(result.correctByQuestionId, {200: true, 201: false});
    expect(result.correctAnswers, 1);
    expect(result.approved, isFalse);
  });

  test('theory_videos and video_url round-trip in the course payload', () {
    final json = _courseReadJson();
    final lesson20 =
        (json['lessons'] as List).firstWhere((lesson) => lesson['id'] == 20)
            as Map<String, dynamic>;
    lesson20['theory_videos'] = [
      {
        'id': 2,
        'url': 'https://vimeo.com/76979871',
        'title': null,
        'sort_order': 2,
      },
      {
        'id': 1,
        'url': 'https://youtu.be/dQw4w9WgXcQ',
        'title': 'Intro',
        'sort_order': 1,
      },
    ];
    ((lesson20['questions'] as List).single as Map)['video_url'] =
        'https://example.com/clase.mp4';

    final course = Course.fromJson(json);
    final lesson = course.lessons.first;
    expect(lesson.theoryVideos.map((video) => video.url), [
      'https://youtu.be/dQw4w9WgXcQ',
      'https://vimeo.com/76979871',
    ]);
    expect(lesson.theoryVideos.first.title, 'Intro');
    expect(lesson.questions.single.videoUrl, 'https://example.com/clase.mp4');
    expect(lesson.hasVideo, isTrue);
    expect(course.lessons[1].hasVideo, isFalse);

    final lessons = course.toPayload()['lessons'] as List;
    expect(lessons[0]['theory_videos'], [
      {
        'url': 'https://youtu.be/dQw4w9WgXcQ',
        'title': 'Intro',
        'sort_order': 1,
      },
      {'url': 'https://vimeo.com/76979871', 'title': null, 'sort_order': 2},
    ]);
    expect(
      (lessons[0]['questions'] as List).single['video_url'],
      'https://example.com/clase.mp4',
    );
    expect(lessons[1]['theory_videos'], isEmpty);
    expect((lessons[1]['questions'] as List).single['video_url'], isNull);

    // Empty video links are not sent and the moved copy keeps the video.
    final cleared = lesson.questions.single.copyWith(clearVideoUrl: true);
    expect(cleared.toPayload(1)['video_url'], isNull);
    expect(lesson.questions.single.withoutIds().videoUrl, isNotNull);
  });

  test('bad video links block saving with lesson/question context', () {
    final course = Course.fromJson(_courseReadJson());
    final first = course.lessons.first;
    final broken = course.copyWith(
      lessons: [
        first.copyWith(
          theoryVideos: const [TheoryVideo(url: 'www.youtube.com/x')],
          questions: [
            first.questions.single.copyWith(videoUrl: 'https://example.com/a'),
          ],
        ),
        course.lessons[1],
      ],
    );

    expect(broken.validationErrors(), [
      'Lección 1, video 1: El enlace del video debe empezar con http:// o https://.',
      'Lección 1, pregunta 1: El video debe ser un enlace de YouTube, Google Drive, Vimeo, un archivo .mp4 / .webm o un video subido a Hércules.',
    ]);
  });
}
