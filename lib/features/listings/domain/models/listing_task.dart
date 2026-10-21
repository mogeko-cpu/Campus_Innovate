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

  bool get isCancelled => column == TaskColumn.cancelled;

  /// Past its day and not finished. A task due today is not late yet, and a
  /// cancelled one never is: nobody is going to do it.
  bool isOverdue(DateTime now) {
    final due = dueDate;
    if (due == null || isDone || isCancelled) return false;

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

/// How far along a project is: its finished tasks out of the ones that count.
///
/// A cancelled task is work the team decided not to do, so it leaves the count
/// instead of holding the project back forever; everything else is either done
/// or still to do.
///
/// Counted from the rows every time, never stored on the project, for the same
/// reason likes are counted: a stored number would need read-modify-write and
/// two people finishing a task at once would lose one.
class TaskProgress {
  final int done;
  final int total;

  /// Part of [total] that was cancelled.
  final int cancelled;

  const TaskProgress({
    required this.done,
    required this.total,
    this.cancelled = 0,
  });

  static const empty = TaskProgress(done: 0, total: 0);

  factory TaskProgress.of(Iterable<ListingTask> tasks) {
    var done = 0;
    var total = 0;
    var cancelled = 0;

    for (final task in tasks) {
      total++;
      if (task.isDone) done++;
      if (task.isCancelled) cancelled++;
    }

    return TaskProgress(done: done, total: total, cancelled: cancelled);
  }

  /// The tasks the progress is taken over: every one but the cancelled.
  int get counted => total - cancelled;

  /// Between 0 and 1; 0 for a board with nothing to count.
  double get fraction => counted == 0 ? 0 : done / counted;

  /// [fraction] as a whole percentage, the number the team looks for.
  int get percent => (fraction * 100).round();

  String get label => counted == 1
      ? '$done de 1 tarea hecha'
      : '$done de $counted tareas hechas';
}
