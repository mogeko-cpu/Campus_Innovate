import 'package:campus_innovate/features/groups/domain/models/group.dart';
import 'package:campus_innovate/features/groups/domain/models/group_invitation.dart';
import 'package:campus_innovate/features/groups/domain/models/group_request.dart';
import 'package:campus_innovate/features/groups/ui/viewmodels/groups_view_model.dart';
import 'package:campus_innovate/features/listings/domain/models/listing.dart';
import 'package:campus_innovate/features/notifications/domain/models/notification_type.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/in_memory_group_source.dart';
import '../../../../support/test_session.dart';
import '../../view_model_harness.dart';

class _FailingGroupSource extends InMemoryGroupSource {
  @override
  Future<List<Group>> getGroups() async => throw StateError('groups');
}

void main() {
  setUpViewModelTests();

  late ViewModelHarness harness;

  Future<GroupsViewModel> open() => start(
        GroupsViewModel(
          harness.groups,
          harness.listings,
          harness.publisher,
          harness.session,
        ),
      );

  Future<Group> otherGroup() => harness.groups.createGroup(
        Group.draft(
          name: 'Robótica',
          description: 'Robots',
          ownerId: 'user_3',
          ownerName: 'Carlos Ruiz',
        ),
      );

  Future<Listing> publishFor(String groupId) =>
      harness.listingSource.createListing(
        Listing.draft(
          title: 'Proyecto de $groupId',
          description: 'Descripción',
          category: 'Tecnología',
          creatorId: 'user_1',
          creatorName: 'Leonel Triana',
          maxMembers: 4,
          requiredSkills: const [],
          groupId: groupId,
          groupName: 'Innovación UN',
        ),
      );

  Future<GroupInvitation> inviteMariana() => harness.groups.inviteUser(
        const GroupInvitation.draft(
          groupId: 'group_1',
          groupName: 'Innovación UN',
          inviterId: 'user_1',
          inviterName: 'Leonel Triana',
          inviteeId: 'user_2',
          inviteeName: 'Mariana Ospina',
        ),
      );

  setUp(() => harness = ViewModelHarness());

  group('carga', () {
    test('separa los grupos propios de los del resto del campus', () async {
      final other = await otherGroup();

      final viewModel = await open();

      expect(viewModel.currentUserId, 'user_1');
      expect(viewModel.myGroups.map((group) => group.id), ['group_1']);
      expect(viewModel.otherGroups.map((group) => group.id), [other.id]);
      expect(viewModel.isLoading.value, isFalse);
      expect(viewModel.error.value, isNull);
    });

    test('cuenta los proyectos de cada grupo e ignora los que no tienen',
        () async {
      final other = await otherGroup();
      await publishFor('group_1');
      await publishFor('group_1');

      final viewModel = await open();
      final mine = viewModel.myGroups.single;

      expect(viewModel.projectsOf(mine), 2);
      expect(viewModel.projectsOf(viewModel.otherGroups.single), 0);
      expect(viewModel.projectCounts.keys, ['group_1']);
      expect(viewModel.projectCounts.containsKey(other.id), isFalse);
    });

    test('myRequestFor encuentra la solicitud que ya envié', () async {
      await harness.groups.requestToJoin(
        const GroupRequest.draft(
          groupId: 'group_1',
          applicantId: 'user_2',
          applicantName: 'Mariana Ospina',
          message: 'Quiero entrar',
        ),
      );
      final other = await otherGroup();
      harness.session.signInAs(TestUsers.mariana);

      final viewModel = await open();
      final innovation = viewModel.otherGroups.firstWhere(
        (group) => group.id == 'group_1',
      );
      final robotics = viewModel.otherGroups.firstWhere(
        (group) => group.id == other.id,
      );

      expect(viewModel.myRequestFor(innovation), isNotNull);
      expect(viewModel.myRequestFor(robotics), isNull);
    });

    test('un fallo al cargar muestra el mensaje de respaldo', () async {
      harness = ViewModelHarness(groupSource: _FailingGroupSource());

      final viewModel = await open();

      expect(viewModel.error.value, 'No se pudieron cargar los grupos');
      expect(viewModel.isLoading.value, isFalse);
    });

    test('una recarga silenciosa que falla no muestra error', () async {
      harness = ViewModelHarness(groupSource: _FailingGroupSource());
      final viewModel = GroupsViewModel(
        harness.groups,
        harness.listings,
        harness.publisher,
        harness.session,
      );

      await viewModel.load(silent: true);

      expect(viewModel.error.value, isNull);
    });
  });

  group('invitaciones', () {
    test('muestra las invitaciones recibidas', () async {
      await inviteMariana();
      harness.session.signInAs(TestUsers.mariana);

      final viewModel = await open();

      expect(viewModel.invitations.single.groupId, 'group_1');
    });

    test('aceptar pasa el grupo a los míos y avisa a quien invitó', () async {
      await inviteMariana();
      harness.session.signInAs(TestUsers.mariana);
      final viewModel = await open();

      final done = await viewModel.acceptInvitation(
        viewModel.invitations.single,
      );

      expect(done, isTrue);
      expect(viewModel.myGroups.map((group) => group.id), ['group_1']);
      expect(viewModel.otherGroups, isEmpty);
      expect(viewModel.invitations, isEmpty);
      expect(viewModel.isWorking.value, isFalse);

      final sent = harness.notificationSource.all;
      expect(sent.single.recipientId, 'user_1');
      expect(sent.single.type, NotificationType.invitationAccepted);
    });

    test('rechazar la quita sin sumar al grupo y avisa', () async {
      await inviteMariana();
      harness.session.signInAs(TestUsers.mariana);
      final viewModel = await open();

      final done = await viewModel.rejectInvitation(
        viewModel.invitations.single,
      );

      expect(done, isTrue);
      expect(viewModel.myGroups, isEmpty);
      expect(viewModel.invitations, isEmpty);
      expect(
        harness.notificationSource.all.single.type,
        NotificationType.invitationRejected,
      );
    });

    test('responder una invitación que ya no existe lo dice aparte', () async {
      final invitation = await inviteMariana();
      harness.session.signInAs(TestUsers.mariana);
      final viewModel = await open();
      await harness.groups.cancelInvitation(invitation.id);

      final done = await viewModel.acceptInvitation(invitation);

      expect(done, isFalse);
      expect(viewModel.lastActionError, 'Esta invitación ya no existe.');
      // A failed button must not replace the whole screen with an error.
      expect(viewModel.error.value, isNull);
      expect(harness.notificationSource.all, isEmpty);
    });
  });
}
