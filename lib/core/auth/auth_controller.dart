import 'package:flutter/foundation.dart';
import 'package:hercules_control/core/api/api_client.dart';
import 'package:hercules_control/core/auth/current_user.dart';
import 'package:hercules_control/core/auth/token_storage.dart';

enum AuthStatus { restoring, signedOut, signedIn }

/// Holds the session (token + current user) and exposes permission checks.
class AuthController extends ChangeNotifier {
  AuthController({required this.api, TokenStorage? storage})
    : _storage = storage ?? TokenStorage() {
    api.onUnauthorized = _handleUnauthorized;
  }

  final ApiClient api;
  final TokenStorage _storage;

  AuthStatus _status = AuthStatus.restoring;
  CurrentUser? _user;
  String? _sessionMessage;

  AuthStatus get status => _status;
  CurrentUser? get user => _user;
  bool get isSignedIn => _status == AuthStatus.signedIn && _user != null;

  /// Message to show on the login page (for example, an expired session).
  String? get sessionMessage => _sessionMessage;

  bool can(String permission) => _user?.can(permission) ?? false;

  /// Restores a persisted token, validating it against `/auth/me`.
  Future<void> restore() async {
    final token = _storage.read();
    if (token == null || token.isEmpty) {
      _setSignedOut();
      return;
    }
    api.token = token;
    try {
      await _loadUser();
    } on ApiException catch (error) {
      _setSignedOut(
        message: error.isUnauthorized
            ? null
            : 'No se pudo validar la sesión: ${error.message}',
      );
    }
  }

  /// Signs in. Throws [ApiException] with a friendly message on failure.
  Future<void> login(String username, String password) async {
    dynamic response;
    try {
      response = await api.postForm('/auth/token', {
        'username': username.trim(),
        'password': password,
      });
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        throw const ApiException(401, 'Usuario o contraseña incorrectos.');
      }
      rethrow;
    }

    final token = (response as Map<String, dynamic>)['access_token'] as String;
    api.token = token;
    try {
      await _loadUser();
    } catch (_) {
      api.token = null;
      rethrow;
    }
    _storage.write(token);
  }

  Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    // The server answers with ready-to-show Spanish messages.
    await api.post(
      '/auth/change-password',
      body: {'current_password': currentPassword, 'new_password': newPassword},
    );
  }

  void logout() => _setSignedOut();

  Future<void> _loadUser() async {
    final json = await api.get('/auth/me') as Map<String, dynamic>;
    _user = CurrentUser.fromJson(json);
    _status = AuthStatus.signedIn;
    _sessionMessage = null;
    notifyListeners();
  }

  void _handleUnauthorized() {
    if (_status != AuthStatus.signedIn) return;
    _setSignedOut(message: 'Tu sesión expiró. Vuelve a iniciar sesión.');
  }

  void _setSignedOut({String? message}) {
    _storage.clear();
    api.token = null;
    _user = null;
    _status = AuthStatus.signedOut;
    _sessionMessage = message;
    notifyListeners();
  }
}
