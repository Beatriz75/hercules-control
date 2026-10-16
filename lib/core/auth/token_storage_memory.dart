/// Non-web fallback: keeps the token only while the app is running.
class TokenStorage {
  String? _token;

  String? read() => _token;

  void write(String token) => _token = token;

  void clear() => _token = null;
}
