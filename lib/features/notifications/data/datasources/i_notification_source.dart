import '../../domain/models/app_notification.dart';

/// Storage contract for notifications.
abstract class INotificationSource {
  /// Everything addressed to [userId], newest first.
  Future<List<AppNotification>> getForRecipient(String userId);

  /// Inserts every notification in one request. Fan-out is the reason this is a
  /// bulk call: a comment under a project with a ten-person team would
  /// otherwise be ten requests against a budget of 100 per minute.
  Future<void> insertAll(List<AppNotification> notifications);

  Future<void> markRead(String notificationId);
}
