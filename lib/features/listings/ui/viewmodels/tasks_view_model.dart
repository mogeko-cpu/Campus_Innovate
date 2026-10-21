import 'package:get/get.dart';

import '../../../../core/error_message.dart';
import '../../../../core/i_session_service.dart';
import '../../../notifications/domain/notification_publisher.dart';
import '../../domain/models/listing.dart';
import '../../domain/models/listing_member.dart';
import '../../domain/models/listing_role.dart';
import '../../domain/models/listing_task.dart';
import '../../domain/models/task_column.dart';
import '../../domain/repositories/i_listing_repository.dart';
import '../../domain/repositories/i_task_repository.dart';

/// A project's task board.
///
/// Only the team sees it. Leader and members work it — create, assign, move —
/// and a mentor follows it without touching the cards.
class TasksViewModel extends GetxController {
  final ITaskRepository _tasks;
  final IListingRepository _listings;
  final NotificationPublisher _notifier;
  final ISessionService _session;

  TasksViewModel(this._tasks, this._listings, this._notifier, this._session);

  final Rxn<Listing> listing = Rxn<Listing>();
  final RxList<ListingTask> tasks = <ListingTask>[].obs;
  final RxBool isLoading = false.obs;

  /// The id of the task being written, so only its card waits.
  final RxnString busyTaskId = RxnString();
  final RxnString error = RxnString();

  /// Why the last action failed; apart from [error], which replaces the board,
  /// because a button that failed must not take the board away.
  String? lastActionError;

  late final String listingId;

  @override
  void onInit() {
    super.onInit();
    listingId = Get.parameters['id'] ?? '';
    load();
  }

  Future<void> load() async {
    try {
      isLoading.value = true;
      error.value = null;

      final found = await _listings.getListingById(listingId);

      if (found == null) {
        error.value = 'Proyecto no encontrado';
        return;
      }

      // The board is the team's working space, not a public page.
      if (found.roleOf(_session.currentUserId) == null) {
        error.value = 'Solo el equipo del proyecto puede ver sus tareas.';
        return;
      }

      listing.value = found;
      tasks.assignAll(await _tasks.getTasks(listingId));
    } catch (failure) {
      error.value = errorMessage(
        failure,
        fallback: 'No se pudieron cargar las tareas',
      );
    } finally {
      isLoading.value = false;
    }
  }

  String get currentUserId => _session.currentUserId;

  ListingRole? get myRole => listing.value?.roleOf(_session.currentUserId);

  /// Leader and members; never a mentor or somebody outside.
  bool get canWork => myRole?.canWorkTasks ?? false;

  /// Whoever created a card can take it back, and the leader can tidy any.
  bool canDelete(ListingTask task) =>
      myRole == ListingRole.leader ||
      (canWork && task.createdById == _session.currentUserId);

  /// People a task can be given to: the ones who work the board.
  List<ListingMember> get assignable => [
        for (final member in listing.value?.team ?? const <ListingMember>[])
          if (member.role.canWorkTasks) member,
      ];

  List<ListingTask> tasksIn(TaskColumn column) =>
      tasks.where((task) => task.column == column).toList();

  TaskProgress get progress => TaskProgress.of(tasks);

  Future<bool> create({
    required String title,
    String assigneeId = '',
    DateTime? dueDate,
  }) async {
    final current = listing.value;
    if (current == null || !canWork) return false;

    return _run(
      fallback: 'No se pudo crear la tarea',
      action: () async {
        final assignee = _memberOf(assigneeId);

        final stored = await _tasks.createTask(
          ListingTask.draft(
            listingId: listingId,
            title: title,
            createdById: _session.currentUserId,
            assigneeId: assignee?.userId ?? '',
            assigneeName: assignee?.userName ?? '',
            dueDate: dueDate,
          ),
        );

        await _notifyAssignee(stored, previousAssigneeId: '');
        await _reload();
      },
    );
  }

  /// Saves a new title, assignee or due date on [task].
  Future<bool> edit(
    ListingTask task, {
    required String title,
    required String assigneeId,
    required DateTime? dueDate,
  }) async {
    if (!canWork) return false;

    return _run(
      taskId: task.id,
      fallback: 'No se pudo guardar la tarea',
      action: () async {
        final assignee = _memberOf(assigneeId);

        final saved = await _tasks.updateTask(
          task.copyWith(
            title: title,
            assigneeId: assignee?.userId ?? '',
            assigneeName: assignee?.userName ?? '',
            dueDate: dueDate,
            clearDueDate: dueDate == null,
          ),
        );

        await _notifyAssignee(saved, previousAssigneeId: task.assigneeId);
        await _reload();
      },
    );
  }

  Future<bool> move(ListingTask task, TaskColumn column) async {
    if (!canWork) return false;

    return _run(
      taskId: task.id,
      fallback: 'No se pudo mover la tarea',
      action: () async {
        await _tasks.moveTask(task, column);
        await _reload();
      },
    );
  }

  Future<bool> delete(ListingTask task) async {
    if (!canDelete(task)) return false;

    return _run(
      taskId: task.id,
      fallback: 'No se pudo eliminar la tarea',
      action: () async {
        await _tasks.deleteTask(task.id);
        await _reload();
      },
    );
  }

  ListingMember? _memberOf(String userId) {
    if (userId.isEmpty) return null;

    for (final member in assignable) {
      if (member.userId == userId) return member;
    }

    return null;
  }

  /// Tells whoever has the task now, unless they already had it or gave it to
  /// themselves.
  Future<void> _notifyAssignee(
    ListingTask task, {
    required String previousAssigneeId,
  }) async {
    final current = listing.value;
    if (current == null || !task.isAssigned) return;
    if (task.assigneeId == previousAssigneeId) return;

    await _notifier.taskAssigned(
      listingId: current.id,
      listingTitle: current.title,
      taskTitle: task.title,
      assignerId: _session.currentUserId,
      assignerName: _session.currentUserName,
      assigneeId: task.assigneeId,
    );
  }

  /// Read again after every write rather than patched: two people work the
  /// same board, and what this screen shows has to be what the table holds.
  Future<void> _reload() async {
    tasks.assignAll(await _tasks.getTasks(listingId));
  }

  Future<bool> _run({
    required Future<void> Function() action,
    required String fallback,
    String taskId = '',
  }) async {
    if (busyTaskId.value != null) return false;

    try {
      busyTaskId.value = taskId;
      lastActionError = null;

      await action();

      return true;
    } catch (failure) {
      lastActionError = errorMessage(failure, fallback: fallback);

      return false;
    } finally {
      busyTaskId.value = null;
    }
  }
}
