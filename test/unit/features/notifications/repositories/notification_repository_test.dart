import 'package:campus_innovate/features/notifications/data/datasources/i_notification_source.dart';
import 'package:campus_innovate/features/notifications/data/repositories/notification_repository.dart';
import 'package:campus_innovate/features/notifications/domain/models/app_notification.dart';
import 'package:campus_innovate/features/notifications/domain/models/notification_target.dart';
import 'package:campus_innovate/features/notifications/domain/models/notification_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _RecordingSource source;
  late NotificationRepository repository;

  setUp(() {
    source = _RecordingSource();
    repository = NotificationRepository(source);
  });

  AppNotification stored(String id, String recipientId, {bool isRead = false}) =>
      AppNotification(
        id: id,
        recipientId: recipientId,
        type: NotificationType.comment,
        title: 't',
        body: 'b',
        target: NotificationTarget.none,
        targetId: '',
        isRead: isRead,
        createdAt: DateTime(2026),
      );

  test('enviar una lista vacía no hace ninguna petición', () async {
    await repository.send(const []);

    expect(source.insertCalls, 0);
  });

  test('enviar varias las inserta en una sola petición', () async {
    await repository.send([
      AppNotification.draft(
        recipientId: 'user_2',
        type: NotificationType.comment,
        title: 't',
        body: 'b',
      ),
      AppNotification.draft(
        recipientId: 'user_3',
        type: NotificationType.comment,
        title: 't',
        body: 'b',
      ),
    ]);

    expect(source.insertCalls, 1);
    expect(source.rows.map((n) => n.recipientId), ['user_2', 'user_3']);
  });

  test('getMine trae solo las de esa persona', () async {
    source.rows.addAll([stored('n1', 'user_2'), stored('n2', 'user_3')]);

    expect((await repository.getMine('user_2')).map((n) => n.id), ['n1']);
  });

  test('markRead marca una sola', () async {
    source.rows.addAll([stored('n1', 'user_2'), stored('n2', 'user_2')]);

    await repository.markRead('n1');

    expect(source.markedRead, ['n1']);
  });

  test('markAllRead solo actualiza las que estaban sin leer y son mías',
      () async {
    source.rows.addAll([
      stored('n1', 'user_2'),
      stored('n2', 'user_2', isRead: true),
      stored('n3', 'user_2'),
      stored('n4', 'user_3'),
    ]);

    await repository.markAllRead('user_2');

    // One update per unread row, and none for what was already read.
    expect(source.markedRead, ['n1', 'n3']);
  });

  test('markAllRead sin nada pendiente no escribe', () async {
    source.rows.add(stored('n1', 'user_2', isRead: true));

    await repository.markAllRead('user_2');

    expect(source.markedRead, isEmpty);
  });
}

/// Counts what reaches storage, which is what the repository is careful about.
class _RecordingSource implements INotificationSource {
  final List<AppNotification> rows = [];
  final List<String> markedRead = [];
  int insertCalls = 0;

  @override
  Future<List<AppNotification>> getForRecipient(String userId) async =>
      rows.where((n) => n.recipientId == userId).toList();

  @override
  Future<void> insertAll(List<AppNotification> notifications) async {
    insertCalls++;
    rows.addAll(notifications);
  }

  @override
  Future<void> markRead(String notificationId) async {
    markedRead.add(notificationId);

    final index = rows.indexWhere((n) => n.id == notificationId);
    if (index != -1) rows[index] = rows[index].copyWith(isRead: true);
  }
}
