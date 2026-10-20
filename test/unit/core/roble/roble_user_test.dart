import 'package:campus_innovate/core/roble/roble_user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RobleUser.fromJson', () {
    test('lee la forma de GET /me', () {
      final user = RobleUser.fromJson({
        'id': 'row-1',
        'userId': 'uuid-1',
        'email': 'leonel@uninorte.edu.co',
        'name': 'Leonel Triana',
        'extra': {'role': 'student'},
      });

      expect(user.id, 'uuid-1');
      expect(user.email, 'leonel@uninorte.edu.co');
      expect(user.name, 'Leonel Triana');
    });

    test('userId gana sobre id, e id sobre sub', () {
      expect(RobleUser.fromJson({'userId': 'a', 'id': 'b', 'sub': 'c'}).id, 'a');
      expect(RobleUser.fromJson({'id': 'b', 'sub': 'c'}).id, 'b');
      expect(RobleUser.fromJson({'sub': 'c'}).id, 'c');
    });

    test('un id numérico se convierte a texto', () {
      expect(RobleUser.fromJson({'id': 42}).id, '42');
    });

    test('sin id es un error de formato', () {
      expect(
        () => RobleUser.fromJson({'email': 'x@y.co'}),
        throwsFormatException,
      );
      expect(() => RobleUser.fromJson({'userId': ''}), throwsFormatException);
    });

    test('sin nombre usa la parte local del correo', () {
      final user = RobleUser.fromJson({
        'userId': 'u',
        'email': 'mariana.ospina@uninorte.edu.co',
        'name': '   ',
      });

      expect(user.name, 'mariana.ospina');
    });

    test('sin nombre ni correo saluda como Estudiante', () {
      final user = RobleUser.fromJson({'userId': 'u'});

      expect(user.name, 'Estudiante');
      expect(user.email, '');
    });

    test('recorta los espacios del nombre', () {
      expect(
        RobleUser.fromJson({'userId': 'u', 'name': '  Ana  '}).name,
        'Ana',
      );
    });
  });

  group('caché', () {
    test('toCache y fromCache conservan el usuario', () {
      const user = RobleUser(
        id: 'uuid-1',
        email: 'leonel@uninorte.edu.co',
        name: 'Leonel Triana',
      );

      final restored = RobleUser.fromCache(user.toCache());

      expect(restored.id, user.id);
      expect(restored.email, user.email);
      expect(restored.name, user.name);
    });

    test('un texto que no es JSON es un error de formato', () {
      expect(() => RobleUser.fromCache('{roto'), throwsFormatException);
    });
  });

  test('firstName es la primera palabra del nombre', () {
    const user = RobleUser(id: 'u', email: '', name: 'Leonel Triana Ruiz');
    expect(user.firstName, 'Leonel');

    const single = RobleUser(id: 'u', email: '', name: 'Leonel');
    expect(single.firstName, 'Leonel');
  });
}
