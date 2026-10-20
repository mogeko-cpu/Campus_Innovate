import 'package:campus_innovate/features/groups/data/repositories/group_repository.dart';
import 'package:campus_innovate/features/groups/domain/group_exception.dart';
import 'package:campus_innovate/features/groups/domain/models/group.dart';
import 'package:campus_innovate/features/groups/domain/models/group_invitation.dart';
import 'package:campus_innovate/features/groups/domain/models/group_member.dart';
import 'package:campus_innovate/features/groups/domain/models/group_request.dart';
import 'package:campus_innovate/features/groups/domain/models/group_request_status.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/in_memory_group_source.dart';

/// What `group_collaboration_test.dart` does not already cover: listing "my"
/// groups, the missing-row errors, leftovers of the old status column, and
/// leaving a group. The seeded group is `group_1`, owned by `user_1`.
void main() {
  late InMemoryGroupSource source;
  late GroupRepository repository;

  setUp(() {
    source = InMemoryGroupSource();
    repository = GroupRepository(source);
  });

  GroupRequest requestFrom(String id, {String groupId = 'group_1'}) =>
      GroupRequest.draft(
        groupId: groupId,
        applicantId: id,
        applicantName: 'Alguien',
        message: 'Quiero entrar',
      );

  GroupInvitation invitationFor(String id, {String groupId = 'group_1'}) =>
      GroupInvitation.draft(
        groupId: groupId,
        groupName: 'Innovación UN',
        inviterId: 'user_1',
        inviterName: 'Leonel',
        inviteeId: id,
        inviteeName: 'Alguien',
      );

  group('mis grupos', () {
    test('los que dirijo van antes que en los que solo participo', () async {
      // A group somebody else runs, with user_1 inside, created after group_1
      // so it sits first in the store.
      final other = await repository.createGroup(
        Group.draft(
          name: 'Ajeno',
          description: '',
          ownerId: 'user_2',
          ownerName: 'Mariana',
        ),
      );
      await source.addMember(
        GroupMember(groupId: other.id, userId: 'user_1', userName: 'Leonel'),
      );
      await repository.createGroup(
        Group.draft(
          name: 'Sin mí',
          description: '',
          ownerId: 'user_3',
          ownerName: 'Otro',
        ),
      );

      final mine = await repository.getMyGroups('user_1');

      expect(mine.map((g) => g.name), ['Innovación UN', 'Ajeno']);
    });

    test('alguien sin grupos no tiene ninguno', () async {
      expect(await repository.getMyGroups('user_9'), isEmpty);
    });

    test('crear un grupo deja al dueño dentro y con id', () async {
      final created = await repository.createGroup(
        Group.draft(
          name: 'Nuevo',
          description: '',
          ownerId: 'user_4',
          ownerName: 'Ana',
        ),
      );

      expect(created.isPersisted, isTrue);
      expect(created.hasMember('user_4'), isTrue);
      expect((await repository.getGroupById(created.id))?.name, 'Nuevo');
    });
  });

  group('pedir entrar', () {
    test('a un grupo que no existe se rechaza', () async {
      await expectLater(
        repository.requestToJoin(requestFrom('user_2', groupId: 'no-existe')),
        throwsA(isA<GroupException>()),
      );
    });

    test('quien ya es integrante no puede pedir entrar', () async {
      await expectLater(
        repository.requestToJoin(requestFrom('user_1')),
        throwsA(
          isA<GroupException>()
              .having((e) => e.message, 'message', contains('Ya haces parte')),
        ),
      );
    });

    test('una solicitud vieja ya respondida se limpia y deja pedir otra vez',
        () async {
      // Rows from before answered requests were deleted still carry a status.
      final old = await source.createRequest(requestFrom('user_2'));
      await source.updateRequestStatus(old.id, GroupRequestStatus.rejected);

      final fresh = await repository.requestToJoin(requestFrom('user_2'));

      final requests = await repository.getRequestsForGroup('group_1');
      expect(requests.map((r) => r.id), [fresh.id]);
      expect(fresh.isPending, isTrue);
    });
  });

  group('mis solicitudes', () {
    test('mi solicitud a un grupo es solo la que sigue pendiente', () async {
      final old = await source.createRequest(requestFrom('user_2'));
      await source.updateRequestStatus(old.id, GroupRequestStatus.accepted);

      expect(
        await repository.getMyRequestForGroup(
          groupId: 'group_1',
          applicantId: 'user_2',
        ),
        isNull,
      );
    });

    test('mi solicitud pendiente se encuentra', () async {
      final sent = await repository.requestToJoin(requestFrom('user_2'));

      final found = await repository.getMyRequestForGroup(
        groupId: 'group_1',
        applicantId: 'user_2',
      );

      expect(found?.id, sent.id);
    });

    test('la lista de mis solicitudes omite las respondidas', () async {
      final other = await repository.createGroup(
        Group.draft(
          name: 'Otro',
          description: '',
          ownerId: 'user_3',
          ownerName: 'X',
        ),
      );
      final pending = await repository.requestToJoin(requestFrom('user_2'));
      final answered =
          await source.createRequest(requestFrom('user_2', groupId: other.id));
      await source.updateRequestStatus(answered.id, GroupRequestStatus.rejected);

      final mine = await repository.getMyRequests('user_2');

      expect(mine.map((r) => r.id), [pending.id]);
    });
  });

  group('filas que ya no existen', () {
    test('aceptar o rechazar una solicitud borrada falla con un mensaje',
        () async {
      await expectLater(
        repository.acceptRequest('no-existe'),
        throwsA(isA<GroupException>()),
      );
      await expectLater(
        repository.rejectRequest('no-existe'),
        throwsA(isA<GroupException>()),
      );
    });

    test('aceptar o rechazar una invitación borrada falla con un mensaje',
        () async {
      await expectLater(
        repository.acceptInvitation('no-existe'),
        throwsA(isA<GroupException>()),
      );
      await expectLater(
        repository.rejectInvitation('no-existe'),
        throwsA(isA<GroupException>()),
      );
    });

    test('invitar a un grupo que no existe falla', () async {
      await expectLater(
        repository.inviteUser(invitationFor('user_2', groupId: 'no-existe')),
        throwsA(isA<GroupException>()),
      );
    });
  });

  group('invitaciones', () {
    test('aceptar una invitación limpia una solicitud vieja de esa persona',
        () async {
      // An answered leftover does not block the invitation, but must not stay
      // in the owner's list once the person is in.
      final old = await source.createRequest(requestFrom('user_2'));
      await source.updateRequestStatus(old.id, GroupRequestStatus.rejected);
      final keep = await source.createRequest(requestFrom('user_3'));

      final invitation = await repository.inviteUser(invitationFor('user_2'));
      await repository.acceptInvitation(invitation.id);

      final requests = await repository.getRequestsForGroup('group_1');
      expect(requests.map((r) => r.id), [keep.id]);
      expect((await repository.getGroupById('group_1'))?.hasMember('user_2'),
          isTrue);
    });

    test('cancelar una invitación la quita del grupo y de la persona',
        () async {
      final invitation = await repository.inviteUser(invitationFor('user_2'));

      await repository.cancelInvitation(invitation.id);

      expect(await repository.getInvitationsForGroup('group_1'), isEmpty);
      expect(await repository.getMyInvitations('user_2'), isEmpty);
    });

    test('mis invitaciones son solo las dirigidas a mí', () async {
      await repository.inviteUser(invitationFor('user_2'));
      await repository.inviteUser(invitationFor('user_3'));

      final mine = await repository.getMyInvitations('user_2');

      expect(mine.map((i) => i.inviteeId), ['user_2']);
    });
  });

  group('salir del grupo', () {
    test('un integrante puede salir', () async {
      await source.addMember(
        const GroupMember(groupId: 'group_1', userId: 'user_2', userName: 'M'),
      );

      await repository.removeMember(groupId: 'group_1', userId: 'user_2');

      final group = await repository.getGroupById('group_1');
      expect(group?.hasMember('user_2'), isFalse);
      expect(group?.hasMember('user_1'), isTrue);
    });

    test('el dueño no puede salir de su propio grupo', () async {
      await expectLater(
        repository.removeMember(groupId: 'group_1', userId: 'user_1'),
        throwsA(
          isA<GroupException>()
              .having((e) => e.message, 'message', contains('creador')),
        ),
      );

      expect((await repository.getGroupById('group_1'))?.hasMember('user_1'),
          isTrue);
    });

    test('salir de un grupo que no existe falla', () async {
      await expectLater(
        repository.removeMember(groupId: 'no-existe', userId: 'user_2'),
        throwsA(isA<GroupException>()),
      );
    });
  });

  test('borrar un grupo se lleva sus solicitudes e invitaciones', () async {
    await repository.requestToJoin(requestFrom('user_2'));
    await repository.inviteUser(invitationFor('user_3'));

    await repository.deleteGroup('group_1');

    expect(await repository.getGroupById('group_1'), isNull);
    expect(await repository.getGroups(), isEmpty);
    expect(await repository.getRequestsForGroup('group_1'), isEmpty);
    expect(await repository.getMyInvitations('user_3'), isEmpty);
  });
}
