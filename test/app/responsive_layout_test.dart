import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hercules_control/app/navigation/app_shell.dart';
import 'package:hercules_control/core/api/api_client.dart';
import 'package:hercules_control/core/auth/auth_controller.dart';
import 'package:hercules_control/core/auth/auth_scope.dart';
import 'package:hercules_control/core/auth/token_storage_memory.dart';
import 'package:hercules_control/core/theme/app_theme.dart';
import 'package:hercules_control/features/auth/presentation/login_page.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../features/courses/question_bank_test.dart' show bankRowJson;

/// Phone used for every layout check (iPhone 12/13/14).
const _phone = Size(390, 844);
const _tablet = Size(768, 1024);

const _longCourse =
    'Ruta de cobranza Ofertas: validación de comprobantes y seguimiento';
const _longLesson =
    'Transferencias SPEI, depósitos en OXXO y comprobantes dudosos del cliente';

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, dynamic> _question(
  int lessonId,
  int index, {
  bool multiple = false,
}) => {
  'id': lessonId * 10 + index,
  'lesson_id': lessonId,
  'code': 'P${lessonId * 10 + index}',
  'prompt':
      '¿Qué haces si el cliente manda un comprobante de transferencia sin referencia ni clave de rastreo? ($index)',
  'question_type': 'text',
  'answer_mode': multiple ? 'multiple' : 'single',
  'image_url': null,
  'video_url': index == 1 ? 'https://youtu.be/dQw4w9WgXcQ' : null,
  'sort_order': index,
  'active': true,
  'options': [
    for (final option in [1, 2, 3])
      {
        'id': (lessonId * 10 + index) * 10 + option,
        'label':
            'Opción $option: pedir la clave de rastreo y validar en Banxico antes de marcar el pago',
        'media_url': null,
        'option_type': 'text',
        'is_correct': option == 1 || (multiple && option == 2),
        'sort_order': option,
      },
  ],
};

Map<String, dynamic> _lesson(int lessonId, {required bool student}) => {
  'id': lessonId,
  'course_id': 1,
  'title': '$_longLesson ($lessonId)',
  'summary': 'El alumno distingue un comprobante válido de uno dudoso.',
  'theory': 'Teoría larga de la lección. ' * 20,
  'required_approval_percent': 80,
  'sort_order': lessonId,
  'active': true,
  'theory_images': [],
  'theory_videos': [
    {'url': 'https://www.youtube.com/watch?v=dQw4w9WgXcQ', 'title': 'Clase'},
  ],
  if (student) ...{
    'question_bank_size': 3,
    'questions_per_attempt': 2,
  } else ...{
    'questions_per_attempt': 2,
    'questions': [
      for (final index in [1, 2, 3])
        _question(lessonId, index, multiple: index == 2),
    ],
  },
};

Map<String, dynamic> _course({required bool student}) => {
  'id': 1,
  'title': _longCourse,
  'description': 'Curso para cobradores nuevos de la tienda.',
  'status': 'active',
  'sort_order': 1,
  'active': true,
  'stores': [
    {'id': 1, 'store_code': 'Ofertas'},
    {'id': 2, 'store_code': 'Mexi'},
  ],
  'lessons': [
    for (final lessonId in [10, 11]) _lesson(lessonId, student: student),
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
        'username': 'beatriz.administradora',
        'full_name': 'Beatriz Administradora de Hércules Control',
        'role': role,
        'store_code': 'Ofertas',
        'permissions': permissions,
      });
    }
    if (path.endsWith('/training-attempts/start')) {
      return _json({
        'session_id': 1,
        'lesson_id': 10,
        'required_approval_percent': 80,
        'questions': [
          for (final index in [1, 2])
            {
              ..._question(10, index, multiple: index == 2),
              'options': [
                for (final option in _question(10, index)['options'] as List)
                  {...(option as Map<String, dynamic>)}..remove('is_correct'),
              ],
            },
        ],
      }, 201);
    }
    if (path.endsWith('/questions/similar')) return _json([]);
    if (path.endsWith('/questions')) {
      return _json([
        for (final id in [1, 2, 3])
          bankRowJson(
            id: id,
            code: 'P$id',
            prompt:
                '¿Cómo validas una transferencia SPEI que el cliente dice que ya pagó? ($id)',
            videoUrl: id == 1 ? 'https://youtu.be/dQw4w9WgXcQ' : null,
            stores: const ['Ofertas', 'Mexi'],
          ),
      ]);
    }
    if (path.endsWith('/courses/assigned')) {
      return _json([_course(student: true)]);
    }
    if (path.endsWith('/courses/progress')) {
      return _json([
        for (final name in ['Ana', 'Luis'])
          {
            'username': name.toLowerCase(),
            'full_name': '$name Pérez de la Cobranza',
            'store_code': 'Ofertas',
            'course_id': 1,
            'course_title': _longCourse,
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
          'practice_approved': false,
          'best_score_percent': 50.0,
          'completed_at': null,
          'updated_at': '2026-10-12T15:30:00',
        },
      ]);
    }
    if (path.endsWith('/users')) {
      return _json([
        for (final id in [1, 2, 3])
          {
            'id': id,
            'username': 'usuario.de.prueba.$id',
            'full_name': 'Nombre Completo Bastante Largo $id',
            'role': id == 1 ? 'administrador' : 'alumno',
            'store_code': id == 1 ? null : 'Ofertas',
            'active': id != 3,
            'created_at': '2026-10-01T10:00:00',
          },
      ]);
    }
    return _json({'detail': 'No encontrado.'}, 404);
  });
  final auth = AuthController(
    api: ApiClient(baseUrl: 'http://api.test/api', httpClient: client),
    storage: TokenStorage(),
  );
  await tester.runAsync(() => auth.login('u', 'secreto123'));
  return auth;
}

