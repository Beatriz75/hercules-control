import 'package:hercules_control/core/auth/current_user.dart';

final _usernamePattern = RegExp(r'^[A-Za-z0-9._-]+$');

String? validateUsername(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return 'El usuario es obligatorio.';
  if (!_usernamePattern.hasMatch(text)) {
    return 'Solo letras, números, punto, guion y guion bajo; sin espacios ni acentos.';
  }
  if (text.length < 3 || text.length > 60) {
    return 'El usuario debe tener entre 3 y 60 caracteres.';
  }
  return null;
}

String? validateFullName(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return 'El nombre es obligatorio.';
  if (text.length > 120) return 'El nombre admite máximo 120 caracteres.';
  return null;
}

String? validatePassword(String? value) {
  if (value == null || value.isEmpty) return 'La contraseña es obligatoria.';
  if (value.length < 8) {
    return 'La contraseña debe tener al menos 8 caracteres.';
  }
  return null;
}

String? validatePasswordConfirmation(String? value, String password) {
  if (value == null || value.isEmpty) return 'Repite la contraseña.';
  if (value != password) return 'Las contraseñas no coinciden.';
  return null;
}

String? validateStore(UserRole role, String? storeCode) {
  if (role == UserRole.alumno && (storeCode == null || storeCode.isEmpty)) {
    return 'La tienda es obligatoria para alumnos.';
  }
  return null;
}
