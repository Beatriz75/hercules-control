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

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

final _puts = <String, Map<String, dynamic>>{};
final _posts = <Map<String, dynamic>>[];
var _courses = <Map<String, dynamic>>[];

Map<String, dynamic> _courseJson() => {
  'id': 1,
  'title': 'Ruta Ofertas',
  'description': null,
  'status': 'active',
  'sort_order': 1,
  'active': true,
  'stores': [
    {'id': 1, 'store_code': 'Ofertas'},
  ],
  'lessons': [
    for (final lesson in [(9, 'Intro', 1), (10, 'Transferencias', 2)])
      {
        'id': lesson.$1,
        'course_id': 1,
        'title': lesson.$2,
        'summary': 'S',
        'theory': 'T',
        'required_approval_percent': 80,
        'questions_per_attempt': null,
        'sort_order': lesson.$3,
        'active': true,
        'theory_images': [],
        'questions': [],
      },
  ],
};

Future<AuthController> _signIn(
  WidgetTester tester,
  String role,
  List<String> permissions,
) async {
  final client = MockClient((request) async {
    final path = request.url.path;
    if (path.endsWith('/auth/token')) {
      return _json({'access_token': 't', 'token_type': 'bearer'});
    }
    if (path.endsWith('/auth/me')) {
      return _json({
        'id': 1,
        'username': 'u',
        'full_name': 'Usuario Prueba',
        'role': role,
        'store_code': null,
        'permissions': permissions,
      });
    }
    if (request.method == 'POST' && path.endsWith('/questions')) {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      _posts.add(body);
      return _json(
        bankRowJson(
          id: 500 + _posts.length,
          prompt: body['prompt'] as String,
          lessonId: body['lesson_id'] as int,
        ),
        201,
      );
    }
    if (request.method == 'PUT' && path.contains('/questions/')) {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      _puts[path] = body;
      // The server retired the old question and answers with a new id.
      return _json(bankRowJson(id: 99, prompt: body['prompt'] as String));
    }
    if (path.endsWith('/questions')) {
      return _json([
        bankRowJson(id: 1, videoUrl: 'https://youtu.be/dQw4w9WgXcQ'),
        bankRowJson(
          id: 2,
          prompt: 'Pago en OXXO',
          labels: ['Código de barras', 'Transferencia'],
        ),
      ]);
    }
    if (path.endsWith('/courses')) return _json(_courses);
    if (path.endsWith('/courses/progress')) return _json([]);
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

Future<void> _openBank(WidgetTester tester, AuthController auth) async {
  tester.view.physicalSize = const Size(1600, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    AuthScope(
      controller: auth,
      child: MaterialApp(theme: AppTheme.light(), home: const AppShell()),
    ),
  );
  await _settle(tester);
  await tester.tap(find.text('Banco de preguntas').first);
  await _settle(tester);
}

void main() {
  setUp(() {
    _puts.clear();
    _posts.clear();
    _courses = [_courseJson()];
  });

  testWidgets('supervisor sees the bank read-only with correct answers', (
    tester,
  ) async {
    final auth = await _signIn(tester, 'supervisor', [
      'courses.view',
      'courses.progress.view',
    ]);
    await _openBank(tester, auth);

    expect(find.text('2 preguntas'), findsOneWidget);
    expect(
      find.text('Ruta Ofertas · Lección 2: Transferencias'),
      findsOneWidget,
    );
    expect(find.text('Borrador'), findsOneWidget);
    expect(find.text('Inactivo'), findsOneWidget);
    expect(find.text('Pago en OXXO'), findsOneWidget);
    expect(find.text('Editar'), findsNothing);
    expect(find.text('Nueva pregunta'), findsNothing);

    // Video chip, collapsed until "Ver video".
    expect(find.text('Video'), findsOneWidget);
    expect(find.text('Abrir video'), findsNothing);
    await tester.tap(find.text('Ver video'));
    await tester.pump();
    expect(find.text('Ocultar video'), findsOneWidget);
    expect(find.text('Abrir video'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(2));

    await tester.enterText(
      find.widgetWithText(TextField, 'Buscar en enunciados y opciones'),
      'CODIGO',
    );
    await tester.pump();
    expect(find.text('1 pregunta'), findsOneWidget);
    expect(find.text('Pago en OXXO'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Buscar en enunciados y opciones'),
      'nada parecido',
    );
    await tester.pump();
    expect(find.text('No hay preguntas con estos filtros'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('admin edits a question and the row is replaced by the reply', (
    tester,
  ) async {
    final auth = await _signIn(tester, 'administrador', [
      'courses.view',
      'courses.manage',
      'courses.progress.view',
      'users.manage',
    ]);
    await _openBank(tester, auth);

    expect(find.text('Editar'), findsNWidgets(2));
    await tester.tap(find.text('Editar').first);
    await _settle(tester);
    expect(find.text('Editar pregunta'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, '¿Qué validación aplica?'),
      'Enunciado corregido',
    );
    await tester.pump();
    await tester.tap(find.text('Guardar pregunta'));
    await _settle(tester);

    expect(_puts.keys, ['/api/questions/1']);
    final body = _puts.values.single;
    expect(body['prompt'], 'Enunciado corregido');
    expect((body['options'] as List).map((option) => option['id']), [10, 11]);

    expect(find.text('Editar pregunta'), findsNothing);
    expect(find.text('Pregunta actualizada'), findsOneWidget);
    expect(find.text('Enunciado corregido'), findsOneWidget);
    expect(find.text('¿Qué validación aplica?'), findsNothing);
    expect(find.text('2 preguntas'), findsOneWidget);

    // Editing again targets the new id returned by the server.
    await tester.tap(find.text('Editar').first);
    await _settle(tester);
    await tester.tap(find.text('Guardar pregunta'));
    await _settle(tester);
    expect(_puts.keys, contains('/api/questions/99'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('admin is asked before discarding question changes', (
    tester,
  ) async {
    final auth = await _signIn(tester, 'administrador', [
      'courses.view',
      'courses.manage',
    ]);
    await _openBank(tester, auth);

    await tester.tap(find.text('Editar').first);
    await _settle(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, '¿Qué validación aplica?'),
      'Cambio',
    );
    await tester.pump();
    await tester.tap(find.text('Cancelar').last);
    await _settle(tester);
    expect(find.text('¿Descartar los cambios?'), findsOneWidget);
    await tester.tap(find.text('Descartar'));
    await _settle(tester);
    expect(find.text('Editar pregunta'), findsNothing);
    expect(_puts, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('"Ir al curso" switches to Cursos', (tester) async {
    final auth = await _signIn(tester, 'supervisor', ['courses.view']);
    await _openBank(tester, auth);

    await tester.tap(find.text('Ir al curso').first);
    await _settle(tester);
    expect(find.text('Catálogo de cursos'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'admin creates questions and "Guardar y agregar otra" keeps the lesson',
    (tester) async {
      final auth = await _signIn(tester, 'administrador', [
        'courses.view',
        'courses.manage',
      ]);
      await _openBank(tester, auth);

      await tester.tap(find.text('Nueva pregunta'));
      await _settle(tester);
      expect(find.text('Guardar y agregar otra'), findsOneWidget);

      // Lesson is required.
      await tester.tap(find.text('Guardar pregunta'));
      await _settle(tester);
      expect(find.text('Elige el curso y la lección.'), findsWidgets);
      expect(_posts, isEmpty);

      await tester.tap(
        find.widgetWithText(DropdownButtonFormField<int>, 'Curso'),
      );
      await _settle(tester);
      await tester.tap(find.text('Ruta Ofertas').last);
      await _settle(tester);
      await tester.tap(
        find.widgetWithText(DropdownButtonFormField<int>, 'Lección'),
      );
      await _settle(tester);
      await tester.tap(find.text('Lección 2: Transferencias').last);
      await _settle(tester);

      // Fields in the card: video link, question text, option 1, option 2.
    final fields = find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(TextFormField),
      );
      await tester.enterText(fields.at(1), 'Pregunta nueva');
      await tester.enterText(fields.at(2), 'Sí');
      await tester.enterText(fields.at(3), 'No');
      await tester.pump();
      await tester.tap(find.text('Guardar y agregar otra'));
      await _settle(tester);

      expect(_posts, hasLength(1));
      expect(_posts.single['lesson_id'], 10);
      expect(_posts.single['prompt'], 'Pregunta nueva');
      expect(
        (_posts.single['options'] as List).map((option) => option['label']),
        ['Sí', 'No'],
      );
      expect(
        find.text('Pregunta agregada al banco de «Lección 2: Transferencias»'),
        findsOneWidget,
      );

      // Dialog stays open with the same lesson and an empty question.
      expect(find.text('Nueva pregunta'), findsWidgets);
      expect(find.text('Lección 2: Transferencias'), findsOneWidget);
      expect(tester.widget<TextFormField>(fields.at(1)).initialValue, '');

      await tester.tap(find.text('Cancelar').last);
      await _settle(tester);
      expect(find.text('Guardar y agregar otra'), findsNothing);
      expect(find.text('3 preguntas'), findsOneWidget);
      expect(find.text('Pregunta nueva'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('without courses the button explains what to do', (tester) async {
    _courses = [];
    final auth = await _signIn(tester, 'administrador', [
      'courses.view',
      'courses.manage',
    ]);
    await _openBank(tester, auth);

    await tester.tap(find.text('Nueva pregunta'));
    await _settle(tester);
    expect(
      find.text('Primero crea un curso con al menos una lección en Cursos.'),
      findsOneWidget,
    );
    expect(find.text('Guardar y agregar otra'), findsNothing);
  });
}
