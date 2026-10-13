import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:hercules_control/core/api/api_exception.dart';

export 'package:hercules_control/core/api/api_exception.dart';

const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '/api');

/// Thin JSON client over package:http for the Hercules Control API.
class ApiClient {
  ApiClient({
    String baseUrl = apiBaseUrl,
    http.Client? httpClient,
    this.onUnauthorized,
  }) : _baseUrl = baseUrl.endsWith('/')
           ? baseUrl.substring(0, baseUrl.length - 1)
           : baseUrl,
       _http = httpClient ?? http.Client();

  final String _baseUrl;
  final http.Client _http;

  /// Called when an authenticated request answers 401.
  void Function()? onUnauthorized;

  String? token;

  Uri uri(String path, [Map<String, String>? query]) {
    final normalized = path.startsWith('/') ? path : '/$path';
    final base = Uri.base;
    final raw = '$_baseUrl$normalized';
    final parsed = raw.startsWith('http://') || raw.startsWith('https://')
        ? Uri.parse(raw)
        : base.resolve(raw);
    return query == null || query.isEmpty
        ? parsed
        : parsed.replace(queryParameters: query);
  }

  Map<String, String> _headers({bool json = false}) => {
    'Accept': 'application/json',
    if (json) 'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };

  Future<dynamic> get(String path, {Map<String, String>? query}) =>
      _send(() => _http.get(uri(path, query), headers: _headers()));

  Future<dynamic> post(String path, {Object? body}) => _send(
    () => _http.post(
      uri(path),
      headers: _headers(json: true),
      body: body == null ? null : jsonEncode(body),
    ),
  );

  Future<dynamic> put(String path, {Object? body}) => _send(
    () => _http.put(
      uri(path),
      headers: _headers(json: true),
      body: body == null ? null : jsonEncode(body),
    ),
  );

  Future<dynamic> patch(String path, {Object? body}) => _send(
    () => _http.patch(
      uri(path),
      headers: _headers(json: body != null),
      body: body == null ? null : jsonEncode(body),
    ),
  );

  /// Posts an `application/x-www-form-urlencoded` body (used by /auth/token).
  Future<dynamic> postForm(String path, Map<String, String> fields) => _send(
    () => _http.post(
      uri(path),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: fields,
    ),
    notifyUnauthorized: false,
  );

  Future<dynamic> _send(
    Future<http.Response> Function() request, {
    bool notifyUnauthorized = true,
  }) async {
    http.Response response;
    try {
      response = await request();
    } catch (_) {
      throw ApiException(0, ApiException.defaultMessage(0));
    }

    final body = utf8.decode(response.bodyBytes);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (body.trim().isEmpty) return null;
      try {
        return jsonDecode(body);
      } on FormatException {
        return body;
      }
    }

    if (response.statusCode == 401 && notifyUnauthorized && token != null) {
      onUnauthorized?.call();
    }
    throw ApiException.fromResponse(response.statusCode, body);
  }

  void close() => _http.close();
}
