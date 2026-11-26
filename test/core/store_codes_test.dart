import 'package:flutter_test/flutter_test.dart';
import 'package:hercules_control/core/auth/current_user.dart';

void main() {
  test('las tiendas disponibles incluyen Santiago', () {
    expect(storeCodes, ['Ofertas', 'Mexi', 'Santiago']);
  });
}
