import 'package:campus_innovate/features/listings/domain/models/listing.dart';
import 'package:campus_innovate/features/listings/domain/models/listing_member.dart';
import 'package:campus_innovate/features/listings/domain/models/listing_role.dart';
import 'package:campus_innovate/features/listings/domain/models/listing_status.dart';
import 'package:campus_innovate/features/listings/domain/models/listing_task.dart';
import 'package:campus_innovate/features/listings/domain/models/task_column.dart';
import 'package:campus_innovate/features/listings/ui/viewmodels/listing_detail_view_model.dart';
import 'package:campus_innovate/features/notifications/domain/models/notification_type.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/in_memory_task_source.dart';
import '../../../../support/test_session.dart';
import '../../view_model_harness.dart';

const _mentor = TestUser(id: 'user_3', name: 'Profe Ruiz', email: 'r@u.co');
const _outsider = TestUser(id: 'user_9', name: 'Ajeno', email: 'a@u.co');

/// Cannot read the board, to check that the rest of the project still loads.
class _UnreadableTaskSource extends InMemoryTaskSource {
  @override
  Future<List<ListingTask>> getTasks(String listingId) async =>
      throw StateError('listing_tasks');
}

const _leonel = ListingMember(
  userId: 'user_1',
  userName: 'Leonel Triana',
  role: ListingRole.leader,
);
const _mariana = ListingMember(
  userId: 'user_2',
  userName: 'Mariana Ospina',
  role: ListingRole.member,
);
const _profe = ListingMember(
  userId: 'user_3',
  userName: 'Profe Ruiz',
  role: ListingRole.mentor,
);

