import 'notification_target.dart';
import 'notification_type.dart';

/// Something one person has to be told: a comment on their project, a request
/// that was accepted, an invitation.
///
/// One row per recipient — a comment seen by five people is five rows — which
/// makes "mark as read" a single update on the person's own row, with nobody
/// else's state involved.
class AppNotification {
  /// `_id` of the row in `notifications`; empty on a draft.
  final String id;
  final String recipientId;

  /// Null when the row was written by a newer version of the app with a type this
  /// one does not know. It is still shown, with a generic icon.
  final NotificationType? type;
  final String title;
  final String body;
  final NotificationTarget target;
  final String targetId;
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.recipientId,
    required this.type,
    required this.title,
    required this.body,
    required this.target,
    required this.targetId,
    required this.isRead,
    required this.createdAt,
  });

  /// A notification as the code that raises it leaves it: no [id] yet, unread,
  /// dated now.
  AppNotification.draft({
    required this.recipientId,
    required NotificationType this.type,
    required this.title,
    required this.body,
    this.target = NotificationTarget.none,
    this.targetId = '',
  })  : id = '',
        isRead = false,
        createdAt = DateTime.now();

  bool get isPersisted => id.isNotEmpty;

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      recipientId: recipientId,
      type: type,
      title: title,
      body: body,
      target: target,
      targetId: targetId,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
    );
  }
}
