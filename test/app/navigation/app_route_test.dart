import 'package:flutter_test/flutter_test.dart';
import 'package:hercules_control/app/navigation/app_route.dart';
import 'package:hercules_control/app/navigation/app_section.dart';

// Permission sets as returned by GET /auth/me for each role.
const _admin = {
  'dashboard.view',
  'employees.view',
  'candidates.view',
  'audits.view',
  'audits.create',
  'audits.manage',
  'courses.view',
  'courses.manage',
  'courses.progress.view',
  'performance.view',
  'reports.view',
  'reports.create',
  'whatsapp-lines.view',
  'settings.view',
  'users.manage',
};
const _supervisor = {
  'dashboard.view',
  'employees.view',
  'candidates.view',
  'audits.view',
  'performance.view',
  'reports.view',
  'courses.view',
  'courses.progress.view',
};
const _auditor = {
  'dashboard.view',
  'audits.view',
  'audits.create',
  'performance.view',
  'reports.view',
  'reports.create',
};
const _consultaGerencial = {
  'dashboard.view',
  'performance.view',
  'reports.view',
  'courses.view',
  'courses.progress.view',
};
const _alumno = {'courses.take'};

List<AppSection> _sections(Set<String> permissions) =>
    visibleRoutesFor(permissions).map((route) => route.section).toList();

void main() {
  test('defines one base route for each approved module', () {
    expect(appRoutes, hasLength(11));
    expect(
      appRoutes.map((route) => route.path),
      containsAllInOrder([
        '/dashboard',
        '/employees',
        '/candidates',
        '/audits',
        '/courses',
        '/question-bank',
        '/performance',
        '/reports',
        '/whatsapp-lines',
        '/settings',
        '/users',
      ]),
    );
  });

  test('requires a permission for every route', () {
    expect(
      appRoutes.map((route) => route.requiredPermission),
      everyElement(isNotEmpty),
    );
  });

  test('only Cursos, Banco de preguntas and Usuarios are released', () {
    expect(
      appRoutes.where((route) => route.enabled).map((route) => route.section),
      [AppSection.courses, AppSection.questionBank, AppSection.users],
    );
  });

  test('administrator sees Cursos, Banco de preguntas and Usuarios', () {
    expect(_sections(_admin), [
      AppSection.courses,
      AppSection.questionBank,
      AppSection.users,
    ]);
  });

  test('supervisor and consulta gerencial see Cursos and the bank', () {
    expect(_sections(_supervisor), [
      AppSection.courses,
      AppSection.questionBank,
    ]);
    expect(_sections(_consultaGerencial), [
      AppSection.courses,
      AppSection.questionBank,
    ]);
  });

  test('question bank requires courses.view, not courses.take', () {
    final bank = appRoutes.firstWhere(
      (route) => route.section == AppSection.questionBank,
    );
    expect(bank.path, '/question-bank');
    expect(bank.acceptedPermissions, ['courses.view']);
  });

  test('alumno reaches Cursos through courses.take', () {
    expect(_sections(_alumno), [AppSection.courses]);
  });

  test('auditor has no released modules yet', () {
    expect(_sections(_auditor), isEmpty);
  });

  test('no permissions means no sections', () {
    expect(_sections(const {}), isEmpty);
  });

  test('does not define routes for excluded modules', () {
    final paths = appRoutes.map((route) => route.path).join(' ');
    final labels = appRoutes.map((route) => route.label).join(' ');
    final permissions = appRoutes
        .expand((route) => route.acceptedPermissions)
        .join(' ');
    final routeContract = '$paths $labels $permissions'.toLowerCase();

    expect(routeContract, isNot(contains('cobros')));
    expect(routeContract, isNot(contains('collections')));
    expect(routeContract, isNot(contains('deudas')));
    expect(routeContract, isNot(contains('debts')));
    expect(routeContract, isNot(contains('comprobantes')));
    expect(routeContract, isNot(contains('receipts')));
    expect(routeContract, isNot(contains('cuentas-autorizadas')));
    expect(routeContract, isNot(contains('authorized-accounts')));
    expect(routeContract, isNot(contains('pagos-empleados')));
    expect(routeContract, isNot(contains('employee-payments')));
    expect(routeContract, isNot(contains('usuarios-crm')));
    expect(routeContract, isNot(contains('crm-users')));
    expect(routeContract, isNot(contains('integraciones-bancarias')));
    expect(routeContract, isNot(contains('banking-integrations')));
    expect(routeContract, isNot(contains('spei')));
    expect(routeContract, isNot(contains('antifraude')));
    expect(routeContract, isNot(contains('financial-antifraud')));
  });
}
