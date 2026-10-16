import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hercules_control/app/navigation/app_shell.dart';
import 'package:hercules_control/core/api/api_client.dart';
import 'package:hercules_control/core/auth/auth_controller.dart';
import 'package:hercules_control/core/auth/auth_scope.dart';
import 'package:hercules_control/core/auth/token_storage_memory.dart';
import 'package:hercules_control/core/theme/app_theme.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'question_bank_test.dart' show bankRowJson;

Map<String, dynamic> _question(int lessonId, int index) => {
  'id': lessonId * 10 + index,
  'lesson_id': lessonId,
  'prompt': 'Pregunta $index de $lessonId',
  if (lessonId == 11 && index == 2) 'code': 'P65',
  'question_type': 'text',
  'answer_mode': 'single',
  'image_url': null,
  'sort_order': index,
  'active': true,
  'options': [
    {
      'id': (lessonId * 10 + index) * 10 + 1,
      'label': 'Correcta $index',
      'media_url': null,
      'option_type': 'text',
      'is_correct': true,
      'sort_order': 1,
    },
    {
      'id': (lessonId * 10 + index) * 10 + 2,
      'label': 'Incorrecta $index',
      'media_url': null,
      'option_type': 'text',
      'is_correct': false,
      'sort_order': 2,
    },
  ],
};

Map<String, dynamic> _lesson(int lessonId, {required bool student}) => {
  'id': lessonId,
  'course_id': 1,
  'title': 'Lección $lessonId',
  'summary': 'Resumen',
  'theory': 'Teoría',
  'required_approval_percent': 80,
  'sort_order': lessonId,
  'active': true,
  'theory_images': [],
  if (student) ...{
    'question_bank_size': 3,
    'questions_per_attempt': lessonId == 11 ? 2 : 3,
  } else ...{
    'questions_per_attempt': lessonId == 11 ? 2 : null,
    'questions': [
      for (final index in [1, 2, 3]) _question(lessonId, index),
    ],
  },
};

Map<String, dynamic> _course({required bool student}) => {
  'id': 1,
  'title': 'Ruta Mexi',
  'description': 'Cobranza',
  'status': 'active',
  'sort_order': 1,
  'active': true,
  'stores': [
    {'id': 1, 'store_code': 'Mexi'},
  ],
  'lessons': [
    for (final lessonId in [10, 11]) _lesson(lessonId, student: student),
  ],
};

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

final _starts = <Map<String, dynamic>>[];
final _coursePuts = <Map<String, dynamic>>[];
final _similarPrompts = <String>[];
var _similarFails = false;
final _attempts = <Map<String, dynamic>>[];
var _approveAttempts = true;

