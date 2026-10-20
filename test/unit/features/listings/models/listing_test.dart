import 'package:campus_innovate/features/listings/domain/models/listing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Listing listing({int maxMembers = 3, List<String>? memberIds}) => Listing(
        id: 'listing_1',
        title: 'Campus App',
        description: 'Una app',
        category: 'Tecnología',
        creatorId: 'user_1',
        creatorName: 'Leonel',
        maxMembers: maxMembers,
        requiredSkills: const ['Flutter'],
        memberIds: memberIds ?? const ['user_1'],
      );

  group('Listing.draft', () {
    test('nace sin id, con el creador como primer integrante', () {
      final draft = Listing.draft(
        title: 'Huerta',
        description: 'Cultivar',
        category: 'Sostenibilidad',
        creatorId: 'user_7',
        creatorName: 'Mariana',
        maxMembers: 4,
        requiredSkills: const ['Biología'],
        groupId: 'group_1',
        groupName: 'Innovación UN',
      );

      expect(draft.id, isEmpty);
      expect(draft.isPersisted, isFalse);
      expect(draft.memberIds, ['user_7']);
      expect(draft.availableSlots, 3);
      expect(draft.groupId, 'group_1');
      expect(draft.groupName, 'Innovación UN');
      expect(draft.belongsToGroup, isTrue);
    });

    test('sin grupo queda como proyecto previo a los grupos', () {
      final draft = Listing.draft(
        title: 't',
        description: 'd',
        category: 'c',
        creatorId: 'u',
        creatorName: 'n',
        maxMembers: 2,
        requiredSkills: const [],
      );

      expect(draft.belongsToGroup, isFalse);
      expect(draft.groupName, isEmpty);
    });
  });

  group('cupos', () {
    test('cuenta los cupos que quedan', () {
      expect(listing(maxMembers: 3).availableSlots, 2);
      expect(listing(maxMembers: 3).isFull, isFalse);
    });

    test('lleno exactamente al llegar al máximo', () {
      final full = listing(maxMembers: 2, memberIds: ['a', 'b']);

      expect(full.availableSlots, 0);
      expect(full.isFull, isTrue);
    });

    test('con más integrantes que el máximo sigue contando como lleno', () {
      // A row edited by hand in ROBLE can overshoot; it must not reopen.
      final over = listing(maxMembers: 1, memberIds: ['a', 'b']);

      expect(over.availableSlots, -1);
      expect(over.isFull, isTrue);
    });
  });

  test('isPersisted depende solo de tener id', () {
    expect(listing().isPersisted, isTrue);
    expect(listing().copyWith(id: '').isPersisted, isFalse);
  });

  group('copyWith', () {
    test('cambia solo lo que se le pasa', () {
      final original = listing();
      final copy = original.copyWith(title: 'Otro', memberIds: ['x', 'y']);

      expect(copy.title, 'Otro');
      expect(copy.memberIds, ['x', 'y']);
      expect(copy.id, original.id);
      expect(copy.description, original.description);
      expect(copy.category, original.category);
      expect(copy.creatorId, original.creatorId);
      expect(copy.creatorName, original.creatorName);
      expect(copy.maxMembers, original.maxMembers);
      expect(copy.requiredSkills, original.requiredSkills);
      expect(copy.groupId, original.groupId);
    });

    test('puede asignar grupo a un proyecto que no tenía', () {
      final copy = listing().copyWith(groupId: 'g', groupName: 'G');

      expect(copy.belongsToGroup, isTrue);
      expect(copy.groupName, 'G');
    });
  });
}
