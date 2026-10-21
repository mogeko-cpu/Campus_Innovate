import 'package:campus_innovate/features/listings/domain/models/listing_member.dart';
import 'package:campus_innovate/features/listings/domain/models/listing_role.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const ana = ListingMember(
    userId: 'user_1',
    userName: 'Ana Pérez',
    role: ListingRole.member,
  );

  test('guarda quién es, cómo se llama y qué rol tiene', () {
    expect(ana.userId, 'user_1');
    expect(ana.userName, 'Ana Pérez');
    expect(ana.role, ListingRole.member);
  });

  group('copyWith', () {
    test('cambia el rol y conserva a la persona', () {
      final mentor = ana.copyWith(role: ListingRole.mentor);

      expect(mentor.role, ListingRole.mentor);
      expect(mentor.userId, 'user_1');
      expect(mentor.userName, 'Ana Pérez');
    });

    test('cambia el nombre y conserva el rol', () {
      final renamed = ana.copyWith(userName: 'Ana P.');

      expect(renamed.userName, 'Ana P.');
      expect(renamed.role, ListingRole.member);
      expect(renamed.userId, 'user_1');
    });

    test('sin argumentos devuelve los mismos valores', () {
      final copy = ana.copyWith();

      expect(copy.userId, ana.userId);
      expect(copy.userName, ana.userName);
      expect(copy.role, ana.role);
    });

    test('no deja vaciar el nombre con null', () {
      expect(ana.copyWith(userName: null).userName, 'Ana Pérez');
    });
  });
}
