import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hercules_control/core/api/api_client.dart';
import 'package:hercules_control/core/auth/auth_controller.dart';
import 'package:hercules_control/core/auth/auth_scope.dart';
import 'package:hercules_control/core/auth/token_storage_memory.dart';
import 'package:hercules_control/core/theme/app_theme.dart';
import 'package:hercules_control/core/widgets/brand_logo.dart';
import 'package:hercules_control/features/auth/presentation/login_page.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('brand palette drives the color scheme', () {
    final theme = AppTheme.light();

    expect(theme.colorScheme.primary, BrandColors.navy);
    expect(theme.colorScheme.secondary, BrandColors.gold);
    expect(theme.colorScheme.onSecondary, BrandColors.navy);
    expect(theme.colorScheme.tertiary, BrandColors.signalBlue);
    expect(theme.colorScheme.error, BrandColors.error);
    expect(theme.scaffoldBackgroundColor, BrandColors.background);

    // Primary CTAs: gold background with navy (not white) text.
    final filled = theme.filledButtonTheme.style!;
    expect(filled.backgroundColor!.resolve({}), BrandColors.gold);
    expect(filled.foregroundColor!.resolve({}), BrandColors.navy);
  });

  testWidgets('login shows the brand and validates required fields', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final auth = AuthController(
      api: ApiClient(
        baseUrl: 'http://api.test/api',
        httpClient: MockClient((_) async => http.Response('', 500)),
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

    expect(find.byType(BrandMark), findsOneWidget);
    expect(find.text('HÉRCULES'), findsOneWidget);
    expect(find.text('CONTROL'), findsOneWidget);

    await tester.tap(find.text('Ingresar'));
    await tester.pump();
    expect(find.text('El usuario es obligatorio.'), findsOneWidget);
    expect(find.text('La contraseña es obligatoria.'), findsOneWidget);

    await tester.tap(find.byTooltip('Mostrar contraseña'));
    await tester.pump();
    expect(find.byTooltip('Ocultar contraseña'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
