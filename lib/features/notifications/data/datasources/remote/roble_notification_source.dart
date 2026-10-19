import '../../../../../core/roble/roble_client.dart';
import '../../../../../core/roble/roble_config.dart';
import '../../../domain/models/app_notification.dart';
import '../../../domain/models/notification_target.dart';
import '../../../domain/models/notification_type.dart';
import '../i_notification_source.dart';

/// Notifications stored in ROBLE.
class RobleNotificationSource implements INotificationSource {
  RobleNotificationSource(this._client);

  final RobleClient _client;

  /// Rows beyond this many are dropped from the list, newest kept. The table is
  /// never pruned, and a person who has been in the app for months should not
  /// pay for their whole history on every poll.
  static const _maxShown = 100;

  @override
  Future<List<AppNotification>> getForRecipient(String userId) async {
    final rows = await _client.read(
      RobleConfig.notificationsTable,
      filters: {'recipient_id': userId},
    );

    rows.sort(
      (a, b) => _dateOf(b['created_at']).compareTo(_dateOf(a['created_at'])),
    );

    return rows
        .map(_notificationFrom)
        .whereType<AppNotification>()
        .take(_maxShown)
        .toList();
  }

  @override
  Future<void> insertAll(List<AppNotification> notifications) async {
    if (notifications.isEmpty) return;

    final now = DateTime.now().toUtc().toIso8601String();

    // Partial success comes back as 200 with the rejects listed in `skipped`, and
    // it is deliberately not looked at: a notification that did not arrive must
    // never undo the comment or the acceptance that caused it.
    await _client.insertMany(RobleConfig.notificationsTable, [
      for (final notification in notifications)
        {
          'recipient_id': notification.recipientId,
          'type': notification.type?.name ?? '',
          'title': notification.title,
          'body': notification.body,
          'target_type': notification.target.name,
          'target_id': notification.targetId,
          // `int4` and not a boolean: 0 is unread and 1 is read.
          'is_read': 0,
          'created_at': now,
        },
    ]);
  }

  @override
  Future<void> markRead(String notificationId) async {
    await _client.update(
      tableName: RobleConfig.notificationsTable,
      idValue: notificationId,
      updates: {'is_read': 1},
    );
  }

  DateTime _dateOf(dynamic value) =>
      DateTime.tryParse(value?.toString() ?? '') ??
      DateTime.fromMillisecondsSinceEpoch(0);

  AppNotification? _notificationFrom(Map<String, dynamic> row) {
    final id = row['_id']?.toString();
    final recipientId = row['recipient_id']?.toString();
    if (id == null || id.isEmpty || recipientId == null) return null;

    return AppNotification(
      id: id,
      recipientId: recipientId,
      type: NotificationType.fromName(row['type']?.toString()),
      title: row['title']?.toString() ?? '',
      body: row['body']?.toString() ?? '',
      target: NotificationTarget.fromName(row['target_type']?.toString()),
      targetId: row['target_id']?.toString() ?? '',
      isRead: _readFlag(row['is_read']),
      createdAt: _dateOf(row['created_at']),
    );
  }

  /// `is_read` is an `int4`, but ROBLE has been seen returning numbers as text,
  /// so both are accepted.
  bool _readFlag(dynamic value) {
    if (value is num) return value != 0;

    return value?.toString() == '1' || value?.toString() == 'true';
  }
}
