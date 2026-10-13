import 'dart:convert';

/// Error returned by the Hercules Control API.
class ApiException implements Exception {
  const ApiException(this.statusCode, this.message);

  /// HTTP status code, or 0 when the request never reached the server.
  final int statusCode;
  final String message;

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;

  /// Builds an exception from a FastAPI error body.
  ///
  /// FastAPI answers with `{"detail": "text"}` for HTTPException and with
  /// `{"detail": [{"loc": [...], "msg": "..."}]}` for validation errors.
  factory ApiException.fromResponse(int statusCode, String body) {
    return ApiException(statusCode, parseDetail(statusCode, body));
  }

  static String parseDetail(int statusCode, String body) {
    final fallback = defaultMessage(statusCode);
    if (body.trim().isEmpty) return fallback;

    Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      return fallback;
    }

    if (decoded is! Map<String, dynamic>) return fallback;
    final detail = decoded['detail'];

    if (detail is String && detail.trim().isNotEmpty) return detail.trim();
    if (detail is List) {
      // FastAPI validation errors: the backend already writes `msg` as a
      // user-ready Spanish sentence, so only the messages are shown.
      final messages = <String>{};
      for (final item in detail) {
        final raw = item is Map ? item['msg']?.toString() : item?.toString();
        final msg = _cleanMessage(raw ?? '');
        if (msg.isNotEmpty) messages.add(msg);
      }
      if (messages.isNotEmpty) return messages.join('\n');
    }
    return fallback;
  }

  /// Removes the "Value error, " prefix Pydantic adds to custom validators.
  static String _cleanMessage(String message) {
    var text = message.trim();
    const prefix = 'Value error, ';
    if (text.startsWith(prefix)) text = text.substring(prefix.length).trim();
    return text;
  }

  static String defaultMessage(int statusCode) {
    return switch (statusCode) {
      0 =>
        'No se pudo conectar con el servidor. Revisa tu conexión e intenta de nuevo.',
      400 => 'La solicitud no es válida.',
      401 => 'Tu sesión expiró. Vuelve a iniciar sesión.',
      403 => 'No tienes permiso para realizar esta acción.',
      404 => 'No se encontró el recurso solicitado.',
      409 => 'La operación no se puede completar en este momento.',
      422 => 'Hay datos inválidos en el formulario.',
      >= 500 => 'Error del servidor. Intenta de nuevo en unos minutos.',
      _ => 'Ocurrió un error inesperado ($statusCode).',
    };
  }

  @override
  String toString() => 'ApiException($statusCode): $message';
}
