import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hercules_control/core/api/api_exception.dart';

void main() {
  test('uses a string detail as message', () {
    final error = ApiException.fromResponse(
      400,
      jsonEncode({
        'detail': 'No puedes quitarte tu propio acceso de administrador.',
      }),
    );

    expect(error.statusCode, 400);
    expect(
      error.message,
      'No puedes quitarte tu propio acceso de administrador.',
    );
  });

  test('shows only the Spanish msg of validation errors, deduplicated', () {
    final error = ApiException.fromResponse(
      422,
      jsonEncode({
        'detail': [
          {
            'type': 'string_too_short',
            'loc': ['body', 'lessons', 0, 'title'],
            'msg': 'El título de la lección es obligatorio.',
          },
          {
            'type': 'value_error',
            'loc': ['body'],
            'msg': 'Value error, Elige al menos una tienda.',
          },
          {
            'type': 'string_too_short',
            'loc': ['body', 'lessons', 1, 'title'],
            'msg': 'El título de la lección es obligatorio.',
          },
        ],
      }),
    );

    expect(error.statusCode, 422);
    expect(
      error.message,
      'El título de la lección es obligatorio.\nElige al menos una tienda.',
    );
  });

  test('network failures get the connection message', () {
    expect(
      ApiException.defaultMessage(0),
      'No se pudo conectar con el servidor. Revisa tu conexión e intenta de nuevo.',
    );
  });

  test('falls back to a Spanish message for empty or non-JSON bodies', () {
    expect(
      ApiException.fromResponse(500, '<html>Bad gateway</html>').message,
      ApiException.defaultMessage(500),
    );
    expect(
      ApiException.fromResponse(403, '').message,
      'No tienes permiso para realizar esta acción.',
    );
    expect(
      ApiException.fromResponse(404, jsonEncode({'detail': []})).message,
      ApiException.defaultMessage(404),
    );
  });

  test('flags unauthorized and forbidden responses', () {
    expect(const ApiException(401, 'x').isUnauthorized, isTrue);
    expect(const ApiException(403, 'x').isForbidden, isTrue);
    expect(const ApiException(422, 'x').isUnauthorized, isFalse);
  });
}
