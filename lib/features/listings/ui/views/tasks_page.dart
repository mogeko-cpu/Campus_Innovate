import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/day_format.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/name_avatar.dart';
import '../../../shell/ui/widgets/empty_state.dart';
import '../../../shell/ui/widgets/hero_decor.dart';
import '../../../shell/ui/widgets/info_banner.dart';
import '../../domain/models/listing_member.dart';
import '../../domain/models/listing_task.dart';
import '../../domain/models/task_column.dart';
import '../viewmodels/tasks_view_model.dart';

/// A project's board: three columns of cards, moved one step at a time.
///
/// On a phone the columns are tabs, because three columns side by side would
/// leave each card a few words wide; with room for them, they sit side by side
/// the way a board is usually drawn.
class TasksPage extends GetView<TasksViewModel> {
  const TasksPage({super.key});

  /// From this width the three columns fit side by side.
  static const wideLayout = 720.0;

  void _toast(String title, String message) =>
      Get.snackbar(title, message, snackPosition: SnackPosition.BOTTOM);

  Future<void> _create() async {
    final result = await Get.dialog<_TaskFormResult>(
      _TaskFormDialog(people: controller.assignable),
    );
    if (result == null) return;

    final done = await controller.create(
      title: result.title,
      assigneeId: result.assigneeId,
      dueDate: result.dueDate,
    );

    if (!done) {
      _toast('No se pudo crear', controller.lastActionError ?? 'Intenta de nuevo');
    }
  }

  Future<void> _edit(ListingTask task) async {
    final result = await Get.dialog<_TaskFormResult>(
      _TaskFormDialog(people: controller.assignable, initial: task),
    );
    if (result == null) return;

    final done = await controller.edit(
      task,
      title: result.title,
      assigneeId: result.assigneeId,
      dueDate: result.dueDate,
    );

    if (!done) {
      _toast('No se pudo guardar', controller.lastActionError ?? 'Intenta de nuevo');
    }
  }

  Future<void> _move(ListingTask task, TaskColumn column) async {
    final done = await controller.move(task, column);

    if (!done) {
      _toast('No se pudo mover', controller.lastActionError ?? 'Intenta de nuevo');
    }
  }

  Future<void> _cancel(ListingTask task) async {
    final confirmed = await confirmAction(
      title: '¿Cancelar la tarea?',
      message: '"${task.title}" queda en la columna Cancelado y deja de contar '
          'para el avance. Puedes reabrirla cuando quieras.',
      confirmLabel: 'Cancelar tarea',
    );
    if (!confirmed) return;

    final done = await controller.cancel(task);

    if (!done) {
      _toast('No se pudo cancelar', controller.lastActionError ?? 'Intenta de nuevo');
    }
  }

  Future<void> _reopen(ListingTask task) async {
    final done = await controller.reopen(task);

    if (!done) {
      _toast('No se pudo reabrir', controller.lastActionError ?? 'Intenta de nuevo');
    }
  }