const _adminPermissions = [
  'courses.view',
  'courses.manage',
  'courses.progress.view',
  'users.manage',
];

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void _useSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _pumpShell(
  WidgetTester tester,
  AuthController auth, {
  Size size = _phone,
}) async {
  _useSize(tester, size);
  await tester.pumpWidget(
    AuthScope(
      controller: auth,
      child: MaterialApp(theme: AppTheme.light(), home: const AppShell()),
    ),
  );
  await _settle(tester);
}

/// Opens the drawer and goes to [label].
Future<void> _goTo(WidgetTester tester, String label) async {
  await tester.tap(find.byIcon(Icons.menu));
  await _settle(tester);
  await tester.tap(
    find.descendant(of: find.byType(Drawer), matching: find.text(label)),
  );
  await _settle(tester);
}

/// Scrolls [finder] to the middle of the screen (clear of sticky headers)
/// and taps it.
Future<void> _tap(WidgetTester tester, Finder finder) async {
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
  await tester.pump();
  await tester.tap(finder);
  await _settle(tester);
}

void main() {
  testWidgets('login fits a phone without overflow', (tester) async {
    _useSize(tester, _phone);
    final auth = AuthController(
      api: ApiClient(
        baseUrl: 'http://api.test/api',
        httpClient: MockClient((_) async => _json({}, 401)),
      ),
      storage: TokenStorage(),
    );
    await tester.pumpWidget(
      AuthScope(
        controller: auth,
        child: MaterialApp(theme: AppTheme.light(), home: const LoginPage()),
      ),
    );
    await tester.pump();

    expect(find.text('Ingresar'), findsOneWidget);
    // Validation messages must not push the card out of the screen.
    await tester.tap(find.text('Ingresar'));
    await tester.pump();
    expect(find.text('El usuario es obligatorio.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone: the sidebar becomes a drawer with the user panel', (
    tester,
  ) async {
    final auth = await _signIn(tester, 'administrador', _adminPermissions);
    await _pumpShell(tester, auth);

    // No fixed sidebar: app bar with the hamburger button instead.
    expect(find.byTooltip('Contraer menú'), findsNothing);
    expect(find.byIcon(Icons.menu), findsOneWidget);
    expect(find.widgetWithText(AppBar, 'Cursos'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.menu));
    await _settle(tester);
    expect(find.byType(Drawer), findsOneWidget);
    expect(find.text('Banco de preguntas'), findsOneWidget);
    expect(
      find.text('Beatriz Administradora de Hércules Control'),
      findsOneWidget,
    );

    // Change password from the drawer.
    await tester.tap(find.byTooltip('Cambiar contraseña'));
    await _settle(tester);
    expect(find.text('Repite la nueva contraseña'), findsOneWidget);
    await tester.tap(find.text('Guardar'));
    await _settle(tester);
    expect(find.text('La contraseña actual es obligatoria.'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await _settle(tester);

    await tester.tap(find.text('Usuarios'));
    await _settle(tester);
    expect(find.byType(Drawer), findsNothing);
    expect(find.widgetWithText(AppBar, 'Usuarios'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tablet: the sidebar starts collapsed and can expand', (
    tester,
  ) async {
    final auth = await _signIn(tester, 'administrador', _adminPermissions);
    await _pumpShell(tester, auth, size: _tablet);

    expect(find.byIcon(Icons.menu), findsNothing);
    expect(find.byTooltip('Expandir menú'), findsOneWidget);
    await tester.tap(find.byTooltip('Expandir menú'));
    await _settle(tester);
    expect(find.byTooltip('Contraer menú'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone: Usuarios shows cards and one-column forms', (
    tester,
  ) async {
    final auth = await _signIn(tester, 'administrador', _adminPermissions);
    await _pumpShell(tester, auth);
    await _goTo(tester, 'Usuarios');

    expect(find.byType(DataTable), findsNothing);
    expect(find.text('Nombre Completo Bastante Largo 2'), findsOneWidget);
    expect(find.text('usuario.de.prueba.1 (tú)'), findsOneWidget);

    await _tap(tester, find.text('Nuevo usuario'));
    expect(find.text('Confirmar contraseña'), findsOneWidget);
    await tester.tap(find.text('Guardar'));
    await _settle(tester);
    await tester.tap(find.text('Cancelar'));
    await _settle(tester);

    await _tap(tester, find.byTooltip('Restablecer contraseña').first);
    expect(find.text('Restablecer'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await _settle(tester);

    await _tap(tester, find.byTooltip('Editar').first);
    expect(find.text('Editar usuario'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone: course catalog, preview, export and progress', (
    tester,
  ) async {
    final auth = await _signIn(tester, 'administrador', _adminPermissions);
    await _pumpShell(tester, auth);

    expect(find.text('Nuevo curso'), findsOneWidget);
    expect(find.text('Editar plantilla'), findsOneWidget);

    // Lesson preview (full screen on phones).
    await _tap(tester, find.textContaining('$_longLesson (10)').last);
    expect(find.text('Editar lección'), findsOneWidget);
    await _tap(tester, find.widgetWithText(OutlinedButton, 'Cerrar'));

    await _tap(tester, find.text('Exportar preguntas'));
    expect(find.text('Copiar export'), findsOneWidget);
    await _tap(tester, find.widgetWithText(OutlinedButton, 'Cerrar'));

    await tester.tap(find.text('Avance de alumnos'));
    await _settle(tester);
    expect(find.byType(DataTable), findsNothing);
    expect(find.text('Ana Pérez de la Cobranza (ana)'), findsOneWidget);
    expect(find.text('Preguntas más falladas'), findsOneWidget);
    expect(find.text('Ver intentos'), findsWidgets);
    // The second student's card is below the fold: scroll to it.
    await tester.drag(find.byType(ListView).last, const Offset(0, -300));
    await _settle(tester);
    expect(find.text('Luis Pérez de la Cobranza (luis)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone: course editor fills the screen without overflow', (
    tester,
  ) async {
    final auth = await _signIn(tester, 'administrador', _adminPermissions);
    await _pumpShell(tester, auth);

    await _tap(tester, find.text('Editar plantilla'));
    expect(find.text('Guardar curso'), findsOneWidget);
    final dialog = tester.getRect(find.byType(Dialog));
    expect(dialog.width, _phone.width);

    // Walk the whole form so every row is laid out.
    await _tap(tester, find.text('Agregar pregunta'));
    await _tap(tester, find.text('Guardar curso'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone: question bank and its editor', (tester) async {
    final auth = await _signIn(tester, 'administrador', _adminPermissions);
    await _pumpShell(tester, auth);
    await _goTo(tester, 'Banco de preguntas');

    expect(find.text('Nueva pregunta'), findsOneWidget);
    // The question list is lazy: scroll until the first card is built.
    await tester.dragUntilVisible(
      find.text('Ver video'),
      find.byType(CustomScrollView),
      const Offset(0, -200),
    );
    await _tap(tester, find.text('Ver video'));
    expect(find.text('Abrir video'), findsWidgets);

    await _tap(tester, find.widgetWithText(OutlinedButton, 'Editar').first);
    expect(find.text('Guardar pregunta'), findsOneWidget);
    expect(tester.getRect(find.byType(Dialog)).width, _phone.width);
    await _tap(tester, find.widgetWithText(OutlinedButton, 'Cancelar'));

    await _tap(tester, find.text('Nueva pregunta'));
    expect(find.text('Guardar y agregar otra'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone: student theory and practice', (tester) async {
    final auth = await _signIn(tester, 'alumno', ['courses.take']);
    await _pumpShell(tester, auth);

    expect(find.text('Mis cursos'), findsOneWidget);
    await _tap(tester, find.textContaining('$_longLesson (10)').last);
    expect(find.text('Marcar teoría como leída'), findsNothing);
    expect(find.text('Abrir video'), findsWidgets);
    await _tap(tester, find.widgetWithText(OutlinedButton, 'Cerrar'));

    await _tap(tester, find.text('Iniciar práctica'));
    expect(find.text('Pregunta 1 de 2'), findsOneWidget);
    expect(tester.getRect(find.byType(Dialog)).width, _phone.width);
    await _tap(tester, find.textContaining('Opción 1').first);
    await _tap(tester, find.text('Siguiente pregunta'));
    expect(find.text('Pregunta 2 de 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
