import '../../domain/models/listing_task.dart';

/// Storage contract for a project's task board.
abstract class ITaskSource {
  /// Every task of the project, in no particular order.
  Future<List<ListingTask>> getTasks(String listingId);

  /// Stores [task] — which arrives without an id — and returns it with the id
  /// the database assigned.
  Future<ListingTask> createTask(ListingTask task);

  /// Writes the title, assignee, due date and column of [task] onto its row.
  Future<void> updateTask(ListingTask task);

  Future<void> deleteTask(String taskId);

  /// Removes every task of the project. ROBLE has no cascades, so deleting a
  /// project calls this by hand.
  Future<void> deleteTasksOf(String listingId);
}
