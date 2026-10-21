import 'package:campus_innovate/features/listings/domain/models/listing_role.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cada rol tiene su etiqueta en español', () {
    expect(ListingRole.leader.label, 'Líder');
    expect(ListingRole.member.label, 'Integrante');
    expect(ListingRole.mentor.label, 'Mentor');
  });

  test('líder e integrante trabajan el tablero; el mentor solo lo lee', () {
    expect(ListingRole.leader.canWorkTasks, isTrue);
    expect(ListingRole.member.canWorkTasks, isTrue);
    expect(ListingRole.mentor.canWorkTasks, isFalse);
  });

  group('fromName', () {
    test('lee de vuelta el nombre que se guarda en la columna', () {
      for (final role in ListingRole.values) {
        expect(ListingRole.fromName(role.name), role);
      }
    });

    test('una fila sin rol devuelve null y decide quien llama', () {
      // Not a default role: `Listing.team` needs to tell an old row apart from
      // an explicit "member" to know whether the creator still leads.
      expect(ListingRole.fromName(null), isNull);
      expect(ListingRole.fromName(''), isNull);
    });

    test('un valor desconocido también es null', () {
      expect(ListingRole.fromName('owner'), isNull);
      expect(ListingRole.fromName('Leader'), isNull);
    });
  });
}
