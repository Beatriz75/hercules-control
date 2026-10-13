import 'package:flutter_test/flutter_test.dart';
import 'package:hercules_control/core/auth/current_user.dart';
import 'package:hercules_control/features/users/presentation/user_validators.dart';

void main() {
  test('username: required, allowed characters and 3-60 length', () {
    expect(validateUsername(''), 'El usuario es obligatorio.');
    expect(
      validateUsername('josé'),
      'Solo letras, números, punto, guion y guion bajo; sin espacios ni acentos.',
    );
    expect(validateUsername('ana perez'), isNotNull);
    expect(
      validateUsername('ab'),
      'El usuario debe tener entre 3 y 60 caracteres.',
    );
    expect(validateUsername('a' * 61), isNotNull);
    expect(validateUsername('  ana.perez-01_x  '), isNull);
  });

  test('full name: required, max 120', () {
    expect(validateFullName('   '), 'El nombre es obligatorio.');
    expect(validateFullName('x' * 121), isNotNull);
    expect(validateFullName('Ana Pérez'), isNull);
  });

  test('password: min 8 and confirmation must match', () {
    expect(validatePassword(''), 'La contraseña es obligatoria.');
    expect(
      validatePassword('1234567'),
      'La contraseña debe tener al menos 8 caracteres.',
    );
    expect(validatePassword('12345678'), isNull);
    expect(
      validatePasswordConfirmation('abc', 'abcdefgh'),
      'Las contraseñas no coinciden.',
    );
    expect(validatePasswordConfirmation('abcdefgh', 'abcdefgh'), isNull);
  });

  test('store is required only for alumno', () {
    expect(
      validateStore(UserRole.alumno, null),
      'La tienda es obligatoria para alumnos.',
    );
    expect(validateStore(UserRole.alumno, 'Mexi'), isNull);
    expect(validateStore(UserRole.supervisor, null), isNull);
  });
}
