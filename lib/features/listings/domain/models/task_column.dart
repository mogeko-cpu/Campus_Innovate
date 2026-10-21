/// The columns of a project's task board.
///
/// Stored as the enum's name in the `status` column of `listing_tasks`; the
/// order of the values is the order of the columns, left to right.
///
/// [cancelled] is a column but not a step: work the team decided not to do.
/// A card reaches it from the menu, never with the arrows, and leaves the count
/// the progress is taken over — see `TaskProgress`.
enum TaskColumn {
  todo,
  doing,
  done,
  cancelled;

  /// The columns a card walks through with the arrows, in order.
  static const flow = [TaskColumn.todo, TaskColumn.doing, TaskColumn.done];

  String get label => switch (this) {
        TaskColumn.todo => 'Por hacer',
        TaskColumn.doing => 'En progreso',
        TaskColumn.done => 'Hecho',
        TaskColumn.cancelled => 'Cancelado',
      };

  bool get isCancelled => this == TaskColumn.cancelled;

  /// The column to the left, or null from the first one and from [cancelled].
  TaskColumn? get previous {
    final index = flow.indexOf(this);
    return index <= 0 ? null : flow[index - 1];
  }

  /// The column to the right, or null from the last one and from [cancelled].
  TaskColumn? get next {
    final index = flow.indexOf(this);
    return index == -1 || index == flow.length - 1 ? null : flow[index + 1];
  }

  /// An unknown value reads as [todo], so a task is never lost from the board.
  static TaskColumn fromName(String? name) {
    for (final column in values) {
      if (column.name == name) return column;
    }

    return TaskColumn.todo;
  }
}
