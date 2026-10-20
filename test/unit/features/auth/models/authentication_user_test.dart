import 'package:campus_innovate/features/auth/domain/models/authentication_user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sin contraseña explícita queda vacía', () {
    const user = AuthenticationUser(email: 'a@b.co', name: 'Ana');

    expect(user.password, isEmpty);
    expect(user.id, isNull);
  });

  test('fromJson lee id, correo y nombre', () {
    final user = AuthenticationUser.fromJson({
      'id': 'uuid-1',
      'email': 'leonel@uninorte.edu.co',
      'name': 'Leonel',
    });

    expect(user.id, 'uuid-1');
    expect(user.email, 'leonel@uninorte.edu.co');
    expect(user.name, 'Leonel');
    expect(user.password, isEmpty);
  });

  test('fromJson tolera campos ausentes y convierte el id a texto', () {
    final user = AuthenticationUser.fromJson({'id': 7});

    expect(user.id, '7');
    expect(user.email, '');
    expect(user.name, '');
    expect(AuthenticationUser.fromJson(const {}).id, isNull);
  });

  test('fromJson nunca lee una contraseña aunque venga', () {
    final user = AuthenticationUser.fromJson({
      'email': 'a@b.co',
      'name': 'Ana',
      'password': 'secreta',
    });

    expect(user.password, isEmpty);
  });

  test('toJson nunca incluye la contraseña', () {
    const user = AuthenticationUser(
      id: 'u',
      email: 'a@b.co',
      name: 'Ana',
      password: 'Campus2026!',
    );

    final json = user.toJson();

    expect(json, {'id': 'u', 'email': 'a@b.co', 'name': 'Ana'});
    expect(json.values, isNot(contains('Campus2026!')));
  });

  test('toJson y fromJson van de ida y vuelta', () {
    const user = AuthenticationUser(id: 'u', email: 'a@b.co', name: 'Ana');
    final restored = AuthenticationUser.fromJson(user.toJson());

    expect(restored.id, user.id);
    expect(restored.email, user.email);
    expect(restored.name, user.name);
  });
}
