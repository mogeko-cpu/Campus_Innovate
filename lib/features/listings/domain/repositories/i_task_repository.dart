import '../models/listing_task.dart';
import '../models/task_column.dart';

abstract class ITaskRepository {
  /// The board of a project, in the order each column shows it.
  Future<List<ListingTask>> getTasks(String listingId);

  Future<TaskProgress> progressOf(String listingId);

  Future<ListingTask> createTask(ListingTask draft);

  /// Saves an edited title, assignee or due date.
  Future<ListingTask> updateTask(ListingTask task);

  Future<ListingTask> moveTask(ListingTask task, TaskColumn column);

  Future<void> deleteTask(String taskId);

  /// Leaves every task of [userId] in the project without anybody, for when
  /// that person is no longer on the team. Returns how many it freed.
  Future<int> unassignAll({required String listingId, required String userId});

  /// Removes the board of a project that is being deleted.
  Future<void> purgeListing(String listingId);
}
