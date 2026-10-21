/// The three columns of a project's task board.
///
/// Stored as the enum's name in the `status` column of `listing_tasks`; the
/// order of the values is the order of the columns, left to right.
enum TaskColumn {
  todo,
  doing,
  done;

  String get label => switch (this) {
        TaskColumn.todo => 'Por hacer',
        TaskColumn.doing => 'En progreso',
        TaskColumn.done => 'Hecho',
      };

  /// The column to the left, or null from the first one.
  TaskColumn? get previous => index == 0 ? null : values[index - 1];

  /// The column to the right, or null from the last one.
  TaskColumn? get next => index == values.length - 1 ? null : values[index + 1];

  /// An unknown value reads as [todo], so a task is never lost from the board.
  static TaskColumn fromName(String? name) {
    for (final column in values) {
      if (column.name == name) return column;
    }

    return TaskColumn.todo;
  }
}