void main() {
  setUpViewModelTests();

  late ViewModelHarness harness;

  ListingDetailViewModel build() => ListingDetailViewModel(
        harness.listings,
        harness.engagement,
        harness.groups,
        harness.publisher,
        harness.session,
        harness.tasks,
      );

  Future<ListingDetailViewModel> open(String id) =>
      start(build(), routeId: id);

  setUp(() => harness = ViewModelHarness());

  /// Leonel leads, Mariana works, and user_3 mentors.
  Future<Listing> teamProject({ListingStatus status = ListingStatus.idea}) =>
      harness.listingSource.createListing(
        Listing(
          id: '',
          title: 'Bicicletas compartidas',
          description: 'Préstamo de bicicletas entre edificios del campus.',
          category: 'Tecnología',
          creatorId: 'user_1',
          creatorName: 'Leonel Triana',
          maxMembers: 6,
          requiredSkills: const [],
          memberIds: const ['user_1', 'user_2', 'user_3'],
          members: const [_leonel, _mariana, _profe],
          status: status,
        ),
      );

  Future<ListingTask> seedTask(
    String listingId, {
    String assigneeId = '',
    TaskColumn column = TaskColumn.todo,
  }) =>
      harness.taskSource.createTask(
        ListingTask(
          id: '',
          listingId: listingId,
          title: 'Tarea',
          assigneeId: assigneeId,
          assigneeName: assigneeId.isEmpty ? '' : 'Alguien',
          dueDate: null,
          column: column,
          createdById: 'user_1',
          createdAt: DateTime(2026, 10, 1),
        ),
      );

  group('el equipo', () {
    test('el líder se reconoce y ve a todo el equipo con su rol', () async {
      final project = await teamProject();

      final viewModel = await open(project.id);

      expect(viewModel.isLeader, isTrue);
      expect(viewModel.myRole, ListingRole.leader);
      expect(
        {for (final m in viewModel.team) m.userId: m.role},
        {
          'user_1': ListingRole.leader,
          'user_2': ListingRole.member,
          'user_3': ListingRole.mentor,
        },
      );
    });

    test('un integrante no es líder', () async {
      final project = await teamProject();
      harness.session.signInAs(TestUsers.mariana);

      final viewModel = await open(project.id);

      expect(viewModel.isLeader, isFalse);
      expect(viewModel.myRole, ListingRole.member);
    });

    test('alguien de afuera no tiene rol', () async {
      final project = await teamProject();
      harness.session.signInAs(_outsider);

      final viewModel = await open(project.id);

      expect(viewModel.myRole, isNull);
      expect(viewModel.isLeader, isFalse);
      expect(viewModel.team, hasLength(3));
    });

    test('sin proyecto cargado el equipo está vacío', () async {
      final viewModel = await open('ghost');

      expect(viewModel.team, isEmpty);
      expect(viewModel.isLeader, isFalse);
    });
  });

  group('progreso', () {
    test('cuenta las tareas hechas del proyecto', () async {
      final project = await teamProject();
      await seedTask(project.id, column: TaskColumn.done);
      await seedTask(project.id, column: TaskColumn.doing);
      await seedTask(project.id);
      await seedTask('listing_1', column: TaskColumn.done);

      final viewModel = await open(project.id);

      expect(viewModel.progress.value?.done, 1);
      expect(viewModel.progress.value?.total, 3);
    });

    test('si el tablero no se puede leer queda en null y el resto carga',
        () async {
      harness = ViewModelHarness(taskSource: _UnreadableTaskSource());
      final project = await teamProject();

      final viewModel = await open(project.id);

      expect(viewModel.progress.value, isNull);
      expect(viewModel.error.value, isNull);
      expect(viewModel.listing.value?.id, project.id);
      expect(viewModel.stats.value.views, 1);
      expect(viewModel.isLoading.value, isFalse);
    });
  });

  group('postularse según el estado', () {
    test('un proyecto pausado no admite postulaciones', () async {
      final project = await teamProject(status: ListingStatus.paused);
      harness.session.signInAs(_outsider);

      final viewModel = await open(project.id);

      expect(viewModel.canRequestToJoin, isFalse);
    });

    test('un proyecto terminado no admite postulaciones', () async {
      final project = await teamProject(status: ListingStatus.done);
      harness.session.signInAs(_outsider);

      final viewModel = await open(project.id);

      expect(viewModel.canRequestToJoin, isFalse);
    });

    test('uno en curso sí las admite', () async {
      final project = await teamProject(status: ListingStatus.inProgress);
      harness.session.signInAs(_outsider);

      final viewModel = await open(project.id);

      expect(viewModel.canRequestToJoin, isTrue);
    });
  });

  group('deleteListing', () {
    test('un integrante que no lidera no puede eliminarlo', () async {
      final project = await teamProject();
      await seedTask(project.id);
      harness.session.signInAs(TestUsers.mariana);
      final viewModel = await open(project.id);

      final deleted = await viewModel.deleteListing();

      expect(deleted, isFalse);
      expect(
        viewModel.error.value,
        'Solo el líder del proyecto puede eliminarlo.',
      );
      expect(await harness.listings.getListingById(project.id), isNotNull);
      expect(harness.taskSource.all, hasLength(1));
    });

    test('el líder lo elimina junto con sus tareas, y solo las suyas',
        () async {
      final project = await teamProject();
      await seedTask(project.id);
      await seedTask(project.id, column: TaskColumn.done);
      await seedTask('listing_1');
      final viewModel = await open(project.id);

      final deleted = await viewModel.deleteListing();

      expect(deleted, isTrue);
      expect(await harness.listings.getListingById(project.id), isNull);
      expect(
        harness.taskSource.all.map((task) => task.listingId),
        ['listing_1'],
      );
    });

    test('quien recibió el liderazgo puede eliminarlo sin haberlo creado',
        () async {
      final project = await harness.listingSource.createListing(
        const Listing(
          id: '',
          title: 'Radio universitaria',
          description: 'Una emisora hecha por estudiantes del campus.',
          category: 'Arte y Cultura',
          creatorId: 'user_2',
          creatorName: 'Mariana Ospina',
          maxMembers: 4,
          requiredSkills: [],
          memberIds: ['user_2', 'user_1'],
          members: [
            ListingMember(
              userId: 'user_2',
              userName: 'Mariana Ospina',
              role: ListingRole.member,
            ),
            _leonel,
          ],
        ),
      );
      final viewModel = await open(project.id);

      expect(viewModel.isCreator, isFalse);
      expect(await viewModel.deleteListing(), isTrue);
    });
  });

  group('removeMember', () {
    test('quita a la persona, libera sus tareas y le avisa', () async {
      final project = await teamProject();
      final hers = await seedTask(project.id, assigneeId: 'user_2');
      final mine = await seedTask(project.id, assigneeId: 'user_1');
      final viewModel = await open(project.id);

      final done = await viewModel.removeMember(_mariana);

      expect(done, isTrue);
      expect(viewModel.error.value, isNull);
      expect(viewModel.isWorking.value, isFalse);
      expect(viewModel.team.map((m) => m.userId), ['user_1', 'user_3']);

      final tasks = {for (final t in harness.taskSource.all) t.id: t};
      expect(tasks[hers.id]?.isAssigned, isFalse);
      expect(tasks[hers.id]?.assigneeName, '');
      expect(tasks[mine.id]?.assigneeId, 'user_1');

      final sent = harness.notificationSource.all;
      expect(sent, hasLength(1));
      expect(sent.single.type, NotificationType.memberRemoved);
      expect(sent.single.recipientId, 'user_2');
      expect(sent.single.targetId, project.id);
    });

    test('al líder no se le puede quitar', () async {
      final project = await teamProject();
      final viewModel = await open(project.id);

      final done = await viewModel.removeMember(_leonel);

      expect(done, isFalse);
      expect(
        viewModel.error.value,
        'No se puede quitar al líder. Transfiere el liderazgo primero.',
      );
      expect(viewModel.team, hasLength(3));
      expect(harness.notificationSource.all, isEmpty);
    });

    test('alguien que no lidera no puede quitar a nadie', () async {
      final project = await teamProject();
      await seedTask(project.id, assigneeId: 'user_3');
      harness.session.signInAs(TestUsers.mariana);
      final viewModel = await open(project.id);

      final done = await viewModel.removeMember(_profe);

      expect(done, isFalse);
      expect(
        viewModel.error.value,
        'Solo el líder del proyecto puede quitar integrantes.',
      );
      expect(harness.taskSource.all.single.assigneeId, 'user_3');
      expect(harness.notificationSource.all, isEmpty);
    });
  });

  group('leave', () {
    test('un integrante sale y sus tareas quedan libres', () async {
      final project = await teamProject();
      await seedTask(project.id, assigneeId: 'user_2');
      harness.session.signInAs(TestUsers.mariana);
      final viewModel = await open(project.id);

      final done = await viewModel.leave();

      expect(done, isTrue);
      expect(viewModel.myRole, isNull);
      expect(viewModel.isMember, isFalse);
      expect(harness.taskSource.all.single.isAssigned, isFalse);
    });

    test('el líder no puede salir sin transferir el liderazgo', () async {
      final project = await teamProject();
      await seedTask(project.id, assigneeId: 'user_1');
      final viewModel = await open(project.id);

      final done = await viewModel.leave();

      expect(done, isFalse);
      expect(
        viewModel.error.value,
        'Eres el líder: transfiere el liderazgo antes de salir del proyecto.',
      );
      expect(viewModel.isLeader, isTrue);
      expect(harness.taskSource.all.single.assigneeId, 'user_1');
    });
  });

  group('setRole', () {
    test('cambia el rol y le avisa a la persona', () async {
      final project = await teamProject();
      final viewModel = await open(project.id);

      final done = await viewModel.setRole(_mariana, ListingRole.mentor);

      expect(done, isTrue);
      expect(viewModel.listing.value?.roleOf('user_2'), ListingRole.mentor);

      final sent = harness.notificationSource.all;
      expect(sent, hasLength(1));
      expect(sent.single.type, NotificationType.roleChanged);
      expect(sent.single.recipientId, 'user_2');
      expect(sent.single.body, 'Ahora eres mentor del equipo.');
    });

    test('el mismo rol que ya tiene no escribe ni avisa', () async {
      final project = await teamProject();
      final viewModel = await open(project.id);

      final done = await viewModel.setRole(_mariana, ListingRole.member);

      expect(done, isFalse);
      expect(viewModel.error.value, isNull);
      expect(harness.notificationSource.all, isEmpty);
    });

    test('el liderazgo no se asigna como un rol', () async {
      final project = await teamProject();
      final viewModel = await open(project.id);

      final done = await viewModel.setRole(_mariana, ListingRole.leader);

      expect(done, isFalse);
      expect(viewModel.error.value, contains('Transferir liderazgo'));
      expect(viewModel.listing.value?.leaderId, 'user_1');
      expect(harness.notificationSource.all, isEmpty);
    });
  });

  group('transferLeadership', () {
    test('los roles se intercambian y se avisa al nuevo líder', () async {
      final project = await teamProject();
      final viewModel = await open(project.id);

      final done = await viewModel.transferLeadership(_mariana);

      expect(done, isTrue);
      expect(viewModel.isLeader, isFalse);
      expect(viewModel.myRole, ListingRole.member);
      expect(viewModel.listing.value?.leaderId, 'user_2');
      expect(
        viewModel.team.where((m) => m.role == ListingRole.leader),
        hasLength(1),
      );

      final sent = harness.notificationSource.all;
      expect(sent, hasLength(1));
      expect(sent.single.type, NotificationType.roleChanged);
      expect(sent.single.recipientId, 'user_2');
      expect(sent.single.title, 'Ahora lideras "Bicicletas compartidas"');
    });

    test('el antiguo líder ya no puede eliminar el proyecto', () async {
      final project = await teamProject();
      final viewModel = await open(project.id);
      await viewModel.transferLeadership(_mariana);

      expect(await viewModel.deleteListing(), isFalse);
      expect(await harness.listings.getListingById(project.id), isNotNull);
    });

    test('alguien que no lidera no puede transferirlo', () async {
      final project = await teamProject();
      harness.session.signInAs(_mentor);
      final viewModel = await open(project.id);

      final done = await viewModel.transferLeadership(_mariana);

      expect(done, isFalse);
      expect(
        viewModel.error.value,
        'Solo el líder del proyecto puede transferir el liderazgo.',
      );
      expect(viewModel.listing.value?.leaderId, 'user_1');
    });
  });
}
