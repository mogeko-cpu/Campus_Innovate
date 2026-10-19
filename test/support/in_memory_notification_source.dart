import 'package:campus_innovate/features/notifications/data/datasources/i_notification_source.dart';
import 'package:campus_innovate/features/notifications/domain/models/app_notification.dart';

/// [INotificationSource] in memory.
class InMemoryNotificationSource implements INotificationSource {
  final List<AppNotification> _notifications = [];

  var _nextId = 700;

  /// Everything that was sent, for the tests that assert on who got told.
  List<AppNotification> get all => List.unmodifiable(_notifications);

  @override
  Future<List<AppNotification>> getForRecipient(String userId) async {
    final mine = _notifications
        .where((notification) => notification.recipientId == userId)
        .toList();

    mine.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return mine;
  }

  @override
  Future<void> insertAll(List<AppNotification> notifications) async {
    for (final notification in notifications) {
      _notifications.add(
        AppNotification(
          id: 'notification_${_nextId++}',
          recipientId: notification.recipientId,
          type: notification.type,
          title: notification.title,
          body: notification.body,
          target: notification.target,
          targetId: notification.targetId,
          isRead: false,
          createdAt: notification.createdAt,
        ),
      );
    }
  }

  @override
  Future<void> markRead(String notificationId) async {
    final index = _notifications.indexWhere((item) => item.id == notificationId);

    if (index != -1) {
      _notifications[index] = _notifications[index].copyWith(isRead: true);
    }
  }
}
