import 'package:campus_innovate/features/listings/data/datasources/i_task_source.dart';
import 'package:campus_innovate/features/listings/domain/listing_exception.dart';
import 'package:campus_innovate/features/listings/domain/models/listing_task.dart';

/// [ITaskSource] in memory, starting with no tasks.
class InMemoryTaskSource implements ITaskSource {
  final List<ListingTask> _tasks = [];

  var _nextId = 1100;

  /// Every task, for the tests that look at what was stored.
  List<ListingTask> get all => List.unmodifiable(_tasks);

  @override
  Future<List<ListingTask>> getTasks(String listingId) async =>
      _tasks.where((task) => task.listingId == listingId).toList();

  @override
  Future<ListingTask> createTask(ListingTask task) async {
    final stored = task.copyWith(id: 'task_${_nextId++}');
    _tasks.add(stored);

    return stored;
  }

  @override
  Future<void> updateTask(ListingTask task) async {
    final index = _tasks.indexWhere((stored) => stored.id == task.id);

    if (index == -1) {
      throw ListingException('La tarea ${task.id} ya no existe.');
    }

    _tasks[index] = task;
  }

  @override
  Future<void> deleteTask(String taskId) async {
    _tasks.removeWhere((task) => task.id == taskId);
  }

  @override
  Future<void> deleteTasksOf(String listingId) async {
    _tasks.removeWhere((task) => task.listingId == listingId);
  }
}
