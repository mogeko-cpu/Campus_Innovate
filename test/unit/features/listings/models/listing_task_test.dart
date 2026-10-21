import 'package:campus_innovate/features/listings/domain/models/listing_task.dart';
import 'package:campus_innovate/features/listings/domain/models/task_column.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final created = DateTime(2026, 10, 1, 9, 30);

  ListingTask task({
    String id = 'task_1',
    String assigneeId = '',
    DateTime? dueDate,
    TaskColumn column = TaskColumn.todo,
  }) =>
      ListingTask(
        id: id,
        listingId: 'listing_1',
        title: 'Diseñar el logo',
        assigneeId: assigneeId,
        assigneeName: assigneeId.isEmpty ? '' : 'Ana',
        dueDate: dueDate,
        column: column,
        createdById: 'user_1',
        createdAt: created,
      );

  group('ListingTask.draft', () {
    test('nace sin id, en "Por hacer" y sin asignar', () {
      final draft = ListingTask.draft(
        listingId: 'listing_1',
        title: 'Diseñar el logo',
        createdById: 'user_1',
        createdAt: created,
      );

      expect(draft.id, isEmpty);
      expect(draft.isPersisted, isFalse);
      expect(draft.column, TaskColumn.todo);
      expect(draft.isAssigned, isFalse);
      expect(draft.assigneeName, isEmpty);
      expect(draft.dueDate, isNull);
      expect(draft.createdAt, created);
    });

    test('la fecha límite pierde la hora: es un día, no un momento', () {
      final draft = ListingTask.draft(
        listingId: 'listing_1',
        title: 'Entregar',
        createdById: 'user_1',
        dueDate: DateTime(2026, 11, 15, 23, 59, 59),
      );

      expect(draft.dueDate, DateTime(2026, 11, 15));
    });

    test('sin fecha de creación se fecha en el momento', () {
      final before = DateTime.now();
      final draft = ListingTask.draft(
        listingId: 'listing_1',
        title: 'Entregar',
        createdById: 'user_1',
      );
      final after = DateTime.now();

      expect(draft.createdAt.isBefore(before), isFalse);
      expect(draft.createdAt.isAfter(after), isFalse);
    });
  });

  test('isPersisted, isAssigned e isDone leen el estado de la fila', () {
    final stored = task(assigneeId: 'user_2', column: TaskColumn.done);

    expect(stored.isPersisted, isTrue);
    expect(stored.isAssigned, isTrue);
    expect(stored.isDone, isTrue);
    expect(task(column: TaskColumn.doing).isDone, isFalse);
  });

  group('isOverdue', () {
    final now = DateTime(2026, 11, 15, 18, 0);

    test('sin fecha límite nunca está atrasada', () {
      expect(task().isOverdue(now), isFalse);
    });

    test('vencida ayer y sin terminar está atrasada', () {
      expect(task(dueDate: DateTime(2026, 11, 14)).isOverdue(now), isTrue);
    });

    test('la que vence hoy todavía no está atrasada, aunque sea tarde', () {
      final lateAtNight = DateTime(2026, 11, 15, 23, 59);

      expect(task(dueDate: DateTime(2026, 11, 15)).isOverdue(lateAtNight),
          isFalse);
    });

    test('una futura no está atrasada', () {
      expect(task(dueDate: DateTime(2026, 11, 20)).isOverdue(now), isFalse);
    });

    test('una terminada no está atrasada aunque su día ya pasó', () {
      final done = task(dueDate: DateTime(2026, 1, 1), column: TaskColumn.done);

      expect(done.isOverdue(now), isFalse);
    });
  });

  test('dateOnly iguala dos momentos del mismo día', () {
    final morning = ListingTask.dateOnly(DateTime(2026, 3, 9, 0, 0, 1));
    final night = ListingTask.dateOnly(DateTime(2026, 3, 9, 23, 59, 59, 999));

    expect(morning, night);
    expect(morning, DateTime(2026, 3, 9));
  });

  group('copyWith', () {
    test('cambia lo pedido y conserva lista, autor y fecha de creación', () {
      final moved = task().copyWith(
        id: 'task_9',
        title: 'Logo final',
        assigneeId: 'user_3',
        assigneeName: 'Carlos',
        column: TaskColumn.doing,
      );

      expect(moved.id, 'task_9');
      expect(moved.title, 'Logo final');
      expect(moved.assigneeId, 'user_3');
      expect(moved.assigneeName, 'Carlos');
      expect(moved.column, TaskColumn.doing);
      expect(moved.listingId, 'listing_1');
      expect(moved.createdById, 'user_1');
      expect(moved.createdAt, created);
    });

    test('sin fecha nueva conserva la que tenía', () {
      final dated = task(dueDate: DateTime(2026, 11, 15));

      expect(dated.copyWith(title: 'Otro').dueDate, DateTime(2026, 11, 15));
    });

    test('una fecha nueva también pierde la hora', () {
      final dated = task().copyWith(dueDate: DateTime(2026, 12, 1, 14, 45));

      expect(dated.dueDate, DateTime(2026, 12, 1));
    });

    test('clearDueDate quita la fecha, cosa que null no puede', () {
      final dated = task(dueDate: DateTime(2026, 11, 15));

      expect(dated.copyWith(dueDate: null).dueDate, isNotNull);
      expect(dated.copyWith(clearDueDate: true).dueDate, isNull);
    });

    test('clearDueDate gana sobre una fecha pasada a la vez', () {
      final cleared = task().copyWith(
        dueDate: DateTime(2026, 11, 15),
        clearDueDate: true,
      );

      expect(cleared.dueDate, isNull);
    });

    test('desasignar es pasar cadenas vacías', () {
      final unassigned = task(assigneeId: 'user_2')
          .copyWith(assigneeId: '', assigneeName: '');

      expect(unassigned.isAssigned, isFalse);
      expect(unassigned.assigneeName, isEmpty);
    });
  });

  group('TaskProgress', () {
    test('cuenta las terminadas sobre el total', () {
      final progress = TaskProgress.of([
        task(id: 'a', column: TaskColumn.done),
        task(id: 'b', column: TaskColumn.doing),
        task(id: 'c', column: TaskColumn.todo),
        task(id: 'd', column: TaskColumn.done),
      ]);

      expect(progress.done, 2);
      expect(progress.total, 4);
      expect(progress.fraction, 0.5);
      expect(progress.label, '2 de 4 tareas hechas');
    });

    test('un tablero vacío es 0 de 0 y su fracción es 0, no NaN', () {
      final progress = TaskProgress.of(const []);

      expect(progress.done, 0);
      expect(progress.total, 0);
      expect(progress.fraction, 0);
      expect(progress.label, '0 de 0 tareas hechas');
    });

    test('empty equivale a un tablero sin tareas', () {
      expect(TaskProgress.empty.done, 0);
      expect(TaskProgress.empty.total, 0);
      expect(TaskProgress.empty.fraction, 0);
    });

    test('con una sola tarea la etiqueta va en singular', () {
      expect(TaskProgress.of([task()]).label, '0 de 1 tarea hecha');
      expect(
        TaskProgress.of([task(column: TaskColumn.done)]).label,
        '1 de 1 tarea hecha',
      );
    });

    test('todo terminado es la fracción completa', () {
      final progress = TaskProgress.of([
        task(id: 'a', column: TaskColumn.done),
        task(id: 'b', column: TaskColumn.done),
        task(id: 'c', column: TaskColumn.done),
      ]);

      expect(progress.fraction, 1);
      expect(progress.label, '3 de 3 tareas hechas');
    });
  });
}
