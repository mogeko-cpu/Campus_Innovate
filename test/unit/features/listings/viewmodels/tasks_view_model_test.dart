import 'package:campus_innovate/features/listings/domain/models/listing.dart';
import 'package:campus_innovate/features/listings/domain/models/listing_member.dart';
import 'package:campus_innovate/features/listings/domain/models/listing_role.dart';
import 'package:campus_innovate/features/listings/domain/models/listing_task.dart';
import 'package:campus_innovate/features/listings/domain/models/task_column.dart';
import 'package:campus_innovate/features/listings/ui/viewmodels/tasks_view_model.dart';
import 'package:campus_innovate/features/notifications/domain/models/notification_type.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/in_memory_task_source.dart';
import '../../../../support/test_session.dart';
import '../../view_model_harness.dart';

const _mentor = TestUser(id: 'user_3', name: 'Profe Ruiz', email: 'r@u.co');
const _outsider = TestUser(id: 'user_9', name: 'Ajeno', email: 'a@u.co');

/// Refuses every write, to check that a failed action leaves the board alone.
class _FailingWritesTaskSource extends InMemoryTaskSource {
  @override
  Future<void> updateTask(ListingTask task) async =>
      throw StateError('listing_tasks');
}

void main() {
  setUpViewModelTests();

  late ViewModelHarness harness;
  late Listing project;

  TasksViewModel build() => TasksViewModel(
        harness.tasks,
        harness.listings,
        harness.publisher,
        harness.session,
      );

  Future<TasksViewModel> open([String? id]) =>
      start(build(), routeId: id ?? project.id);

  /// Leonel leads, Mariana works, and user_3 mentors.
  Future<Listing> seedProject() => harness.listingSource.createListing(
        const Listing(
          id: '',
          title: 'Bicicletas compartidas',
          description: 'Préstamo de bicicletas entre edificios del campus.',
          category: 'Tecnología',
          creatorId: 'user_1',
          creatorName: 'Leonel Triana',
          maxMembers: 5,
          requiredSkills: [],
          memberIds: ['user_1', 'user_2', 'user_3'],
          members: [
            ListingMember(
              userId: 'user_1',
              userName: 'Leonel Triana',
              role: ListingRole.leader,
            ),
            ListingMember(
              userId: 'user_2',
              userName: 'Mariana Ospina',
              role: ListingRole.member,
            ),
            ListingMember(
              userId: 'user_3',
              userName: 'Profe Ruiz',
              role: ListingRole.mentor,
            ),
          ],
        ),
      );

  Future<ListingTask> seedTask({
    String title = 'Comprar candados',
    String createdById = 'user_1',
    String assigneeId = '',
    String assigneeName = '',
    TaskColumn column = TaskColumn.todo,
    DateTime? dueDate,
  }) =>
      harness.taskSource.createTask(
        ListingTask(
          id: '',
          listingId: project.id,
          title: title,
          assigneeId: assigneeId,
          assigneeName: assigneeName,
          dueDate: dueDate,
          column: column,
          createdById: createdById,
          createdAt: DateTime(2026, 10, 1),
        ),
      );

  List<NotificationType?> sentTypes() =>
      harness.notificationSource.all.map((item) => item.type).toList();

  setUp(() async {
    harness = ViewModelHarness();
    project = await seedProject();
  });

  group('carga', () {
    test('un id inexistente dice que no se encontró', () async {
      final viewModel = await open('ghost');

      expect(viewModel.error.value, 'Proyecto no encontrado');
      expect(viewModel.listing.value, isNull);
      expect(viewModel.isLoading.value, isFalse);
    });

    test('alguien de afuera no ve el tablero', () async {
      await seedTask();
      harness.session.signInAs(_outsider);

      final viewModel = await open();

      expect(
        viewModel.error.value,
        'Solo el equipo del proyecto puede ver sus tareas.',
      );
      expect(viewModel.tasks, isEmpty);
      expect(viewModel.canWork, isFalse);
    });

    test('el equipo ve las tareas del proyecto', () async {
      await seedTask();

      final viewModel = await open();

      expect(viewModel.error.value, isNull);
      expect(viewModel.tasks.map((t) => t.title), ['Comprar candados']);
    });

    test('el mentor también ve el tablero', () async {
      await seedTask();
      harness.session.signInAs(_mentor);

      final viewModel = await open();

      expect(viewModel.error.value, isNull);
      expect(viewModel.tasks, hasLength(1));
    });
  });

  group('permisos', () {
    test('el líder trabaja el tablero', () async {
      final viewModel = await open();

      expect(viewModel.myRole, ListingRole.leader);
      expect(viewModel.canWork, isTrue);
    });

    test('un integrante trabaja el tablero', () async {
      harness.session.signInAs(TestUsers.mariana);

      final viewModel = await open();

      expect(viewModel.myRole, ListingRole.member);
      expect(viewModel.canWork, isTrue);
    });

    test('el mentor lo sigue sin trabajarlo', () async {
      harness.session.signInAs(_mentor);

      final viewModel = await open();

      expect(viewModel.myRole, ListingRole.mentor);
      expect(viewModel.canWork, isFalse);
    });

    test('el líder puede borrar cualquier tarea', () async {
      final theirs = await seedTask(createdById: 'user_2');

      final viewModel = await open();

      expect(viewModel.canDelete(theirs), isTrue);
    });

    test('un integrante borra solo las que creó', () async {
      final mine = await seedTask(createdById: 'user_2');
      final theirs = await seedTask(createdById: 'user_1');
      harness.session.signInAs(TestUsers.mariana);

      final viewModel = await open();

      expect(viewModel.canDelete(mine), isTrue);
      expect(viewModel.canDelete(theirs), isFalse);
    });

    test('el mentor no borra nada, ni lo que figure a su nombre', () async {
      final own = await seedTask(createdById: 'user_3');
      harness.session.signInAs(_mentor);

      final viewModel = await open();

      expect(viewModel.canDelete(own), isFalse);
    });

    test('solo se puede asignar a quienes trabajan el tablero', () async {
      final viewModel = await open();

      expect(
        viewModel.assignable.map((member) => member.userId),
        ['user_1', 'user_2'],
      );
    });
  });

  group('columnas y progreso', () {
    test('tasksIn reparte por columna y progress cuenta las hechas', () async {
      await seedTask(title: 'Uno');
      await seedTask(title: 'Dos', column: TaskColumn.doing);
      await seedTask(title: 'Tres', column: TaskColumn.done);
      await seedTask(title: 'Cuatro', column: TaskColumn.done);

      final viewModel = await open();

      expect(viewModel.tasksIn(TaskColumn.todo).map((t) => t.title), ['Uno']);
      expect(viewModel.tasksIn(TaskColumn.doing).map((t) => t.title), ['Dos']);
      expect(viewModel.tasksIn(TaskColumn.done), hasLength(2));
      expect(viewModel.progress.done, 2);
      expect(viewModel.progress.total, 4);
    });

    test('un tablero vacío tiene progreso cero', () async {
      final viewModel = await open();

      expect(viewModel.progress.total, 0);
      expect(viewModel.progress.fraction, 0);
    });
  });

  group('create', () {
    test('crea la tarea en Por hacer y avisa a quien la recibe', () async {
      final viewModel = await open();

      final done = await viewModel.create(
        title: '  Pintar   el logo ',
        assigneeId: 'user_2',
        dueDate: DateTime(2026, 11, 3, 15, 30),
      );

      expect(done, isTrue);
      expect(viewModel.lastActionError, isNull);
      expect(viewModel.busyTaskId.value, isNull);

      final task = viewModel.tasks.single;
      expect(task.title, 'Pintar el logo');
      expect(task.column, TaskColumn.todo);
      expect(task.assigneeId, 'user_2');
      expect(task.assigneeName, 'Mariana Ospina');
      expect(task.createdById, 'user_1');
      expect(task.dueDate, DateTime(2026, 11, 3));

      final sent = harness.notificationSource.all;
      expect(sent, hasLength(1));
      expect(sent.single.type, NotificationType.taskAssigned);
      expect(sent.single.recipientId, 'user_2');
      expect(sent.single.targetId, project.id);
    });

    test('asignársela a uno mismo no genera aviso', () async {
      final viewModel = await open();

      await viewModel.create(title: 'Mi tarea', assigneeId: 'user_1');

      expect(viewModel.tasks.single.assigneeId, 'user_1');
      expect(harness.notificationSource.all, isEmpty);
    });

    test('sin asignar no avisa a nadie', () async {
      final viewModel = await open();

      await viewModel.create(title: 'Libre');

      expect(viewModel.tasks.single.isAssigned, isFalse);
      expect(harness.notificationSource.all, isEmpty);
    });

    test('a un mentor no se le asigna: la tarea queda libre', () async {
      final viewModel = await open();

      await viewModel.create(title: 'Revisar', assigneeId: 'user_3');

      expect(viewModel.tasks.single.isAssigned, isFalse);
      expect(harness.notificationSource.all, isEmpty);
    });

    test('un título inválido deja el error sin tocar el tablero', () async {
      final viewModel = await open();

      final done = await viewModel.create(title: ' a ');

      expect(done, isFalse);
      expect(
        viewModel.lastActionError,
        'Escribe un título de al menos 3 caracteres.',
      );
      expect(viewModel.error.value, isNull);
      expect(viewModel.tasks, isEmpty);
      expect(harness.taskSource.all, isEmpty);
      expect(viewModel.busyTaskId.value, isNull);
    });

    test('el mentor no puede crear', () async {
      harness.session.signInAs(_mentor);
      final viewModel = await open();

      expect(await viewModel.create(title: 'Consejo'), isFalse);
      expect(harness.taskSource.all, isEmpty);
    });
  });

  group('edit', () {
    test('cambiar de responsable avisa al nuevo', () async {
      final task = await seedTask(assigneeId: 'user_1');
      final viewModel = await open();

      final done = await viewModel.edit(
        task,
        title: task.title,
        assigneeId: 'user_2',
        dueDate: null,
      );

      expect(done, isTrue);
      expect(viewModel.tasks.single.assigneeName, 'Mariana Ospina');
      expect(sentTypes(), [NotificationType.taskAssigned]);
      expect(harness.notificationSource.all.single.recipientId, 'user_2');
    });

    test('mantener el responsable no vuelve a avisar', () async {
      final task = await seedTask(
        assigneeId: 'user_2',
        assigneeName: 'Mariana Ospina',
      );
      final viewModel = await open();

      await viewModel.edit(
        task,
        title: 'Comprar candados buenos',
        assigneeId: 'user_2',
        dueDate: null,
      );

      expect(viewModel.tasks.single.title, 'Comprar candados buenos');
      expect(harness.notificationSource.all, isEmpty);
    });

    test('dejar la fecha vacía la borra', () async {
      final task = await seedTask(dueDate: DateTime(2026, 11, 3));
      final viewModel = await open();

      await viewModel.edit(
        task,
        title: task.title,
        assigneeId: '',
        dueDate: null,
      );

      expect(viewModel.tasks.single.dueDate, isNull);
      expect(harness.taskSource.all.single.dueDate, isNull);
    });

    test('un título inválido no guarda nada', () async {
      final task = await seedTask();
      final viewModel = await open();

      final done = await viewModel.edit(
        task,
        title: '',
        assigneeId: '',
        dueDate: null,
      );

      expect(done, isFalse);
      expect(viewModel.lastActionError, isNotNull);
      expect(harness.taskSource.all.single.title, 'Comprar candados');
    });

    test('el mentor no puede editar', () async {
      final task = await seedTask();
      harness.session.signInAs(_mentor);
      final viewModel = await open();

      final done = await viewModel.edit(
        task,
        title: 'Otro título',
        assigneeId: '',
        dueDate: null,
      );

      expect(done, isFalse);
      expect(harness.taskSource.all.single.title, 'Comprar candados');
    });
  });

  group('move', () {
    test('pasa la tarea a otra columna', () async {
      final task = await seedTask();
      final viewModel = await open();

      final done = await viewModel.move(task, TaskColumn.doing);

      expect(done, isTrue);
      expect(viewModel.tasksIn(TaskColumn.doing).single.id, task.id);
      expect(viewModel.tasksIn(TaskColumn.todo), isEmpty);
    });

    test('si falla la escritura queda el error y el tablero sigue', () async {
      harness = ViewModelHarness(taskSource: _FailingWritesTaskSource());
      project = await seedProject();
      final task = await seedTask();
      final viewModel = await open();

      final done = await viewModel.move(task, TaskColumn.done);

      expect(done, isFalse);
      expect(viewModel.lastActionError, 'No se pudo mover la tarea');
      expect(viewModel.error.value, isNull);
      expect(viewModel.tasksIn(TaskColumn.todo).single.id, task.id);
      expect(viewModel.busyTaskId.value, isNull);
    });

    test('el mentor no mueve tarjetas', () async {
      final task = await seedTask();
      harness.session.signInAs(_mentor);
      final viewModel = await open();

      expect(await viewModel.move(task, TaskColumn.done), isFalse);
      expect(harness.taskSource.all.single.column, TaskColumn.todo);
    });
  });

  group('delete', () {
    test('quien la creó la borra', () async {
      final task = await seedTask(createdById: 'user_2');
      harness.session.signInAs(TestUsers.mariana);
      final viewModel = await open();

      expect(await viewModel.delete(task), isTrue);
      expect(viewModel.tasks, isEmpty);
      expect(harness.taskSource.all, isEmpty);
    });

    test('un integrante no borra la de otro', () async {
      final task = await seedTask(createdById: 'user_1');
      harness.session.signInAs(TestUsers.mariana);
      final viewModel = await open();

      expect(await viewModel.delete(task), isFalse);
      expect(harness.taskSource.all, hasLength(1));
    });
  });

  group('busyTaskId', () {
    test('marca la tarjeta en curso y bloquea otra acción hasta terminar',
        () async {
      final task = await seedTask();
      final other = await seedTask(title: 'Otra');
      final viewModel = await open();

      final moving = viewModel.move(task, TaskColumn.doing);

      expect(viewModel.busyTaskId.value, task.id);
      expect(await viewModel.move(other, TaskColumn.done), isFalse);
      expect(await viewModel.create(title: 'Nueva'), isFalse);

      expect(await moving, isTrue);
      expect(viewModel.busyTaskId.value, isNull);
      expect(viewModel.tasksIn(TaskColumn.done), isEmpty);
      expect(viewModel.tasks, hasLength(2));
    });

    test('crear bloquea con un id vacío, no con null', () async {
      final viewModel = await open();

      final creating = viewModel.create(title: 'Nueva');

      expect(viewModel.busyTaskId.value, '');

      await creating;
      expect(viewModel.busyTaskId.value, isNull);
    });
  });
}
