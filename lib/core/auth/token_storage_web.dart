import 'package:web/web.dart' as web;

const _tokenKey = 'hercules_control.access_token';

/// Persists the access token in the browser localStorage so a page refresh
/// keeps the session.
class TokenStorage {
  String? read() {
    try {
      return web.window.localStorage.getItem(_tokenKey);
    } catch (_) {
      return null;
    }
  }

  void write(String token) {
    try {
      web.window.localStorage.setItem(_tokenKey, token);
    } catch (_) {}
  }

  void clear() {
    try {
      web.window.localStorage.removeItem(_tokenKey);
    } catch (_) {}
  }
}
