import '../../domain/models/app_notification.dart';
import '../../domain/repositories/i_notification_repository.dart';
import '../datasources/i_notification_source.dart';

class NotificationRepository implements INotificationRepository {
  final INotificationSource _source;

  NotificationRepository(this._source);

  @override
  Future<List<AppNotification>> getMine(String userId) =>
      _source.getForRecipient(userId);

  @override
  Future<void> send(List<AppNotification> notifications) async {
    if (notifications.isEmpty) return;

    await _source.insertAll(notifications);
  }

  @override
  Future<void> markRead(String notificationId) =>
      _source.markRead(notificationId);

  @override
  Future<void> markAllRead(String userId) async {
    final unread = (await _source.getForRecipient(userId))
        .where((notification) => !notification.isRead);

    // One update per row: ROBLE updates by `_id` only. The unread ones are the
    // few the person has not seen yet, not the whole history.
    for (final notification in unread) {
      await _source.markRead(notification.id);
    }
  }
}