  Future<void> _delete(ListingTask task) async {
    final confirmed = await confirmAction(
      title: '¿Eliminar la tarea?',
      message: '"${task.title}" desaparece del tablero.',
      confirmLabel: 'Eliminar',
    );
    if (!confirmed) return;

    final done = await controller.delete(task);

    if (!done) {
      _toast('No se pudo eliminar', controller.lastActionError ?? 'Intenta de nuevo');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Obx(() {
          final title = controller.listing.value?.title;

          return Text(title == null ? 'Tareas' : 'Tareas · $title');
        }),
      ),
      floatingActionButton: Obx(
        () => controller.canWork
            ? FloatingActionButton.extended(
                onPressed: _create,
                icon: const Icon(Icons.add_task),
                label: const Text('Nueva tarea'),
              )
            : const SizedBox.shrink(),
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        if (controller.error.value != null || controller.listing.value == null) {
          return EmptyState.screen(
            icon: Icons.lock_outline,
            title: 'No se pudo abrir el tablero',
            message: controller.error.value ?? 'Proyecto no encontrado',
          );
        }

        // Everything the cards depend on is read here, inside the `Obx`: the
        // builders below run later, outside it, and would not notice a change.
        final canWork = controller.canWork;
        final busyId = controller.busyTaskId.value;
        final now = DateTime.now();
        final columns = {
          for (final column in TaskColumn.values)
            column: [
              for (final task in controller.tasksIn(column))
                _CardData(
                  task: task,
                  canWork: canWork,
                  canDelete: controller.canDelete(task),
                  isBusy: busyId == task.id,
                  isLocked: busyId != null,
                  isOverdue: task.isOverdue(now),
                ),
            ],
        };

        final actions = _CardActions(
          onMove: _move,
          onEdit: _edit,
          onCancel: _cancel,
          onReopen: _reopen,
          onDelete: _delete,
        );

        return Column(
          children: [
            _ProgressHeader(
              progress: controller.progress,
              counts: {
                for (final column in TaskColumn.values)
                  column: columns[column]!.length,
              },
            ),
            if (!canWork)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: InfoBanner(
                  icon: Icons.visibility_outlined,
                  text: 'Como mentor puedes seguir el tablero, pero no mover '
                      'las tarjetas.',
                ),
              ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth >= wideLayout) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final column in TaskColumn.values)
                          Expanded(
                            child: _ColumnView(
                              column: column,
                              cards: columns[column]!,
                              actions: actions,
                              showTitle: true,
                            ),
                          ),
                      ],
                    );
                  }

                  return DefaultTabController(
                    length: TaskColumn.values.length,
                    child: Column(
                      children: [
                        TabBar(
                          // Four columns with their counts do not fit a phone
                          // side by side; they scroll instead of squeezing.
                          isScrollable: true,
                          tabAlignment: TabAlignment.start,
                          tabs: [
                            for (final column in TaskColumn.values)
                              Tab(
                                text: '${column.label} '
                                    '(${columns[column]!.length})',
                              ),
                          ],
                        ),
                        Expanded(
                          child: TabBarView(
                            children: [
                              for (final column in TaskColumn.values)
                                _ColumnView(
                                  column: column,
                                  cards: columns[column]!,
                                  actions: actions,
                                  showTitle: false,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      }),
    );
  }
}

/// How far along the board is, on the brand gradient: the percentage first,
/// since it is what the team opens the board to see, then what it is made of.
class _ProgressHeader extends StatelessWidget {
  final TaskProgress progress;

  /// Cards per column, for the small counters under the bar.
  final Map<TaskColumn, int> counts;

  const _ProgressHeader({required this.progress, required this.counts});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final onHero = colors.onPrimary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [colors.primary, colors.secondary],
          ),
          boxShadow: heroShadow(colors),
        ),
        child: Stack(
          children: [
            HeroDecor(color: onHero),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${progress.percent}%',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: onHero,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          progress.label,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: onHero.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress.fraction,
                      minHeight: 8,
                      color: onHero,
                      backgroundColor: onHero.withValues(alpha: 0.22),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      for (final entry in counts.entries)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: onHero.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _iconOf(entry.key),
                                size: 13,
                                color: onHero.withValues(alpha: 0.9),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                '${entry.value}',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: onHero,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static IconData _iconOf(TaskColumn column) => switch (column) {
        TaskColumn.todo => Icons.radio_button_unchecked,
        TaskColumn.doing => Icons.timelapse,
        TaskColumn.done => Icons.check_circle_outline,
        TaskColumn.cancelled => Icons.block,
      };
}

/// What one card shows, worked out inside the page's `Obx`.
class _CardData {
  final ListingTask task;
  final bool canWork;
  final bool canDelete;
  final bool isBusy;

  /// Some card is being written: every button waits, so two taps cannot race.
  final bool isLocked;
  final bool isOverdue;

  const _CardData({
    required this.task,
    required this.canWork,
    required this.canDelete,
    required this.isBusy,
    required this.isLocked,
    required this.isOverdue,
  });
}

class _CardActions {
  final Future<void> Function(ListingTask, TaskColumn) onMove;
  final Future<void> Function(ListingTask) onEdit;
  final Future<void> Function(ListingTask) onCancel;
  final Future<void> Function(ListingTask) onReopen;
  final Future<void> Function(ListingTask) onDelete;

  const _CardActions({
    required this.onMove,
    required this.onEdit,
    required this.onCancel,
    required this.onReopen,
    required this.onDelete,
  });
}

class _ColumnView extends StatelessWidget {
  final TaskColumn column;
  final List<_CardData> cards;
  final _CardActions actions;

  /// Side by side each column needs its name; as a tab, the tab already says it.
  final bool showTitle;

  const _ColumnView({
    required this.column,
    required this.cards,
    required this.actions,
    required this.showTitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
      children: [
        if (showTitle)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
            child: Text(
              '${column.label} (${cards.length})',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        if (cards.isEmpty)
          EmptyState.inline(
            icon: Icons.inbox_outlined,
            title: 'Nada en "${column.label}"',
          )
        else
          for (final card in cards) _TaskCard(data: card, actions: actions),
      ],
    );
  }
}

class _TaskCard extends StatelessWidget {
  final _CardData data;
  final _CardActions actions;

  const _TaskCard({required this.data, required this.actions});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final task = data.task;
    final due = task.dueDate;
    final previous = task.column.previous;
    final next = task.column.next;

    // A strip in the column's color down the left edge, so a card says where
    // it stands before a word is read — handy on the wide board, where every
    // column is on screen at once.
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: _accentOf(task.column, colors)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 6, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            task.title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              decoration: task.isDone || task.isCancelled
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: task.isCancelled
                                  ? colors.onSurfaceVariant
                                  : null,
                            ),
                          ),
                        ),
                        if (data.canWork)
                          PopupMenuButton<String>(
                            tooltip: 'Opciones de la tarea',
                            enabled: !data.isLocked,
                            onSelected: (choice) => switch (choice) {
                              'edit' => actions.onEdit(task),
                              'cancel' => actions.onCancel(task),
                              'reopen' => actions.onReopen(task),
                              _ => actions.onDelete(task),
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(value: 'edit', child: Text('Editar')),
                              if (task.isCancelled)
                                const PopupMenuItem(
                                  value: 'reopen',
                                  child: Text('Reabrir tarea'),
                                )
                              else
                                const PopupMenuItem(
                                  value: 'cancel',
                                  child: Text('Cancelar tarea'),
                                ),
                              if (data.canDelete)
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Eliminar'),
                                ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (task.isAssigned) ...[
                          NameAvatar(name: task.assigneeName, radius: 11),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              task.assigneeName.isEmpty
                                  ? 'Integrante'
                                  : task.assigneeName,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        ] else
                          Flexible(
                            child: Text(
                              'Sin asignar',
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ),
                        if (due != null) ...[
                          const SizedBox(width: 10),
                          Icon(
                            Icons.event_outlined,
                            size: 14,
                            color: data.isOverdue ? colors.error : colors.outline,
                          ),
                          const SizedBox(width: 3),
                          // Flexible as well: in a narrow column a name and a date with
                          // its year do not both fit.
                          Flexible(
                            child: Text(
                              data.isOverdue
                                  ? 'Venció el ${shortDay(due)}'
                                  : 'Vence el ${shortDay(due)}',
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: data.isOverdue ? colors.error : null,
                                fontWeight: data.isOverdue ? FontWeight.w700 : null,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (data.canWork) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (data.isBusy)
                            const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          else ...[
                            if (previous != null)
                              IconButton(
                                tooltip: 'Mover a ${previous.label}',
                                onPressed: data.isLocked
                                    ? null
                                    : () => actions.onMove(task, previous),
                                icon: const Icon(Icons.arrow_back),
                              ),
                            if (next != null)
                              IconButton(
                                tooltip: 'Mover a ${next.label}',
                                onPressed: data.isLocked
                                    ? null
                                    : () => actions.onMove(task, next),
                                icon: const Icon(Icons.arrow_forward),
                              ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Color _accentOf(TaskColumn column, ColorScheme colors) =>
      switch (column) {
        TaskColumn.todo => const Color(0xFFE07A1E),
        TaskColumn.doing => const Color(0xFF2F6FED),
        TaskColumn.done => const Color(0xFF1E9E6B),
        TaskColumn.cancelled => colors.outline,
      };
}

class _TaskFormResult {
  final String title;
  final String assigneeId;
  final DateTime? dueDate;

  const _TaskFormResult({
    required this.title,
    required this.assigneeId,
    required this.dueDate,
  });
}

/// The form to create or edit a card.
///
/// A widget of its own so the text controller lives exactly as long as the
/// field: disposing it when `Get.dialog` returns, while the dialog is still
/// animating out, breaks the closing frames.
class _TaskFormDialog extends StatefulWidget {
  final List<ListingMember> people;
  final ListingTask? initial;

  const _TaskFormDialog({required this.people, this.initial});

  @override
  State<_TaskFormDialog> createState() => _TaskFormDialogState();
}

class _TaskFormDialogState extends State<_TaskFormDialog> {
  late final _title = TextEditingController(text: widget.initial?.title ?? '');
  late String _assigneeId = _initialAssignee();
  late DateTime? _dueDate = widget.initial?.dueDate;
  String? _titleError;

  /// Somebody who left the team cannot stay selected: the menu has no entry for
  /// them, and saving would keep a name nobody can act on.
  String _initialAssignee() {
    final id = widget.initial?.assigneeId ?? '';

    return widget.people.any((person) => person.userId == id) ? id : '';
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final today = ListingTask.dateOnly(DateTime.now());

    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? today,
      firstDate: today.subtract(const Duration(days: 365)),
      lastDate: today.add(const Duration(days: 730)),
    );

    if (picked != null) setState(() => _dueDate = picked);
  }

  void _save() {
    final title = _title.text.trim();

    if (title.length < 3) {
      setState(() => _titleError = 'Escribe un título de al menos 3 caracteres');
      return;
    }

    Navigator.of(context).pop(
      _TaskFormResult(title: title, assigneeId: _assigneeId, dueDate: _dueDate),
    );
  }

  @override
  Widget build(BuildContext context) {
    final due = _dueDate;

    return AlertDialog(
      title: Text(widget.initial == null ? 'Nueva tarea' : 'Editar tarea'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _title,
              autofocus: widget.initial == null,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Título de la tarea',
                errorText: _titleError,
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _assigneeId,
              decoration: const InputDecoration(labelText: 'Responsable'),
              items: [
                const DropdownMenuItem(value: '', child: Text('Sin asignar')),
                for (final person in widget.people)
                  DropdownMenuItem(
                    value: person.userId,
                    child: Text(
                      person.userName.isEmpty ? 'Integrante' : person.userName,
                    ),
                  ),
              ],
              onChanged: (value) => setState(() => _assigneeId = value ?? ''),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    due == null
                        ? 'Sin fecha límite'
                        : 'Vence el ${shortDay(due)}',
                  ),
                ),
                if (due != null)
                  IconButton(
                    tooltip: 'Quitar fecha',
                    onPressed: () => setState(() => _dueDate = null),
                    icon: const Icon(Icons.close),
                  ),
                TextButton(
                  onPressed: _pickDate,
                  child: const Text('Elegir fecha'),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _save, child: const Text('Guardar')),
      ],
    );
  }
}
