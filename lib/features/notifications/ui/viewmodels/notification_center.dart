import 'package:get/get.dart';

import '../../../../core/i_session_service.dart';
import '../../../../core/poller.dart';
import '../../domain/models/app_notification.dart';
import '../../domain/repositories/i_notification_repository.dart';

/// The person's notifications, kept current while the app is open.
///
/// One instance for the whole app (registered as permanent) instead of one per
/// screen, because two things need the same answer at the same time: the bell on
/// every tab, which shows how many are unread, and the list screen, which shows
/// them. Both read this controller, and one timer keeps it fresh.
class NotificationCenter extends GetxController {
  final INotificationRepository _repository;
  final ISessionService _session;

  NotificationCenter(
    this._repository,
    this._session, {
    Duration interval = const Duration(seconds: 30),
  }) {
    _poller = Poller(interval: interval, action: refresh);
  }

  late final Poller _poller;

  final RxList<AppNotification> notifications = <AppNotification>[].obs;
  final RxInt unreadCount = 0.obs;
  final RxBool isLoading = false.obs;

  /// Ids already shown, so a poll only announces what is new. Null until the
  /// first load: what was waiting when the app opened is not "new", and
  /// announcing it all at once on launch would be noise.
  Set<String>? _seen;

  /// Whose notifications these are, to notice that a different person signed in
  /// on the same device and start from zero instead of showing the previous
  /// person's list for one poll.
  String? _ownerId;

  /// Starts keeping the list fresh. Idempotent: every bell calls it when it
  /// appears, and only the first one creates the timer.
  void start() {
    refresh();
    _poller.start();
  }

  /// Forgets everything. Called when the session ends.
  void reset() {
    _poller.stop();
    notifications.clear();
    unreadCount.value = 0;
    _seen = null;
    _ownerId = null;
  }

  Future<void> refresh() async {
    final String userId;

    try {
      userId = _session.currentUserId;
    } catch (_) {
      // No session: the person signed out. Nothing to fetch.
      return;
    }

    if (_ownerId != userId) {
      notifications.clear();
      unreadCount.value = 0;
      _seen = null;
      _ownerId = userId;
    }

    try {
      final fetched = await _repository.getMine(userId);

      _announceNew(fetched);

      notifications.assignAll(fetched);
      unreadCount.value = fetched.where((item) => !item.isRead).length;
    } catch (_) {
      // Keeps what it already shows; the next tick tries again.
    }
  }

  Future<void> markRead(AppNotification notification) async {
    if (notification.isRead) return;

    final index = notifications.indexWhere((item) => item.id == notification.id);

    // Optimistic: the dot disappears at once, and a failed write is repaired by
    // the next poll, which reads the truth.
    if (index != -1) {
      notifications[index] = notification.copyWith(isRead: true);
      unreadCount.value = notifications.where((item) => !item.isRead).length;
    }

    try {
      await _repository.markRead(notification.id);
    } catch (_) {
      // See above.
    }
  }

  Future<void> markAllRead() async {
    if (unreadCount.value == 0) return;

    final previous = notifications.toList();

    notifications.assignAll(
      previous.map((item) => item.copyWith(isRead: true)),
    );
    unreadCount.value = 0;

    try {
      await _repository.markAllRead(_session.currentUserId);
    } catch (_) {
      // See [markRead].
    }
  }

  /// Shows a toast for notifications that arrived since the last poll.
  void _announceNew(List<AppNotification> fetched) {
    final seen = _seen;
    _seen = fetched.map((item) => item.id).toSet();

    if (seen == null) return;

    final fresh = fetched
        .where((item) => !item.isRead && !seen.contains(item.id))
        .toList();

    if (fresh.isEmpty || Get.context == null) return;

    if (fresh.length == 1) {
      Get.snackbar(
        fresh.first.title,
        fresh.first.body,
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 4),
      );

      return;
    }

    Get.snackbar(
      'Tienes ${fresh.length} notificaciones nuevas',
      'Toca la campana para verlas.',
      snackPosition: SnackPosition.TOP,
      duration: const Duration(seconds: 4),
    );
  }

  @override
  void onClose() {
    _poller.stop();
    super.onClose();
  }
}
