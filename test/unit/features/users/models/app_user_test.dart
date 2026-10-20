import 'package:campus_innovate/features/users/domain/models/app_user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('guarda el id de la cuenta, el nombre y el correo', () {
    const user = AppUser(
      id: 'uuid-1',
      name: 'Mariana Ospina',
      email: 'mariana@uninorte.edu.co',
    );

    expect(user.id, 'uuid-1');
    expect(user.name, 'Mariana Ospina');
    expect(user.email, 'mariana@uninorte.edu.co');
  });
}