Future<AuthController> _signIn(
  WidgetTester tester,
  String role,
  List<String> permissions, {
  bool secondTheoryDone = false,
}) async {
  final client = MockClient((request) async {
    final path = request.url.path;
    if (path.endsWith('/questions/similar')) {
      final prompt = request.url.queryParameters['prompt']!;
      _similarPrompts.add(prompt);
      if (_similarFails) return _json({'detail': 'Error interno.'}, 500);
      return _json([
        if (prompt.contains('SPEI'))
          {
            ...bankRowJson(
              id: 7,
              prompt: 'Cómo se valida una transferencia SPEI',
            ),
            'similarity': 0.91,
          },
      ]);
    }
    if (request.method == 'PUT' && path.endsWith('/courses/1')) {
      _coursePuts.add(jsonDecode(request.body) as Map<String, dynamic>);
      return _json(_course(student: false));
    }
    if (path.endsWith('/training-attempts/start')) {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      _starts.add(body);
      final lessonId = body['lesson_id'] as int;
      // Two questions drawn from the bank, options already shuffled.
      return _json({
        'session_id': 100 + _starts.length,
        'lesson_id': lessonId,
        'required_approval_percent': 80,
        'questions': [
          for (final index in [3, 1])
            {
              ..._question(lessonId, index),
              if (index == 3) 'video_url': 'https://youtu.be/dQw4w9WgXcQ',
              'options': [
                for (final option
                    in (_question(lessonId, index)['options'] as List).reversed)
                  {...(option as Map<String, dynamic>)}..remove('is_correct'),
              ],
            },
        ],
      }, 201);
    }
    if (path.endsWith('/training-attempts')) {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      _attempts.add(body);
      return _json({
        'id': 9,
        'employee_reference': 'u',
        'lesson_id': 11,
        'score_percent': _approveAttempts ? 100.0 : 50.0,
        'required_approval_percent': 80,
        'approved': _approveAttempts,
        'created_at': '2026-10-12T15:30:00',
        'answers': [
          for (final answer in body['answers'] as List)
            {
              'id': 1,
              'question_id': answer['question_id'],
              'is_correct': _approveAttempts || answer['question_id'] == 113,
              'selected_options': [],
            },
        ],
      }, 201);
    }
    if (path.endsWith('/auth/token')) {
      return _json({'access_token': 't', 'token_type': 'bearer'});
    }
    if (path.endsWith('/auth/me')) {
      return _json({
        'id': 1,
        'username': 'u',
        'full_name': 'Usuario Prueba',
        'role': role,
        'store_code': 'Mexi',
        'permissions': permissions,
      });
    }
    if (path.endsWith('/courses/assigned')) {
      return _json([_course(student: true)]);
    }
    if (path.endsWith('/courses/progress')) {
      return _json([
        {
          'username': 'ana',
          'full_name': 'Ana',
          'store_code': 'Mexi',
          'course_id': 1,
          'course_title': 'Ruta Mexi',
          'lessons_total': 2,
          'lessons_completed': 1,
          'last_activity': '2026-10-12T15:30:00',
        },
      ]);
    }
    if (path.endsWith('/courses')) return _json([_course(student: false)]);
    if (path.endsWith('/lesson-progress')) {
      return _json([
        {
          'id': 1,
          'employee_reference': 'u',
          'lesson_id': 10,
          'theory_completed': true,
          'practice_approved': true,
          'best_score_percent': 100.0,
          'completed_at': null,
          'updated_at': '2026-10-12T15:30:00',
        },
        if (secondTheoryDone)
          {
            'id': 2,
            'employee_reference': 'u',
            'lesson_id': 11,
            'theory_completed': true,
            'practice_approved': false,
            'best_score_percent': null,
            'completed_at': null,
            'updated_at': '2026-10-12T15:30:00',
          },
      ]);
    }
    if (path.endsWith('/users')) return _json([]);
    return _json({'detail': 'No encontrado.'}, 404);
  });
  final auth = AuthController(
    api: ApiClient(baseUrl: 'http://api.test/api', httpClient: client),
    storage: TokenStorage(),
  );
  await tester.runAsync(() => auth.login('u', 'secreto123'));
  return auth;
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _pumpShell(WidgetTester tester, AuthController auth) async {
  tester.view.physicalSize = const Size(1600, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    AuthScope(
      controller: auth,
      child: MaterialApp(theme: AppTheme.light(), home: const AppShell()),
    ),
  );
  await _settle(tester);
}

void main() {
  setUp(() {
    _starts.clear();
    _attempts.clear();
    _approveAttempts = true;
    _coursePuts.clear();
    _similarPrompts.clear();
    _similarFails = false;
  });

  testWidgets('alumno sees assigned courses, progress and bank size', (
    tester,
  ) async {
    final auth = await _signIn(tester, 'alumno', ['courses.take']);
    await _pumpShell(tester, auth);

    expect(find.text('Mis cursos'), findsOneWidget);
    expect(find.text('Ruta Mexi'), findsWidgets);
    expect(find.text('Completa'), findsOneWidget);
    expect(find.text('Falta teoría'), findsOneWidget);
    expect(
      find.text(
        'Práctica: 2 preguntas al azar de un banco de 3 · aprueba con 80%',
      ),
      findsOneWidget,
    );
    expect(find.text('Usuarios'), findsNothing);
    expect(find.text('Editar plantilla'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('practice starts a session, submits with session_id once', (
    tester,
  ) async {
    final auth = await _signIn(tester, 'alumno', [
      'courses.take',
    ], secondTheoryDone: true);
    await _pumpShell(tester, auth);

    await tester.tap(find.text('Iniciar práctica'));
    await _settle(tester);
    expect(_starts, [
      {'lesson_id': 11},
    ]);
    expect(find.text('Pregunta 1 de 2'), findsOneWidget);
    // The first drawn question has a video: 3 minutes instead of 60 s.
    expect(
      find.text(
        'Pregunta con video: tienes 3 minutos · Tiempo restante: 3:00 min',
      ),
      findsOneWidget,
    );
    expect(find.text('Abrir video'), findsOneWidget);

    // Can't advance without answering.
    final next = find.widgetWithText(FilledButton, 'Siguiente pregunta');
    expect(tester.widget<FilledButton>(next).onPressed, isNull);

    await tester.tap(find.text('Correcta 3'));
    await tester.pump();
    await tester.tap(next);
    await tester.pump();
    await tester.tap(find.text('Incorrecta 1'));
    await tester.pump();
    await tester.tap(find.text('Enviar respuestas'));
    await _settle(tester);

    expect(_attempts, [
      {
        'session_id': 101,
        'answers': [
          {
            'question_id': 113,
            'selected_option_ids': [1131],
          },
          {
            'question_id': 111,
            'selected_option_ids': [1112],
          },
        ],
      },
    ]);
    expect(find.textContaining('Aprobado: 100%'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Cerrar').last);
    await _settle(tester);
  });

  testWidgets('retry after failing starts a brand new session', (tester) async {
    _approveAttempts = false;
    final auth = await _signIn(tester, 'alumno', [
      'courses.take',
    ], secondTheoryDone: true);
    await _pumpShell(tester, auth);

    await tester.tap(find.text('Iniciar práctica'));
    await _settle(tester);
    await tester.tap(find.text('Correcta 3'));
    await tester.pump();
    await tester.tap(find.text('Siguiente pregunta'));
    await tester.pump();
    await tester.tap(find.text('Correcta 1'));
    await tester.pump();
    await tester.tap(find.text('Enviar respuestas'));
    await _settle(tester);

    expect(find.textContaining('No aprobado: 50%'), findsOneWidget);
    await tester.tap(find.text('Intentar de nuevo'));
    await _settle(tester);

    expect(_starts, hasLength(2));
    expect(find.text('Pregunta 1 de 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('closing mid-practice asks for confirmation', (tester) async {
    final auth = await _signIn(tester, 'alumno', [
      'courses.take',
    ], secondTheoryDone: true);
    await _pumpShell(tester, auth);

    await tester.tap(find.text('Iniciar práctica'));
    await _settle(tester);
    await tester.tap(find.text('Correcta 3'));
    await tester.pump();
    await tester.tap(find.byTooltip('Cerrar'));
    await _settle(tester);

    expect(
      find.text('Perderás las respuestas de esta práctica.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Seguir respondiendo'));
    await _settle(tester);
    expect(find.text('Pregunta 1 de 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('administrator sees catalog editor, bank info and Usuarios', (
    tester,
  ) async {
    final auth = await _signIn(tester, 'administrador', [
      'courses.view',
      'courses.manage',
      'courses.progress.view',
      'users.manage',
    ]);
    await _pumpShell(tester, auth);

    expect(find.text('Nuevo curso'), findsOneWidget);
    expect(find.text('Usuarios'), findsOneWidget);
    expect(find.text('2 de 3 al azar'), findsOneWidget);
    expect(find.text('3 de 3 al azar'), findsOneWidget);

    await tester.ensureVisible(find.text('Editar plantilla'));
    await tester.pump();
    await tester.tap(find.text('Editar plantilla'));
    await _settle(tester);
    expect(find.text('Guardar curso'), findsOneWidget);
    expect(
      find.text('Banco: 3 preguntas. Cada práctica toma 3 al azar.'),
      findsOneWidget,
    );

    // A bad question video link is rejected inline.
    final videoField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText ==
              'Enlace de YouTube, Google Drive, Vimeo o .mp4 / .webm, o súbelo desde la computadora',
    );
    await tester.enterText(videoField.first, 'https://example.com/clase');
    await tester.pump();
    expect(
      find.text(
        'El video debe ser un enlace de YouTube, Google Drive, Vimeo, un archivo .mp4 / .webm o un video subido a Hércules.',
      ),
      findsOneWidget,
    );

    // Invalid "Preguntas por práctica" shows an inline error.
    final perAttempt = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.hintText == 'Vacío = todas',
    );
    await tester.enterText(perAttempt, '9');
    await tester.pump();
    expect(
      find.text('Debe estar entre 1 y 3 (tamaño del banco).'),
      findsOneWidget,
    );

    // Unsaved changes ask before discarding.
    await tester.tap(find.text('Cancelar'));
    await _settle(tester);
    expect(find.text('¿Descartar los cambios?'), findsOneWidget);
    await tester.tap(find.text('Descartar'));
    await _settle(tester);
    expect(find.text('Guardar curso'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('supervisor gets read-only catalog and progress table', (
    tester,
  ) async {
    final auth = await _signIn(tester, 'supervisor', [
      'courses.view',
      'courses.progress.view',
    ]);
    await _pumpShell(tester, auth);

    expect(find.text('Editar plantilla'), findsNothing);
    expect(find.text('Nuevo curso'), findsNothing);

    await tester.tap(find.text('Avance de alumnos'));
    await _settle(tester);
    expect(find.text('1/2'), findsOneWidget);
    expect(find.text('12/10/2026 3:30 p. m.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  Future<void> addNewQuestionAndSave(WidgetTester tester) async {
    final auth = await _signIn(tester, 'administrador', [
      'courses.view',
      'courses.manage',
    ]);
    await _pumpShell(tester, auth);
    await tester.ensureVisible(find.text('Editar plantilla'));
    await tester.pump();
    await tester.tap(find.text('Editar plantilla'));
    await _settle(tester);

    final add = find.text('Agregar pregunta');
    await tester.ensureVisible(add);
    await tester.tap(add);
    await _settle(tester);

    // Last card: question text, option 1, option 2.
    final fields = find.byType(TextFormField);
    final count = tester.widgetList(fields).length;
    await tester.enterText(fields.at(count - 3), '¿Cómo valido un SPEI?');
    await tester.enterText(fields.at(count - 2), 'En Banxico');
    await tester.enterText(fields.at(count - 1), 'No se valida');
    await tester.pump();
    await tester.tap(find.text('Guardar curso'));
    await _settle(tester);
  }

  testWidgets('course editor groups similar matches of new questions', (
    tester,
  ) async {
    await addNewQuestionAndSave(tester);

    // Only the new question (without id) is checked.
    expect(_similarPrompts, ['¿Cómo valido un SPEI?']);
    expect(
      find.text('Hay 1 pregunta nueva parecida a otras del banco'),
      findsOneWidget,
    );
    expect(
      find.text('Lección 1, pregunta 4: ¿Cómo valido un SPEI?'),
      findsOneWidget,
    );
    expect(find.textContaining('91 % parecida'), findsOneWidget);

    await tester.tap(find.text('Revisar'));
    await _settle(tester);
    expect(_coursePuts, isEmpty);

    await tester.tap(find.text('Guardar curso'));
    await _settle(tester);
    await tester.tap(find.text('Guardar de todos modos'));
    await _settle(tester);
    expect(_coursePuts, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('course editor saves when the similar check fails', (
    tester,
  ) async {
    _similarFails = true;
    await addNewQuestionAndSave(tester);

    expect(_similarPrompts, hasLength(1));
    expect(find.textContaining('parecida'), findsNothing);
    expect(_coursePuts, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  Finder searchField() => find.byWidgetPredicate(
    (widget) =>
        widget is TextField &&
        widget.decoration?.hintText ==
            'Buscar lección, pregunta o código (P65)',
  );

  testWidgets('catalog search finds a question by code and opens it', (
    tester,
  ) async {
    final auth = await _signIn(tester, 'administrador', [
      'courses.view',
      'courses.manage',
    ]);
    await _pumpShell(tester, auth);

    await tester.enterText(searchField(), 'p65');
    await tester.pump();
    expect(find.text('Ruta Mexi › Lección 2: Lección 11'), findsOneWidget);
    expect(find.text('P65'), findsOneWidget);
    // The course list and detail panel are hidden while searching.
    expect(find.text('Editar plantilla'), findsNothing);

    await tester.tap(find.text('Pregunta 2: Pregunta 2 de 11'));
    await _settle(tester);
    expect(find.text('Editor · Lección 2'), findsOneWidget);
    expect(find.text('Guardar curso'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('catalog search ignores accents and clears back to the list', (
    tester,
  ) async {
    final auth = await _signIn(tester, 'administrador', [
      'courses.view',
      'courses.manage',
    ]);
    await _pumpShell(tester, auth);

    for (final query in ['leccion 10', 'LECCIÓN 10']) {
      await tester.enterText(searchField(), query);
      await tester.pump();
      expect(find.text('Ruta Mexi › Lección 1: Lección 10'), findsOneWidget);
      expect(find.text('Coincide en título de la lección.'), findsOneWidget);
      expect(find.text('Ruta Mexi › Lección 2: Lección 11'), findsNothing);
    }

    await tester.enterText(searchField(), 'teoria');
    await tester.pump();
    expect(find.text('Coincide en teoría de la lección.'), findsNWidgets(2));

    await tester.enterText(searchField(), 'zzz');
    await tester.pump();
    expect(find.textContaining('Sin resultados'), findsOneWidget);

    await tester.tap(find.byTooltip('Limpiar búsqueda'));
    await tester.pump();
    expect(find.text('Editar plantilla'), findsOneWidget);

    // Tapping a lesson result opens the editor on that lesson.
    await tester.enterText(searchField(), 'lección 11');
    await tester.pump();
    await tester.tap(find.text('Ruta Mexi › Lección 2: Lección 11'));
    await _settle(tester);
    expect(find.text('Editor · Lección 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('read-only staff opens the lesson preview from the search', (
    tester,
  ) async {
    final auth = await _signIn(tester, 'supervisor', ['courses.view']);
    await _pumpShell(tester, auth);

    await tester.enterText(searchField(), 'pregunta 3 de 10');
    await tester.pump();
    await tester.tap(find.text('Pregunta 3: Pregunta 3 de 10'));
    await _settle(tester);
    expect(find.text('Ruta Mexi · Lección 1'), findsOneWidget);
    expect(find.text('Guardar curso'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
