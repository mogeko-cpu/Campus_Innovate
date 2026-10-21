import 'package:campus_innovate/core/roble/roble_client.dart';
import 'package:campus_innovate/core/roble/roble_session.dart';
import 'package:campus_innovate/core/roble/roble_user.dart';
import 'package:campus_innovate/features/listings/data/datasources/remote/roble_task_source.dart';
import 'package:campus_innovate/features/listings/domain/listing_exception.dart';
import 'package:campus_innovate/features/listings/domain/models/listing_task.dart';
import 'package:campus_innovate/features/listings/domain/models/task_column.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../../support/fake_roble_api.dart';
import '../../../support/memory_preferences.dart';

/// One row per card in `listing_tasks`, with the due date stored as the day
/// alone so no time zone can move it.
void main() {
  const contract = 'contrato_test';

  late FakeRobleApi api;
  late RobleTaskSource source;
  late String listingId;

  Future<RobleTaskSource> sourceOn(http.Client client) async {
    final session = RobleSession(MemoryPreferences());
    await session.save(
      accessToken: 'access-1',
      refreshToken: null,
      user: const RobleUser(
        id: 'user-1',
        email: 'ana@uninorte.edu.co',
        name: 'Ana Pérez',
      ),
    );

    return RobleTaskSource(
      RobleClient(
        session: session,
        httpClient: client,
        baseUrl: 'https://roble-api.test',
        contractId: contract,
      ),
    );
  }

  setUp(() async {
    api = FakeRobleApi(contractId: contract);
    source = await sourceOn(api.client);
    listingId = api.seed('listings', {'title': 'Huerta'})['_id'] as String;
  });

  List<Map<String, dynamic>> rows() => api.rowsOf('listing_tasks');

  ListingTask draft({DateTime? dueDate, String assigneeId = ''}) =>
      ListingTask.draft(
        listingId: listingId,
        title: 'Preparar el terreno',
        createdById: 'user-1',
        assigneeId: assigneeId,
        assigneeName: assigneeId.isEmpty ? '' : 'Carlos',
        dueDate: dueDate,
        createdAt: DateTime.utc(2026, 10, 1, 15, 30),
      );

  void seedTask(Map<String, dynamic> record) => api.seed('listing_tasks', {
        'listing_id': listingId,
        'title': 'Tarea',
        'assignee_id': '',
        'assignee_name': '',
        'status': 'todo',
        'created_by': 'user-1',
        'created_at': '2026-10-01T15:30:00.000Z',
        ...record,
      });

  group('createTask', () {
    test('escribe una fila con la fecha límite como AAAA-MM-DD', () async {
      final created = await source.createTask(
        draft(dueDate: DateTime(2026, 3, 7, 22, 15), assigneeId: 'user-3'),
      );

      expect(created.isPersisted, isTrue);
      expect(created.id, rows().single['_id']);

      final row = rows().single;
      expect(row['listing_id'], listingId);
      expect(row['title'], 'Preparar el terreno');
      expect(row['assignee_id'], 'user-3');
      expect(row['assignee_name'], 'Carlos');
      // Month and day padded, no time: the column is plain text.
      expect(row['due_date'], '2026-03-07');
      expect(row['status'], 'todo');
      expect(row['created_by'], 'user-1');
      expect(row['created_at'], '2026-10-01T15:30:00.000Z');
    });

    test('sin fecha límite la columna queda nula', () async {
      await source.createTask(draft());

      expect(rows().single['due_date'], isNull);
    });

    test('si ROBLE no devuelve el id se informa', () async {
      final noId = await sourceOn(
        MockClient((request) async {
          if (request.url.pathSegments.last == 'insert-one') {
            return http.Response(
              '{"inserted":[{"title":"Preparar el terreno"}]}',
              200,
              headers: {'content-type': 'application/json'},
            );
          }

          return api.handle(request);
        }),
      );

      await expectLater(
        noId.createTask(draft()),
        throwsA(
          isA<ListingException>().having(
            (error) => error.message,
            'message',
            contains('no devolvió su identificador'),
          ),
        ),
      );
    });
  });

  group('getTasks', () {
    test('lee de vuelta lo que escribió', () async {
      final created = await source.createTask(
        draft(dueDate: DateTime(2026, 11, 15), assigneeId: 'user-3'),
      );

      final task = (await source.getTasks(listingId)).single;

      expect(task.id, created.id);
      expect(task.listingId, listingId);
      expect(task.title, 'Preparar el terreno');
      expect(task.assigneeId, 'user-3');
      expect(task.assigneeName, 'Carlos');
      expect(task.dueDate, DateTime(2026, 11, 15));
      expect(task.column, TaskColumn.todo);
      expect(task.createdById, 'user-1');
      expect(
        task.createdAt.isAtSameMomentAs(DateTime.utc(2026, 10, 1, 15, 30)),
        isTrue,
      );
    });

    test('solo trae las tareas de ese proyecto', () async {
      seedTask({'title': 'Mía'});
      seedTask({
        'title': 'Ajena',
        'listing_id': '00000000-0000-4000-8000-000000009999',
      });

      final tasks = await source.getTasks(listingId);

      expect(tasks.map((task) => task.title), ['Mía']);
    });

    test('una fecha con hora se lee como ese día local', () async {
      // A row written by hand in the console, or by a column typed `date`.
      seedTask({'due_date': '2026-11-15T00:00:00Z'});

      final task = (await source.getTasks(listingId)).single;

      expect(task.dueDate, DateTime(2026, 11, 15));
      expect(task.dueDate!.isUtc, isFalse);
    });

    test('una fecha ilegible o corta se lee como sin fecha', () async {
      seedTask({'title': 'Corta', 'due_date': '2026-11'});
      seedTask({'title': 'Ilegible', 'due_date': 'mañana sin falta'});
      seedTask({'title': 'Vacía', 'due_date': ''});

      final tasks = await source.getTasks(listingId);

      expect(tasks.map((task) => task.dueDate), [null, null, null]);
    });

    test('un estado desconocido cae en "Por hacer"', () async {
      seedTask({'status': 'blocked'});
      seedTask({'status': 'doing'});

      final tasks = await source.getTasks(listingId);

      expect(tasks.map((task) => task.column), [
        TaskColumn.todo,
        TaskColumn.doing,
      ]);
    });

    test('una fila sin created_at ni asignación no rompe el tablero',
        () async {
      api.seed('listing_tasks', {'listing_id': listingId, 'title': 'Mínima'});

      final task = (await source.getTasks(listingId)).single;

      expect(task.createdAt, DateTime.fromMillisecondsSinceEpoch(0));
      expect(task.isAssigned, isFalse);
      expect(task.createdById, isEmpty);
    });

    test('una fila sin _id se descarta', () async {
      seedTask({'_id': '', 'title': 'Sin id'});
      seedTask({'title': 'Con id'});

      final tasks = await source.getTasks(listingId);

      expect(tasks.map((task) => task.title), ['Con id']);
    });

    test('un id de proyecto que no es UUID no hace ninguna petición', () async {
      expect(await source.getTasks('listing_1'), isEmpty);
      expect(api.calls, isEmpty);
    });
  });

  group('updateTask', () {
    test('escribe las columnas editables y no toca autor ni fecha de creación',
        () async {
      final created = await source.createTask(draft());

      await source.updateTask(
        created.copyWith(
          title: 'Sembrar',
          assigneeId: 'user-4',
          assigneeName: 'Valentina',
          dueDate: DateTime(2026, 12, 24),
          column: TaskColumn.doing,
        ),
      );

      final row = rows().single;
      expect(row['title'], 'Sembrar');
      expect(row['assignee_id'], 'user-4');
      expect(row['assignee_name'], 'Valentina');
      expect(row['due_date'], '2026-12-24');
      expect(row['status'], 'doing');
      expect(row['created_by'], 'user-1');
      expect(row['created_at'], '2026-10-01T15:30:00.000Z');
    });

    test('quitar la fecha límite la deja nula en la fila', () async {
      final created = await source.createTask(
        draft(dueDate: DateTime(2026, 11, 15)),
      );

      await source.updateTask(created.copyWith(clearDueDate: true));

      expect(rows().single['due_date'], isNull);
      expect((await source.getTasks(listingId)).single.dueDate, isNull);
    });
  });

  group('borrado', () {
    test('deleteTask borra solo esa tarea', () async {
      final first = await source.createTask(draft());
      await source.createTask(draft());

      await source.deleteTask(first.id);

      expect(rows(), hasLength(1));
      expect(rows().single['_id'], isNot(first.id));
    });

    test('deleteTasksOf vacía el tablero de ese proyecto y no el de otros',
        () async {
      await source.createTask(draft());
      await source.createTask(draft());
      seedTask({
        'title': 'Ajena',
        'listing_id': '00000000-0000-4000-8000-000000009999',
      });

      await source.deleteTasksOf(listingId);

      expect(rows().map((row) => row['title']), ['Ajena']);
    });

    test('deleteTasksOf con un id que no es UUID no hace ninguna petición',
        () async {
      await source.deleteTasksOf('listing_1');

      expect(api.calls, isEmpty);
    });
  });
}
