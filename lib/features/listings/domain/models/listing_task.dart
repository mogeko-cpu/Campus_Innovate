import 'task_column.dart';

/// One piece of work on a project's board.
///
/// A row per task in `listing_tasks`, never a list inside the project: moving a
/// card is an update of that one row, and two people moving two cards at once
/// cannot overwrite each other — ROBLE has no transactions to protect a list.
class ListingTask {
  /// `_id` of the row; empty on a draft.
  final String id;
  final String listingId;
  final String title;

  /// Empty while nobody has taken it.
  final String assigneeId;

  /// Copied in so the board can show who has it without a lookup.
  final String assigneeName;

  /// The day it is due, without a time: a deadline here is "by Friday", and a
  /// time of day would only drag the time-zone trap of `timestamp` columns in
  /// with it. Null when there is none.
  final DateTime? dueDate;
  final TaskColumn column;
  final String createdById;
  final DateTime createdAt;

  const ListingTask({
    required this.id,
    required this.listingId,
    required this.title,
    required this.assigneeId,
    required this.assigneeName,
    required this.dueDate,
    required this.column,
    required this.createdById,
    required this.createdAt,
  });

  /// A task as the form leaves it: no [id] yet, in the first column, dated now.
  ListingTask.draft({
    required this.listingId,
    required this.title,
    required this.createdById,
    this.assigneeId = '',
    this.assigneeName = '',
    DateTime? dueDate,
    DateTime? createdAt,
  })  : id = '',
        dueDate = dueDate == null ? null : dateOnly(dueDate),
        column = TaskColumn.todo,
        createdAt = createdAt ?? DateTime.now();

  bool get isPersisted => id.isNotEmpty;

  bool get isAssigned => assigneeId.isNotEmpty;

  bool get isDone => column == TaskColumn.done;

  /// Past its day and not finished. A task due today is not late yet.
  bool isOverdue(DateTime now) {
    final due = dueDate;
    if (due == null || isDone) return false;

    return due.isBefore(dateOnly(now));
  }

  /// Drops the time of day, so two moments of the same day compare equal.
  static DateTime dateOnly(DateTime moment) =>
      DateTime(moment.year, moment.month, moment.day);

  ListingTask copyWith({
    String? id,
    String? title,
    String? assigneeId,
    String? assigneeName,
    DateTime? dueDate,
    bool clearDueDate = false,
    TaskColumn? column,
  }) {
    return ListingTask(
      id: id ?? this.id,
      listingId: listingId,
      title: title ?? this.title,
      assigneeId: assigneeId ?? this.assigneeId,
      assigneeName: assigneeName ?? this.assigneeName,
      dueDate: clearDueDate
          ? null
          : (dueDate == null ? this.dueDate : dateOnly(dueDate)),
      column: column ?? this.column,
      createdById: createdById,
      createdAt: createdAt,
    );
  }
}

/// How far along a project is: its finished tasks out of all of them.
///
/// Counted from the rows every time, never stored on the project, for the same
/// reason likes are counted: a stored number would need read-modify-write and
/// two people finishing a task at once would lose one.
class TaskProgress {
  final int done;
  final int total;

  const TaskProgress({required this.done, required this.total});

  static const empty = TaskProgress(done: 0, total: 0);

  factory TaskProgress.of(Iterable<ListingTask> tasks) {
    var done = 0;
    var total = 0;

    for (final task in tasks) {
      total++;
      if (task.isDone) done++;
    }

    return TaskProgress(done: done, total: total);
  }

  /// Between 0 and 1; 0 for a board with no tasks.
  double get fraction => total == 0 ? 0 : done / total;

  String get label => total == 1
      ? '$done de 1 tarea hecha'
      : '$done de $total tareas hechas';
}
