import '../../../../../core/roble/roble_client.dart';
import '../../../../../core/roble/roble_config.dart';
import '../../../domain/listing_exception.dart';
import '../../../domain/models/listing_task.dart';
import '../../../domain/models/task_column.dart';
import '../i_task_source.dart';

/// A project's tasks, stored in ROBLE as one row per card in `listing_tasks`.
class RobleTaskSource implements ITaskSource {
  RobleTaskSource(this._client);

  final RobleClient _client;

  @override
  Future<List<ListingTask>> getTasks(String listingId) async {
    if (!RobleClient.isRowId(listingId)) return const [];

    final rows = await _client.read(
      RobleConfig.listingTasksTable,
      filters: {'listing_id': listingId},
    );

    return rows.map(_taskFrom).whereType<ListingTask>().toList();
  }

  @override
  Future<ListingTask> createTask(ListingTask task) async {
    final row = await _client.insertOne(RobleConfig.listingTasksTable, {
      'listing_id': task.listingId,
      ..._editableColumnsOf(task),
      'created_by': task.createdById,
      'created_at': task.createdAt.toUtc().toIso8601String(),
    });

    final id = row['_id']?.toString();

    if (id == null || id.isEmpty) {
      throw const ListingException(
        'ROBLE guardó la tarea pero no devolvió su identificador. '
        'Recarga el tablero antes de volver a crearla.',
      );
    }

    return task.copyWith(id: id);
  }

  @override
  Future<void> updateTask(ListingTask task) async {
    await _client.update(
      tableName: RobleConfig.listingTasksTable,
      idValue: task.id,
      updates: _editableColumnsOf(task),
    );
  }

  @override
  Future<void> deleteTask(String taskId) async {
    await _client.delete(
      tableName: RobleConfig.listingTasksTable,
      idValue: taskId,
    );
  }

  @override
  Future<void> deleteTasksOf(String listingId) async {
    if (!RobleClient.isRowId(listingId)) return;

    // ROBLE deletes by `_id` only: a read, then one delete per row.
    final rows = await _client.read(
      RobleConfig.listingTasksTable,
      filters: {'listing_id': listingId},
    );

    for (final row in rows) {
      final id = row['_id']?.toString();
      if (id == null || id.isEmpty) continue;

      await _client.delete(
        tableName: RobleConfig.listingTasksTable,
        idValue: id,
      );
    }
  }

  Map<String, dynamic> _editableColumnsOf(ListingTask task) => {
        'title': task.title,
        'assignee_id': task.assigneeId,
        'assignee_name': task.assigneeName,
        'due_date': _dayOf(task.dueDate),
        'status': task.column.name,
      };

  /// `AAAA-MM-DD`, the day alone: see [ListingTask.dueDate].
  String? _dayOf(DateTime? day) {
    if (day == null) return null;

    String two(int value) => value.toString().padLeft(2, '0');

    return '${day.year}-${two(day.month)}-${two(day.day)}';
  }

  /// Read back as a local date, whatever the text carries after the day.
  DateTime? _parseDay(dynamic value) {
    final text = value?.toString() ?? '';
    if (text.length < 10) return null;

    final parsed = DateTime.tryParse(text.substring(0, 10));

    return parsed == null ? null : ListingTask.dateOnly(parsed);
  }

  ListingTask? _taskFrom(Map<String, dynamic> row) {
    final id = row['_id']?.toString();
    final listingId = row['listing_id']?.toString();
    if (id == null || id.isEmpty || listingId == null) return null;

    return ListingTask(
      id: id,
      listingId: listingId,
      title: row['title']?.toString() ?? '',
      assigneeId: row['assignee_id']?.toString() ?? '',
      assigneeName: row['assignee_name']?.toString() ?? '',
      dueDate: _parseDay(row['due_date']),
      column: TaskColumn.fromName(row['status']?.toString()),
      createdById: row['created_by']?.toString() ?? '',
      createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
