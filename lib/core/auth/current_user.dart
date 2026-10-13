/// Store codes available for courses and students.
const storeCodes = ['Ofertas', 'Mexi'];

/// Fixed roles defined by the backend.
enum UserRole {
  administrador('administrador', 'Administrador'),
  supervisor('supervisor', 'Supervisor'),
  auditor('auditor', 'Auditor'),
  consultaGerencial('consulta_gerencial', 'Consulta gerencial'),
  alumno('alumno', 'Alumno/Cobrador');

  const UserRole(this.code, this.label);

  final String code;
  final String label;

  static UserRole? fromCode(String? code) {
    for (final role in values) {
      if (role.code == code) return role;
    }
    return null;
  }
}

String roleLabel(String code) => UserRole.fromCode(code)?.label ?? code;

/// Permission codes used by the Flutter client.
abstract final class Permissions {
  static const coursesView = 'courses.view';
  static const coursesManage = 'courses.manage';
  static const coursesProgressView = 'courses.progress.view';
  static const coursesTake = 'courses.take';
  static const usersManage = 'users.manage';
}

/// User returned by `GET /auth/me`.
class CurrentUser {
  const CurrentUser({
    required this.id,
    required this.username,
    required this.fullName,
    required this.role,
    required this.storeCode,
    required this.permissions,
  });

  factory CurrentUser.fromJson(Map<String, dynamic> json) {
    return CurrentUser(
      id: json['id'] as int,
      username: json['username'] as String,
      fullName: (json['full_name'] as String?) ?? '',
      role: json['role'] as String,
      storeCode: json['store_code'] as String?,
      permissions: {
        for (final permission in (json['permissions'] as List? ?? const []))
          permission.toString(),
      },
    );
  }

  final int id;
  final String username;
  final String fullName;
  final String role;
  final String? storeCode;
  final Set<String> permissions;

  String get displayName => fullName.trim().isEmpty ? username : fullName;
  String get roleName => roleLabel(role);

  bool can(String permission) => permissions.contains(permission);
}
