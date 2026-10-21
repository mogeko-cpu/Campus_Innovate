import 'package:campus_innovate/features/listings/data/repositories/task_repository.dart';
import 'package:campus_innovate/features/listings/domain/listing_exception.dart';
import 'package:campus_innovate/features/listings/domain/models/listing_task.dart';
import 'package:campus_innovate/features/listings/domain/models/task_column.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/in_memory_task_source.dart';

void main() {
  late _CountingTaskSource source;
  late TaskRepository repository;

  setUp(() {
    source = _CountingTaskSource();
    repository = TaskRepository(source);
  });

  ListingTask draft(
    String title, {
    String listingId = 'listing_1',
    String assigneeId = '',
    DateTime? dueDate,
    DateTime? createdAt,
  }) =>
      ListingTask.draft(
        listingId: listingId,
        title: title,
        createdById: 'user_1',
        assigneeId: assigneeId,
        assigneeName: assigneeId.isEmpty ? '' : 'Nombre de $assigneeId',
        dueDate: dueDate,
        createdAt: createdAt ?? DateTime(2026, 10, 1),
      );

  Matcher refusal(String message) => throwsA(
        isA<ListingException>().having(
          (error) => error.message,
          'message',
          contains(message),
        ),
      );

  group('getTasks', () {
    test('ordena por columna, luego por fecha límite y luego por antigüedad',
        () async {
      // Stored deliberately out of order: ROBLE gives no order either.
      final undatedOld = await repository.createTask(
        draft('Sin fecha vieja', createdAt: DateTime(2026, 9, 1)),
      );
      final doing = await repository.createTask(draft('En curso'));
      await repository.moveTask(doing, TaskColumn.doing);
      final later = await repository.createTask(
        draft('Vence tarde', dueDate: DateTime(2026, 12, 1)),
      );
      final undatedNew = await repository.createTask(
        draft('Sin fecha nueva', createdAt: DateTime(2026, 9, 20)),
      );
      final done = await repository.createTask(
        draft('Hecha', dueDate: DateTime(2026, 1, 1)),
      );
      await repository.moveTask(done, TaskColumn.done);
      final soon = await repository.createTask(
        draft('Vence pronto', dueDate: DateTime(2026, 10, 25)),
      );
      final soonOlder = await repository.createTask(
        draft(
          'Vence pronto, creada antes',
          dueDate: DateTime(2026, 10, 25),
          createdAt: DateTime(2026, 8, 1),
        ),
      );

      final tasks = await repository.getTasks('listing_1');

      expect(tasks.map((task) => task.id), [
        soonOlder.id,
        soon.id,
        later.id,
        undatedOld.id,
        undatedNew.id,
        doing.id,
        done.id,
      ]);
    });

    test('solo trae las tareas de ese proyecto', () async {
      await repository.createTask(draft('Mía'));
      await repository.createTask(draft('Ajena', listingId: 'listing_2'));

      final tasks = await repository.getTasks('listing_1');

      expect(tasks.map((task) => task.title), ['Mía']);
    });

    test('un proyecto sin tareas da un tablero vacío', () async {
      expect(await repository.getTasks('listing_1'), isEmpty);
    });
  });

  group('createTask', () {
    test('guarda la tarea con el título recortado y espacios colapsados',
        () async {
      final created = await repository.createTask(
        draft('   Diseñar \n  el    logo  '),
      );

      expect(created.isPersisted, isTrue);
      expect(created.title, 'Diseñar el logo');
      expect(source.all.single.title, 'Diseñar el logo');
      expect(source.all.single.column, TaskColumn.todo);
    });

    test('un título de menos de 3 caracteres no se guarda', () async {
      // `createTask` validates before it has a future to return, so the
      // refusal is thrown synchronously; a closure catches it either way.
      expect(
        () => repository.createTask(draft('  ab   ')),
        refusal('Escribe un título de al menos 3 caracteres.'),
      );

      expect(source.all, isEmpty);
    });

    test('los espacios colapsados cuentan como uno', () async {
      // "a     b" is "a b" once collapsed: three characters, enough.
      final created = await repository.createTask(draft('a     b'));

      expect(created.title, 'a b');
    });

    test('se aceptan hasta 120 caracteres y no uno más', () async {
      final longest = await repository.createTask(draft('x' * 120));
      expect(longest.title, hasLength(120));

      expect(
        () => repository.createTask(draft('x' * 121)),
        refusal('El título es muy largo. Máximo 120 caracteres.'),
      );

      expect(source.all, hasLength(1));
    });

    test('el largo se mide después de colapsar los espacios', () async {
      final created = await repository.createTask(
        draft('${'x' * 60}          ${'y' * 59}'),
      );

      expect(created.title, hasLength(120));
    });
  });

  group('updateTask', () {
    test('guarda y devuelve la tarea con el título limpio', () async {
      final created = await repository.createTask(draft('Diseñar el logo'));

      final updated = await repository.updateTask(
        created.copyWith(
          title: '  Logo   final ',
          assigneeId: 'user_2',
          assigneeName: 'Mariana',
          dueDate: DateTime(2026, 11, 15),
        ),
      );

      expect(updated.title, 'Logo final');
      expect(source.all.single.title, 'Logo final');
      expect(source.all.single.assigneeId, 'user_2');
      expect(source.all.single.dueDate, DateTime(2026, 11, 15));
    });

    test('un título inválido no toca lo guardado', () async {
      final created = await repository.createTask(draft('Diseñar el logo'));

      await expectLater(
        repository.updateTask(created.copyWith(title: ' ')),
        refusal('al menos 3 caracteres'),
      );

      expect(source.all.single.title, 'Diseñar el logo');
    });

    test('quitar la fecha límite se guarda', () async {
      final created = await repository.createTask(
        draft('Entregar', dueDate: DateTime(2026, 11, 15)),
      );

      await repository.updateTask(created.copyWith(clearDueDate: true));

      expect(source.all.single.dueDate, isNull);
    });
  });

  group('moveTask', () {
    test('mueve la tarea a la otra columna y la guarda', () async {
      final created = await repository.createTask(draft('Diseñar el logo'));

      final moved = await repository.moveTask(created, TaskColumn.doing);

      expect(moved.column, TaskColumn.doing);
      expect(moved.id, created.id);
      expect(source.all.single.column, TaskColumn.doing);
    });

    test('a la misma columna no escribe nada', () async {
      final created = await repository.createTask(draft('Diseñar el logo'));

      final same = await repository.moveTask(created, TaskColumn.todo);

      expect(identical(same, created), isTrue);
      expect(source.updates, 0);
    });

    test('mover una tarea borrada se informa', () async {
      final created = await repository.createTask(draft('Diseñar el logo'));
      await repository.deleteTask(created.id);

      await expectLater(
        repository.moveTask(created, TaskColumn.done),
        throwsA(isA<ListingException>()),
      );
    });
  });

  test('deleteTask borra solo esa tarea', () async {
    final first = await repository.createTask(draft('Primera'));
    await repository.createTask(draft('Segunda'));

    await repository.deleteTask(first.id);

    expect(source.all.map((task) => task.title), ['Segunda']);
  });

  group('unassignAll', () {
    test('libera las tareas de esa persona en ese proyecto y las cuenta',
        () async {
      await repository.createTask(draft('Una', assigneeId: 'user_3'));
      await repository.createTask(draft('Otra', assigneeId: 'user_3'));
      await repository.createTask(draft('De Ana', assigneeId: 'user_4'));
      await repository.createTask(
        draft('En otro proyecto', listingId: 'listing_2', assigneeId: 'user_3'),
      );

      final freed = await repository.unassignAll(
        listingId: 'listing_1',
        userId: 'user_3',
      );

      expect(freed, 2);

      final byTitle = {for (final task in source.all) task.title: task};
      expect(byTitle['Una']!.isAssigned, isFalse);
      expect(byTitle['Una']!.assigneeName, isEmpty);
      expect(byTitle['Otra']!.isAssigned, isFalse);
      expect(byTitle['De Ana']!.assigneeId, 'user_4');
      // Leaving one project does not touch the board of another.
      expect(byTitle['En otro proyecto']!.assigneeId, 'user_3');
    });

    test('sin tareas suyas devuelve 0 y no escribe', () async {
      await repository.createTask(draft('De Ana', assigneeId: 'user_4'));

      final freed = await repository.unassignAll(
        listingId: 'listing_1',
        userId: 'user_3',
      );

      expect(freed, 0);
      expect(source.updates, 0);
    });
  });

  group('progressOf', () {
    test('cuenta las terminadas de ese proyecto', () async {
      final a = await repository.createTask(draft('Una'));
      await repository.createTask(draft('Otra'));
      await repository.createTask(draft('Tercera'));
      await repository.moveTask(a, TaskColumn.done);
      final elsewhere = await repository.createTask(
        draft('Ajena', listingId: 'listing_2'),
      );
      await repository.moveTask(elsewhere, TaskColumn.done);

      final progress = await repository.progressOf('listing_1');

      expect(progress.done, 1);
      expect(progress.total, 3);
      expect(progress.label, '1 de 3 tareas hechas');
    });

    test('un proyecto sin tareas es 0 de 0', () async {
      final progress = await repository.progressOf('listing_1');

      expect(progress.total, 0);
      expect(progress.fraction, 0);
    });
  });

  test('purgeListing borra el tablero de ese proyecto y no el de otros',
      () async {
    await repository.createTask(draft('Una'));
    await repository.createTask(draft('Otra'));
    await repository.createTask(draft('Ajena', listingId: 'listing_2'));

    await repository.purgeListing('listing_1');

    expect(source.all.map((task) => task.title), ['Ajena']);
  });
}

/// Counts the writes, so "nothing was written" is something a test can see.
class _CountingTaskSource extends InMemoryTaskSource {
  int updates = 0;

  @override
  Future<void> updateTask(ListingTask task) {
    updates++;

    return super.updateTask(task);
  }
}
