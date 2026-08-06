import 'package:flutter_test/flutter_test.dart';
import 'package:hercules_control/app/navigation/app_route.dart';

void main() {
  test('defines one base route for each approved module', () {
    expect(appRoutes, hasLength(8));
    expect(
      appRoutes.map((route) => route.path),
      containsAllInOrder([
        '/dashboard',
        '/employees',
        '/candidates',
        '/audits',
        '/performance',
        '/reports',
        '/whatsapp-lines',
        '/settings',
      ]),
    );
  });

  test('requires a permission for every route', () {
    expect(
      appRoutes.map((route) => route.requiredPermission),
      everyElement(isNotEmpty),
    );
  });

  test('does not define routes for excluded modules', () {
    final paths = appRoutes.map((route) => route.path).join(' ');
    final labels = appRoutes.map((route) => route.label).join(' ');
    final permissions = appRoutes
        .map((route) => route.requiredPermission)
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
