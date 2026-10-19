import '../models/app_notification.dart';

abstract class INotificationRepository {
  /// The person's notifications, newest first.
  Future<List<AppNotification>> getMine(String userId);

  /// Stores one row per notification, in a single request.
  Future<void> send(List<AppNotification> notifications);

  Future<void> markRead(String notificationId);

  Future<void> markAllRead(String userId);
}
