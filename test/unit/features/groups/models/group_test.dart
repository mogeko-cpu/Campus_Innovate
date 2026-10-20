import 'package:campus_innovate/features/groups/domain/models/group.dart';
import 'package:campus_innovate/features/groups/domain/models/group_member.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const team = Group(
    id: 'group_1',
    name: 'Innovación UN',
    description: 'Concursos',
    ownerId: 'user_1',
    ownerName: 'Leonel',
    members: [
      GroupMember(groupId: 'group_1', userId: 'user_1', userName: 'Leonel'),
      GroupMember(groupId: 'group_1', userId: 'user_2', userName: 'Mariana'),
    ],
  );

  group('Group.draft', () {
    test('nace sin id y con el dueño como único integrante', () {
      final draft = Group.draft(
        name: 'Robótica',
        description: 'Robots',
        ownerId: 'user_9',
        ownerName: 'Andrés',
      );

      expect(draft.id, isEmpty);
      expect(draft.isPersisted, isFalse);
      expect(draft.memberCount, 1);
      expect(draft.memberIds, ['user_9']);
      expect(draft.members.single.userName, 'Andrés');
      expect(draft.isOwner('user_9'), isTrue);
      expect(draft.hasMember('user_9'), isTrue);
    });
  });

  test('distingue al dueño de un integrante cualquiera', () {
    expect(team.isOwner('user_1'), isTrue);
    expect(team.isOwner('user_2'), isFalse);
    expect(team.hasMember('user_2'), isTrue);
    expect(team.hasMember('user_3'), isFalse);
  });

  test('memberIds sigue el orden de los integrantes y no se puede alterar', () {
    expect(team.memberIds, ['user_1', 'user_2']);
    expect(() => team.memberIds.add('x'), throwsUnsupportedError);
  });

  test('memberCount cuenta las filas de integrantes', () {
    expect(team.memberCount, 2);
  });

  test('copyWith reemplaza solo lo indicado', () {
    final copy = team.copyWith(name: 'Otro', members: const []);

    expect(copy.name, 'Otro');
    expect(copy.memberCount, 0);
    expect(copy.id, 'group_1');
    expect(copy.description, 'Concursos');
    expect(copy.ownerId, 'user_1');
    expect(copy.ownerName, 'Leonel');
  });

  group('GroupMember', () {
    test('sin id hasta que se guarda', () {
      const member = GroupMember(groupId: 'g', userId: 'u', userName: 'n');

      expect(member.id, isEmpty);
    });

    test('copyWith conserva lo que no cambia', () {
      const member = GroupMember(groupId: 'g', userId: 'u', userName: 'n');
      final stored = member.copyWith(id: 'm1');

      expect(stored.id, 'm1');
      expect(stored.groupId, 'g');
      expect(stored.userId, 'u');
      expect(stored.userName, 'n');
      expect(member.copyWith(userName: 'otro').userName, 'otro');
    });
  });
}
