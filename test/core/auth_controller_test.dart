import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hercules_control/core/api/api_client.dart';
import 'package:hercules_control/core/auth/auth_controller.dart';
import 'package:hercules_control/core/auth/current_user.dart';
import 'package:hercules_control/core/auth/token_storage_memory.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  late List<http.Request> requests;
  late bool meUnauthorized;

  AuthController buildController() {
    final client = MockClient((request) async {
      requests.add(request);
      if (request.url.path.endsWith('/auth/token')) {
        if (request.bodyFields['password'] != 'secreto123') {
          return _json({'detail': 'Usuario o contraseña incorrectos.'}, 401);
        }
        return _json({'access_token': 'abc', 'token_type': 'bearer'});
      }
      if (request.url.path.endsWith('/auth/me')) {
        if (meUnauthorized) return _json({'detail': 'expired'}, 401);
        return _json({
          'id': 1,
          'username': 'ana',
          'full_name': 'Ana Pérez',
          'role': 'alumno',
          'store_code': 'Mexi',
          'permissions': ['courses.take'],
        });
      }
      return _json({'detail': 'Not found'}, 404);
    });
    return AuthController(
      api: ApiClient(baseUrl: 'http://api.test/api', httpClient: client),
      storage: TokenStorage(),
    );
  }

  setUp(() {
    requests = [];
    meUnauthorized = false;
  });

  test('wrong credentials raise the Spanish message', () async {
    final auth = buildController();
    await auth.restore();

    expect(
      () => auth.login('ana', 'mala'),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          'Usuario o contraseña incorrectos.',
        ),
      ),
    );
  });

  test('login loads the user and sends the bearer token', () async {
    final auth = buildController();
    await auth.restore();
    await auth.login('ana', 'secreto123');

    expect(auth.isSignedIn, isTrue);
    expect(auth.user!.roleName, 'Alumno/Cobrador');
    expect(auth.can(Permissions.coursesTake), isTrue);
    expect(auth.can(Permissions.coursesView), isFalse);
    expect(requests.first.headers['content-type'], contains('form-urlencoded'));
    expect(requests.last.headers['authorization'], 'Bearer abc');
  });

  test('a 401 on an authenticated call signs the user out', () async {
    final auth = buildController();
    await auth.restore();
    await auth.login('ana', 'secreto123');

    meUnauthorized = true;
    await expectLater(auth.api.get('/auth/me'), throwsA(isA<ApiException>()));

    expect(auth.status, AuthStatus.signedOut);
    expect(auth.sessionMessage, contains('sesión expiró'));
    expect(auth.api.token, isNull);
  });
}
