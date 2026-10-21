import 'package:campus_innovate/features/listings/domain/models/listing.dart';
import 'package:campus_innovate/features/listings/domain/models/listing_member.dart';
import 'package:campus_innovate/features/listings/domain/models/listing_role.dart';
import 'package:campus_innovate/features/listings/domain/models/listing_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Listing listing({
    List<String> memberIds = const ['user_1'],
    List<ListingMember> members = const [],
    int maxMembers = 4,
    ListingStatus status = ListingStatus.idea,
  }) =>
      Listing(
        id: 'listing_1',
        title: 'Campus App',
        description: 'Una app para el campus',
        category: 'Tecnología',
        creatorId: 'user_1',
        creatorName: 'Leonel',
        maxMembers: maxMembers,
        requiredSkills: const [],
        memberIds: memberIds,
        status: status,
        members: members,
      );

  ListingMember member(
    String id,
    ListingRole role, {
    String name = '',
  }) =>
      ListingMember(userId: id, userName: name, role: role);

  test('un proyecto sin estado guardado es una idea sin equipo descrito', () {
    final plain = listing();

    expect(plain.status, ListingStatus.idea);
    expect(plain.members, isEmpty);
  });

  test('el borrador nace con el creador como líder', () {
    final draft = Listing.draft(
      title: 'Huerta',
      description: 'Cultivar',
      category: 'Sostenibilidad',
      creatorId: 'user_7',
      creatorName: 'Mariana',
      maxMembers: 4,
      requiredSkills: const [],
    );

    expect(draft.status, ListingStatus.idea);
    expect(draft.members.single.userId, 'user_7');
    expect(draft.members.single.userName, 'Mariana');
    expect(draft.members.single.role, ListingRole.leader);
    expect(draft.leaderId, 'user_7');
  });

  group('team', () {
    test('sin filas de rol, el creador lidera y el resto son integrantes', () {
      // A project published before roles existed: only memberIds is known.
      final old = listing(memberIds: ['user_1', 'user_2', 'user_3']);

      expect(old.team.map((m) => m.userId), ['user_1', 'user_2', 'user_3']);
      expect(old.team.map((m) => m.role), [
        ListingRole.leader,
        ListingRole.member,
        ListingRole.member,
      ]);
      expect(old.team.first.userName, 'Leonel');
      expect(old.team[1].userName, isEmpty);
    });

    test('respeta el orden de memberIds, no el de las filas de rol', () {
      final team = listing(
        memberIds: ['user_1', 'user_2', 'user_3'],
        members: [
          member('user_3', ListingRole.mentor, name: 'Carlos'),
          member('user_1', ListingRole.leader, name: 'Leonel'),
        ],
      ).team;

      expect(team.map((m) => m.userId), ['user_1', 'user_2', 'user_3']);
      expect(team[2].role, ListingRole.mentor);
      expect(team[2].userName, 'Carlos');
    });

    test('si otro es líder explícito, el creador sin fila es integrante', () {
      final transferred = listing(
        memberIds: ['user_1', 'user_2'],
        members: [member('user_2', ListingRole.leader, name: 'Mariana')],
      );

      expect(transferred.roleOf('user_1'), ListingRole.member);
      expect(transferred.roleOf('user_2'), ListingRole.leader);
      expect(transferred.leaderId, 'user_2');
    });

    test('un líder explícito que ya salió no le quita el liderazgo al creador',
        () {
      // Their role row survives in `members`, but they are no longer in
      // memberIds, which is the one answer to "who is in".
      final left = listing(
        memberIds: ['user_1', 'user_3'],
        members: [member('user_2', ListingRole.leader)],
      );

      expect(left.team.map((m) => m.userId), ['user_1', 'user_3']);
      expect(left.isLeader('user_1'), isTrue);
      expect(left.roleOf('user_2'), isNull);
    });

    test('una fila de rol de alguien fuera de memberIds no aparece', () {
      final team = listing(
        members: [member('user_9', ListingRole.member, name: 'Fantasma')],
      ).team;

      expect(team.map((m) => m.userId), ['user_1']);
    });

    test('el creador explícitamente integrante no se vuelve líder', () {
      final demoted = listing(
        memberIds: ['user_1', 'user_2'],
        members: [
          member('user_1', ListingRole.member, name: 'Leonel'),
          member('user_2', ListingRole.leader, name: 'Mariana'),
        ],
      );

      expect(demoted.isLeader('user_1'), isFalse);
      expect(demoted.leaderId, 'user_2');
    });
  });

  group('roleOf e isLeader', () {
    final mixed = listing(
      memberIds: ['user_1', 'user_2', 'user_3'],
      members: [member('user_3', ListingRole.mentor)],
    );

    test('dan el rol de cada integrante', () {
      expect(mixed.roleOf('user_1'), ListingRole.leader);
      expect(mixed.roleOf('user_2'), ListingRole.member);
      expect(mixed.roleOf('user_3'), ListingRole.mentor);
      expect(mixed.isLeader('user_1'), isTrue);
      expect(mixed.isLeader('user_3'), isFalse);
    });

    test('alguien de fuera no tiene rol ni lidera', () {
      expect(mixed.roleOf('user_9'), isNull);
      expect(mixed.isLeader('user_9'), isFalse);
    });
  });

  group('leaderId', () {
    test('con dos líderes es el primero del equipo', () {
      // Two leaders is the state a transfer interrupted halfway leaves.
      final halfway = listing(
        memberIds: ['user_2', 'user_1'],
        members: [
          member('user_1', ListingRole.leader),
          member('user_2', ListingRole.leader),
        ],
      );

      expect(halfway.leaderId, 'user_2');
      expect(halfway.isLeader('user_1'), isTrue);
    });

    test('sin nadie liderando cae en el creador', () {
      final nobody = listing(
        memberIds: ['user_2'],
        members: [member('user_2', ListingRole.member)],
      );

      expect(nobody.leaderId, 'user_1');
    });
  });

  group('isRecruiting', () {
    test('una idea o un proyecto en curso con cupo busca gente', () {
      expect(listing(status: ListingStatus.idea).isRecruiting, isTrue);
      expect(listing(status: ListingStatus.inProgress).isRecruiting, isTrue);
    });

    test('pausado o terminado no busca gente aunque tenga cupo', () {
      expect(listing(status: ListingStatus.paused).isRecruiting, isFalse);
      expect(listing(status: ListingStatus.done).isRecruiting, isFalse);
    });

    test('lleno no busca gente aunque esté abierto', () {
      final full = listing(memberIds: ['user_1', 'user_2'], maxMembers: 2);

      expect(full.isFull, isTrue);
      expect(full.isRecruiting, isFalse);
    });
  });

  group('copyWith', () {
    test('cambia el estado y conserva el resto', () {
      final original = listing(
        memberIds: ['user_1', 'user_2'],
        members: [member('user_2', ListingRole.mentor)],
      );
      final paused = original.copyWith(status: ListingStatus.paused);

      expect(paused.status, ListingStatus.paused);
      expect(paused.memberIds, ['user_1', 'user_2']);
      expect(paused.members, same(original.members));
      expect(paused.title, 'Campus App');
    });

    test('cambia los integrantes descritos y conserva el estado', () {
      final original = listing(
        memberIds: ['user_1', 'user_2'],
        status: ListingStatus.inProgress,
      );
      final described = original.copyWith(
        members: [member('user_2', ListingRole.leader)],
      );

      expect(described.status, ListingStatus.inProgress);
      expect(described.leaderId, 'user_2');
      expect(original.leaderId, 'user_1');
    });
  });
}
