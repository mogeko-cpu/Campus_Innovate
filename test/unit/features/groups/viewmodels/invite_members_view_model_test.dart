import 'package:campus_innovate/features/groups/domain/models/group_request.dart';
import 'package:campus_innovate/features/groups/ui/viewmodels/invite_members_view_model.dart';
import 'package:campus_innovate/features/notifications/domain/models/notification_type.dart';
import 'package:campus_innovate/features/users/domain/models/app_user.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../view_model_harness.dart';

const _leonel = AppUser(
  id: 'user_1',
  name: 'Leonel Triana',
  email: 'leonel@uninorte.edu.co',
);
const _andres = AppUser(
  id: 'user_3',
  name: 'Andrés Betancur',
  email: 'abetancur@uninorte.edu.co',
);

void main() {
  setUpViewModelTests();

  late ViewModelHarness harness;

  Future<InviteMembersViewModel> open({String id = 'group_1'}) => start(
        InviteMembersViewModel(
          harness.groups,
          harness.users,
          harness.publisher,
          harness.session,
        ),
        routeId: id,
      );

  AppUser candidate(InviteMembersViewModel viewModel, String id) =>
      viewModel.candidates.firstWhere((user) => user.id == id);

  // The directory already holds Mariana; Leonel (the owner) and Andrés join it.
  setUp(() async {
    harness = ViewModelHarness();
    await harness.users.registerCurrentUser(_leonel);
    await harness.users.registerCurrentUser(_andres);
  });

  group('candidatos', () {
    test('excluyen a quien ya está en el grupo, ordenados por nombre',
        () async {
      final viewModel = await open();

      expect(viewModel.candidates.map((user) => user.id), [
        'user_3',
        'user_2',
      ]);
      expect(viewModel.isLoading.value, isFalse);
      expect(viewModel.error.value, isNull);
    });

    test('se filtran por nombre sin distinguir mayúsculas', () async {
      final viewModel = await open();

      viewModel.query.value = 'OSPINA';

      expect(viewModel.candidates.map((user) => user.id), ['user_2']);
    });

    test('se filtran por correo', () async {
      final viewModel = await open();

      viewModel.query.value = '  abetancur@  ';

      expect(viewModel.candidates.map((user) => user.id), ['user_3']);
    });

    test('una búsqueda sin coincidencias deja la lista vacía', () async {
      final viewModel = await open();

      viewModel.query.value = 'zzz';

      expect(viewModel.candidates, isEmpty);
    });

    test('sin grupo no hay candidatos y se informa', () async {
      final viewModel = await open(id: 'ghost');

      expect(viewModel.error.value, 'Grupo no encontrado');
      expect(viewModel.candidates, isEmpty);
    });
  });

  group('estado de cada persona', () {
    test('hasRequested marca a quien ya pidió entrar', () async {
      await harness.groups.requestToJoin(
        const GroupRequest.draft(
          groupId: 'group_1',
          applicantId: 'user_3',
          applicantName: 'Andrés Betancur',
          message: 'Quiero entrar',
        ),
      );

      final viewModel = await open();

      expect(viewModel.hasRequested(candidate(viewModel, 'user_3')), isTrue);
      expect(viewModel.hasRequested(candidate(viewModel, 'user_2')), isFalse);
    });

    test('invitar a quien ya pidió entrar se rechaza con el motivo', () async {
      await harness.groups.requestToJoin(
        const GroupRequest.draft(
          groupId: 'group_1',
          applicantId: 'user_3',
          applicantName: 'Andrés Betancur',
          message: 'Quiero entrar',
        ),
      );
      final viewModel = await open();

      final done = await viewModel.invite(candidate(viewModel, 'user_3'));

      expect(done, isFalse);
      expect(viewModel.lastActionError, startsWith('Esta persona ya pidió'));
      expect(harness.notificationSource.all, isEmpty);
    });
  });

  group('invite', () {
    test('envía la invitación, la marca y avisa a la persona', () async {
      final viewModel = await open();
      final mariana = candidate(viewModel, 'user_2');

      expect(viewModel.isInvited(mariana), isFalse);

      final done = await viewModel.invite(mariana);

      expect(done, isTrue);
      expect(viewModel.isInvited(mariana), isTrue);
      expect(viewModel.sendingTo.value, isNull);
      expect(viewModel.lastActionError, isNull);

      final notification = harness.notificationSource.all.single;
      expect(notification.recipientId, 'user_2');
      expect(notification.type, NotificationType.invitationReceived);
      expect(notification.targetId, 'group_1');
    });

    test('marca a quién se le está enviando mientras está en curso', () async {
      final viewModel = await open();

      final pending = viewModel.invite(candidate(viewModel, 'user_2'));

      expect(viewModel.sendingTo.value, 'user_2');
      // Only one row sends at a time.
      expect(await viewModel.invite(candidate(viewModel, 'user_3')), isFalse);

      expect(await pending, isTrue);
      expect(viewModel.sendingTo.value, isNull);
    });

    test('una segunda invitación a la misma persona se rechaza', () async {
      final viewModel = await open();
      final mariana = candidate(viewModel, 'user_2');
      await viewModel.invite(mariana);

      final again = await viewModel.invite(mariana);

      expect(again, isFalse);
      expect(
        viewModel.lastActionError,
        'Esta persona ya tiene una invitación pendiente a este grupo.',
      );
      expect(viewModel.error.value, isNull);
      expect(viewModel.sendingTo.value, isNull);
      expect(harness.notificationSource.all, hasLength(1));
    });

    test('sin grupo no invita', () async {
      final viewModel = await open(id: 'ghost');

      expect(await viewModel.invite(_andres), isFalse);
    });
  });
}
