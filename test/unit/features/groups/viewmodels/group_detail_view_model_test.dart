import 'package:campus_innovate/features/groups/domain/models/group.dart';
import 'package:campus_innovate/features/groups/domain/models/group_invitation.dart';
import 'package:campus_innovate/features/groups/domain/models/group_member.dart';
import 'package:campus_innovate/features/groups/domain/models/group_request.dart';
import 'package:campus_innovate/features/groups/ui/viewmodels/group_detail_view_model.dart';
import 'package:campus_innovate/features/listings/domain/models/listing.dart';
import 'package:campus_innovate/features/notifications/domain/models/notification_target.dart';
import 'package:campus_innovate/features/notifications/domain/models/notification_type.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/in_memory_group_source.dart';
import '../../../../support/test_session.dart';
import '../../view_model_harness.dart';

/// Reads that can start failing halfway through a test.
class _FlakyGroupSource extends InMemoryGroupSource {
  bool fail = false;

  @override
  Future<Group?> getGroupById(String id) async {
    if (fail) throw StateError('groups');

    return super.getGroupById(id);
  }
}

const _carlos = TestUser(
  id: 'user_3',
  name: 'Carlos Ruiz',
  email: 'carlos@uninorte.edu.co',
);

void main() {
  setUpViewModelTests();

  late ViewModelHarness harness;

  Future<GroupDetailViewModel> open({
    TestUser user = TestUsers.leonel,
    String id = 'group_1',
  }) {
    harness.session.signInAs(user);

    return start(
      GroupDetailViewModel(
        harness.groups,
        harness.listings,
        harness.publisher,
        harness.session,
      ),
      routeId: id,
    );
  }

  Future<void> addMember(TestUser user) => harness.groupSource.addMember(
        GroupMember(groupId: 'group_1', userId: user.id, userName: user.name),
      );

  Future<GroupInvitation> invite(TestUser invitee, {TestUser? by}) {
    final inviter = by ?? TestUsers.leonel;

    return harness.groups.inviteUser(
      GroupInvitation.draft(
        groupId: 'group_1',
        groupName: 'Innovación UN',
        inviterId: inviter.id,
        inviterName: inviter.name,
        inviteeId: invitee.id,
        inviteeName: invitee.name,
      ),
    );
  }

  Future<GroupRequest> requestFrom(TestUser user) =>
      harness.groups.requestToJoin(
        GroupRequest.draft(
          groupId: 'group_1',
          applicantId: user.id,
          applicantName: user.name,
          message: 'Quiero entrar',
        ),
      );

  Future<Listing> publish() => harness.listingSource.createListing(
        Listing.draft(
          title: 'Proyecto del grupo',
          description: 'Descripción',
          category: 'Tecnología',
          creatorId: 'user_1',
          creatorName: 'Leonel Triana',
          maxMembers: 4,
          requiredSkills: const [],
          groupId: 'group_1',
          groupName: 'Innovación UN',
        ),
      );

  Future<Group> stored() async => (await harness.groups.getGroupById('group_1'))!;

  setUp(() => harness = ViewModelHarness());

  group('roles', () {
    test('el dueño está adentro, ve solicitudes e invitaciones', () async {
      await requestFrom(TestUsers.mariana);
      await invite(_carlos);

      final viewModel = await open();

      expect(viewModel.isOwner, isTrue);
      expect(viewModel.isMember, isTrue);
      expect(viewModel.isInside, isTrue);
      expect(viewModel.canRequestToJoin, isFalse);
      expect(viewModel.pendingRequests, hasLength(1));
      expect(viewModel.invitations, hasLength(1));
      expect(viewModel.isLoading.value, isFalse);
    });

    test('un integrante ve las invitaciones pero no las solicitudes', () async {
      await addMember(TestUsers.mariana);
      await requestFrom(_carlos);
      await invite(const TestUser(id: 'user_4', name: 'Sofía', email: 's@u.co'));

      final viewModel = await open(user: TestUsers.mariana);

      expect(viewModel.isOwner, isFalse);
      expect(viewModel.isMember, isTrue);
      expect(viewModel.isInside, isTrue);
      expect(viewModel.canRequestToJoin, isFalse);
      expect(viewModel.requests, isEmpty);
      expect(viewModel.invitations, hasLength(1));
      expect(viewModel.myRequest.value, isNull);
    });

    test('alguien de afuera puede pedir entrar y no ve invitaciones ajenas',
        () async {
      await invite(_carlos);

      final viewModel = await open(user: TestUsers.mariana);

      expect(viewModel.isInside, isFalse);
      expect(viewModel.canRequestToJoin, isTrue);
      expect(viewModel.invitations, isEmpty);
      expect(viewModel.myInvitation.value, isNull);
    });

    test('quien fue invitado ve su invitación y no puede pedir entrar',
        () async {
      await invite(TestUsers.mariana);

      final viewModel = await open(user: TestUsers.mariana);

      expect(viewModel.isInside, isFalse);
      expect(viewModel.myInvitation.value?.inviteeId, 'user_2');
      expect(viewModel.canRequestToJoin, isFalse);
    });

    test('un grupo inexistente dice que no se encontró', () async {
      final viewModel = await open(id: 'ghost');

      expect(viewModel.error.value, 'Grupo no encontrado');
      expect(viewModel.group.value, isNull);
      expect(viewModel.canRequestToJoin, isFalse);
    });

    test('lista los proyectos que publicó el grupo', () async {
      final project = await publish();

      final viewModel = await open();

      expect(viewModel.projects.map((listing) => listing.id), [project.id]);
    });
  });

  group('requestToJoin', () {
    test('envía la solicitud, la muestra y avisa al dueño', () async {
      final viewModel = await open(user: TestUsers.mariana);

      final sent = await viewModel.requestToJoin('  Quiero entrar  ');

      expect(sent, isTrue);
      expect(viewModel.myRequest.value?.message, 'Quiero entrar');
      expect(viewModel.canRequestToJoin, isFalse);
      expect(viewModel.isWorking.value, isFalse);

      final notification = harness.notificationSource.all.single;
      expect(notification.recipientId, 'user_1');
      expect(notification.type, NotificationType.requestReceived);
      expect(notification.target, NotificationTarget.group);
      expect(notification.targetId, 'group_1');
    });

    test('una segunda solicitud se rechaza con el motivo', () async {
      final viewModel = await open(user: TestUsers.mariana);
      await viewModel.requestToJoin('Primera');

      final again = await viewModel.requestToJoin('Segunda');

      expect(again, isFalse);
      expect(viewModel.error.value, 'Ya enviaste una solicitud a este grupo.');
      expect(harness.notificationSource.all, hasLength(1));
    });

    test('sin grupo cargado no envía nada', () async {
      final viewModel = await open(user: TestUsers.mariana, id: 'ghost');

      expect(await viewModel.requestToJoin('Hola'), isFalse);
    });
  });

  group('solicitudes, como dueño', () {
    test('aceptar suma a la persona, quita la solicitud y le avisa', () async {
      final request = await requestFrom(TestUsers.mariana);
      final viewModel = await open();

      final done = await viewModel.accept(request.id);

      expect(done, isTrue);
      expect(viewModel.group.value!.hasMember('user_2'), isTrue);
      expect(viewModel.pendingRequests, isEmpty);

      final notification = harness.notificationSource.all.single;
      expect(notification.recipientId, 'user_2');
      expect(notification.type, NotificationType.requestAccepted);
    });

    test('rechazar quita la solicitud sin sumar a nadie y avisa', () async {
      final request = await requestFrom(TestUsers.mariana);
      final viewModel = await open();

      final done = await viewModel.reject(request.id);

      expect(done, isTrue);
      expect(viewModel.group.value!.hasMember('user_2'), isFalse);
      expect(viewModel.pendingRequests, isEmpty);
      expect(
        harness.notificationSource.all.single.type,
        NotificationType.requestRejected,
      );
    });

    test('una solicitud que ya no existe da error y no avisa', () async {
      final viewModel = await open();

      final done = await viewModel.accept('group_request_missing');

      expect(done, isFalse);
      expect(viewModel.error.value, 'Esta solicitud ya no existe.');
      expect(harness.notificationSource.all, isEmpty);
    });
  });

  group('integrantes', () {
    test('el dueño puede quitar a un integrante', () async {
      await addMember(TestUsers.mariana);
      final viewModel = await open();

      final done = await viewModel.removeMember('user_2');

      expect(done, isTrue);
      expect(viewModel.group.value!.hasMember('user_2'), isFalse);
      expect((await stored()).hasMember('user_2'), isFalse);
    });

    test('al dueño no se le puede quitar', () async {
      final viewModel = await open();

      final done = await viewModel.removeMember('user_1');

      expect(done, isFalse);
      expect(viewModel.error.value, startsWith('El creador no puede salir'));
      expect((await stored()).hasMember('user_1'), isTrue);
    });

    test('un integrante puede salir del grupo', () async {
      await addMember(TestUsers.mariana);
      final viewModel = await open(user: TestUsers.mariana);

      final done = await viewModel.leave();

      expect(done, isTrue);
      expect(viewModel.isMember, isFalse);
      expect(viewModel.isInside, isFalse);
      expect(viewModel.canRequestToJoin, isTrue);
    });

    test('el dueño no puede salir', () async {
      final viewModel = await open();

      expect(await viewModel.leave(), isFalse);
      expect(viewModel.isOwner, isTrue);
    });
  });

  group('mi invitación', () {
    test('aceptarla me deja adentro y avisa a quien invitó', () async {
      await invite(TestUsers.mariana);
      final viewModel = await open(user: TestUsers.mariana);

      final done = await viewModel.acceptMyInvitation();

      expect(done, isTrue);
      expect(viewModel.isMember, isTrue);
      expect(viewModel.myInvitation.value, isNull);

      final notification = harness.notificationSource.all.single;
      expect(notification.recipientId, 'user_1');
      expect(notification.type, NotificationType.invitationAccepted);
    });

    test('rechazarla me deja afuera y avisa a quien invitó', () async {
      await invite(TestUsers.mariana);
      final viewModel = await open(user: TestUsers.mariana);

      final done = await viewModel.rejectMyInvitation();

      expect(done, isTrue);
      expect(viewModel.isMember, isFalse);
      expect(viewModel.myInvitation.value, isNull);
      expect(viewModel.canRequestToJoin, isTrue);
      expect(
        harness.notificationSource.all.single.type,
        NotificationType.invitationRejected,
      );
    });

    test('sin invitación no hay nada que responder', () async {
      final viewModel = await open(user: TestUsers.mariana);

      expect(await viewModel.acceptMyInvitation(), isFalse);
      expect(await viewModel.rejectMyInvitation(), isFalse);
      expect(harness.notificationSource.all, isEmpty);
    });
  });

  group('cancelar invitaciones', () {
    test('el dueño cancela cualquiera', () async {
      await addMember(TestUsers.mariana);
      final invitation = await invite(_carlos, by: TestUsers.mariana);
      final viewModel = await open();

      expect(viewModel.canCancel(invitation), isTrue);

      final done = await viewModel.cancelInvitation(invitation.id);

      expect(done, isTrue);
      expect(viewModel.invitations, isEmpty);
    });

    test('un integrante solo cancela las que envió', () async {
      await addMember(TestUsers.mariana);
      final own = await invite(_carlos, by: TestUsers.mariana);
      final ownersOne = await invite(
        const TestUser(id: 'user_4', name: 'Sofía', email: 's@u.co'),
      );

      final viewModel = await open(user: TestUsers.mariana);

      expect(viewModel.canCancel(own), isTrue);
      expect(viewModel.canCancel(ownersOne), isFalse);
    });
  });

  group('deleteGroup', () {
    test('solo el dueño puede eliminarlo', () async {
      await addMember(TestUsers.mariana);
      final viewModel = await open(user: TestUsers.mariana);

      final done = await viewModel.deleteGroup();

      expect(done, isFalse);
      expect(viewModel.error.value, 'Solo quien creó el grupo puede eliminarlo.');
      expect(await harness.groups.getGroupById('group_1'), isNotNull);
    });

    test('con un proyecto publicado se niega y lo dice en singular', () async {
      await publish();
      final viewModel = await open();

      final done = await viewModel.deleteGroup();

      expect(done, isFalse);
      expect(
        viewModel.error.value,
        'Este grupo tiene 1 proyecto publicado. Elimínalo antes de eliminar '
        'el grupo.',
      );
      expect(await harness.groups.getGroupById('group_1'), isNotNull);
    });

    test('con varios proyectos lo dice en plural', () async {
      await publish();
      await publish();
      final viewModel = await open();

      await viewModel.deleteGroup();

      expect(
        viewModel.error.value,
        'Este grupo tiene 2 proyectos publicados. Elimínalos antes de '
        'eliminar el grupo.',
      );
    });

    test('sin proyectos el dueño lo elimina', () async {
      final viewModel = await open();

      final done = await viewModel.deleteGroup();

      expect(done, isTrue);
      expect(await harness.groups.getGroupById('group_1'), isNull);
      expect(viewModel.error.value, isNull);
    });
  });

  group('recarga silenciosa', () {
    test('un fallo conserva lo que se mostraba y no pone error', () async {
      final source = _FlakyGroupSource();
      harness = ViewModelHarness(groupSource: source);
      final viewModel = await open();

      source.fail = true;
      await viewModel.load(silent: true);

      expect(viewModel.error.value, isNull);
      expect(viewModel.group.value?.id, 'group_1');

      await viewModel.load();

      expect(viewModel.error.value, 'No se pudo cargar el grupo');
      expect(viewModel.isLoading.value, isFalse);
    });
  });
}
