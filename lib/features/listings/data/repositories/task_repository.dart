import '../../domain/listing_exception.dart';
import '../../domain/models/listing_task.dart';
import '../../domain/models/task_column.dart';
import '../../domain/repositories/i_task_repository.dart';
import '../datasources/i_task_source.dart';

class TaskRepository implements ITaskRepository {
  final ITaskSource _source;

  TaskRepository(this._source);

  static const minTitleLength = 3;
  static const maxTitleLength = 120;

  @override
  Future<List<ListingTask>> getTasks(String listingId) async {
    // A copy: a source may hand back a constant list, and sorting it in place
    // would throw.
    final tasks = [...await _source.getTasks(listingId)];

    // ROBLE cannot order a read. By column, then whatever is due soonest — a
    // task with no date after the ones that have one — then the oldest first.
    tasks.sort((a, b) {
      final byColumn = a.column.index.compareTo(b.column.index);
      if (byColumn != 0) return byColumn;

      final aDue = a.dueDate;
      final bDue = b.dueDate;

      if (aDue != null && bDue != null) {
        final byDue = aDue.compareTo(bDue);
        if (byDue != 0) return byDue;
      } else if (aDue != null || bDue != null) {
        return aDue == null ? 1 : -1;
      }

      return a.createdAt.compareTo(b.createdAt);
    });

    return tasks;
  }

  @override
  Future<TaskProgress> progressOf(String listingId) async =>
      TaskProgress.of(await _source.getTasks(listingId));

  @override
  Future<ListingTask> createTask(ListingTask draft) async {
    return _source.createTask(draft.copyWith(title: _validTitle(draft.title)));
  }

  @override
  Future<ListingTask> updateTask(ListingTask task) async {
    final clean = task.copyWith(title: _validTitle(task.title));

    await _source.updateTask(clean);

    return clean;
  }

  @override
  Future<ListingTask> moveTask(ListingTask task, TaskColumn column) async {
    if (task.column == column) return task;

    final moved = task.copyWith(column: column);

    await _source.updateTask(moved);

    return moved;
  }

  @override
  Future<void> deleteTask(String taskId) => _source.deleteTask(taskId);

  @override
  Future<int> unassignAll({
    required String listingId,
    required String userId,
  }) async {
    var freed = 0;

    for (final task in await _source.getTasks(listingId)) {
      if (task.assigneeId != userId) continue;

      await _source.updateTask(task.copyWith(assigneeId: '', assigneeName: ''));
      freed++;
    }

    return freed;
  }

  @override
  Future<void> purgeListing(String listingId) =>
      _source.deleteTasksOf(listingId);

  String _validTitle(String title) {
    final clean = title.trim().replaceAll(RegExp(r'\s+'), ' ');

    if (clean.length < minTitleLength) {
      throw const ListingException(
        'Escribe un título de al menos $minTitleLength caracteres.',
      );
    }

    if (clean.length > maxTitleLength) {
      throw const ListingException(
        'El título es muy largo. Máximo $maxTitleLength caracteres.',
      );
    }

    return clean;
  }
}
