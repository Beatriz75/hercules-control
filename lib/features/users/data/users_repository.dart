import 'package:hercules_control/core/api/api_client.dart';

/// User row returned by `GET /users`.
class AppUser {
  const AppUser({
    required this.id,
    required this.username,
    required this.fullName,
    required this.role,
    required this.storeCode,
    required this.active,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as int,
      username: json['username'] as String,
      fullName: (json['full_name'] as String?) ?? '',
      role: json['role'] as String,
      storeCode: json['store_code'] as String?,
      active: (json['active'] as bool?) ?? true,
      createdAt: DateTime.tryParse('${json['created_at']}'),
      updatedAt: DateTime.tryParse('${json['updated_at']}'),
    );
  }

  final int id;
  final String username;
  final String fullName;
  final String role;
  final String? storeCode;
  final bool active;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}

class UsersRepository {
  const UsersRepository(this._api);

  final ApiClient _api;

  Future<List<AppUser>> fetchUsers() async {
    final json = await _api.get('/users') as List;
    return [
      for (final item in json) AppUser.fromJson(item as Map<String, dynamic>),
    ];
  }

  Future<AppUser> createUser({
    required String username,
    required String fullName,
    required String password,
    required String role,
    String? storeCode,
  }) async {
    final json = await _api.post(
      '/users',
      body: {
        'username': username.trim(),
        'full_name': fullName.trim(),
        'password': password,
        'role': role,
        'store_code': storeCode,
      },
    );
    return AppUser.fromJson(json as Map<String, dynamic>);
  }

  Future<AppUser> updateUser(
    int id, {
    String? fullName,
    String? role,
    String? storeCode,
    bool? active,
  }) async {
    final json = await _api.patch(
      '/users/$id',
      body: {
        'full_name': ?fullName?.trim(),
        'role': ?role,
        'store_code': storeCode,
        'active': ?active,
      },
    );
    return AppUser.fromJson(json as Map<String, dynamic>);
  }

  Future<void> resetPassword(int id, String password) async {
    await _api.post('/users/$id/password', body: {'password': password});
  }
}
