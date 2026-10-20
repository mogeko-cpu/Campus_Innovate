import 'package:campus_innovate/features/notifications/data/repositories/notification_repository.dart';
import 'package:campus_innovate/features/notifications/domain/models/app_notification.dart';
import 'package:campus_innovate/features/notifications/domain/models/notification_type.dart';
import 'package:campus_innovate/features/notifications/ui/viewmodels/notification_center.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/in_memory_notification_source.dart';
import '../../../../support/test_session.dart';
import '../../view_model_harness.dart';

/// Fails on demand, and counts the reads and writes that reach it.
class _FlakySource extends InMemoryNotificationSource {
  bool failReads = false;
  bool failWrites = false;
  int reads = 0;
  int writes = 0;

  @override
  Future<List<AppNotification>> getForRecipient(String userId) async {
    reads++;
    if (failReads) throw StateError('notifications');

    return super.getForRecipient(userId);
  }

  @override
  Future<void> markRead(String notificationId) async {
    writes++;
    if (failWrites) throw StateError('notifications');

    return super.markRead(notificationId);
  }
}

void main() {
  setUpViewModelTests();

  late _FlakySource source;
  late TestSession session;
  late NotificationCenter center;

  setUp(() {
    source = _FlakySource();
    session = TestSession();
    center = NotificationCenter(NotificationRepository(source), session);
  });

  Future<void> notify(String recipientId, String title) => source.insertAll([
        AppNotification.draft(
          recipientId: recipientId,
          type: NotificationType.comment,
          title: title,
          body: 'Cuerpo de $title',
        ),
      ]);

  group('refresh', () {
    test('trae solo las de la persona y cuenta las no leídas', () async {
      await notify('user_1', 'Uno');
      await notify('user_1', 'Dos');
      await notify('user_1', 'Tres');
      await notify('user_2', 'Ajena');
      await source.markRead(
        (await source.getForRecipient('user_1')).first.id,
      );

      await center.refresh();

      expect(center.notifications, hasLength(3));
      expect(
        center.notifications.every((item) => item.recipientId == 'user_1'),
        isTrue,
      );
      expect(center.unreadCount.value, 2);
    });

    test('start carga de inmediato aunque el temporizador esté apagado',
        () async {
      await notify('user_1', 'Uno');

      center.start();
      await settle();

      expect(center.notifications, hasLength(1));
      expect(center.unreadCount.value, 1);
    });

    test('si cambia la persona empieza de cero con lo suyo', () async {
      await notify('user_1', 'De Leonel');
      await notify('user_2', 'De Mariana');
      await center.refresh();

      session.signInAs(TestUsers.mariana);
      await center.refresh();

      expect(center.notifications.map((item) => item.title), ['De Mariana']);
      expect(center.unreadCount.value, 1);
    });

    test('al cambiar de persona no deja lo anterior ni si la lectura falla',
        () async {
      await notify('user_1', 'De Leonel');
      await center.refresh();

      session.signInAs(TestUsers.mariana);
      source.failReads = true;
      await center.refresh();

      expect(center.notifications, isEmpty);
      expect(center.unreadCount.value, 0);
    });

    test('sin sesión no consulta nada', () async {
      session.signOut();

      await center.refresh();

      expect(source.reads, 0);
      expect(center.notifications, isEmpty);
    });

    test('si el repositorio falla conserva lo que ya mostraba', () async {
      await notify('user_1', 'Uno');
      await center.refresh();

      await notify('user_1', 'Dos');
      source.failReads = true;
      await center.refresh();

      expect(center.notifications.map((item) => item.title), ['Uno']);
      expect(center.unreadCount.value, 1);
    });

    test('las nuevas que llegan en un sondeo se agregan', () async {
      await notify('user_1', 'Uno');
      await center.refresh();

      await notify('user_1', 'Dos');
      await center.refresh();

      expect(center.notifications, hasLength(2));
      expect(center.unreadCount.value, 2);
    });
  });

  group('markRead', () {
    test('marca al instante y lo guarda', () async {
      await notify('user_1', 'Uno');
      await notify('user_1', 'Dos');
      await center.refresh();

      await center.markRead(center.notifications.first);

      expect(center.notifications.first.isRead, isTrue);
      expect(center.unreadCount.value, 1);
      final stored = await source.getForRecipient('user_1');
      expect(stored.where((item) => item.isRead), hasLength(1));
    });

    test('es optimista: aunque la escritura falle la marca se ve', () async {
      await notify('user_1', 'Uno');
      await center.refresh();
      source.failWrites = true;

      await center.markRead(center.notifications.first);

      expect(center.notifications.first.isRead, isTrue);
      expect(center.unreadCount.value, 0);
    });

    test('una ya leída no vuelve a escribirse', () async {
      await notify('user_1', 'Uno');
      await center.refresh();
      await center.markRead(center.notifications.first);
      final writes = source.writes;

      await center.markRead(center.notifications.first);

      expect(source.writes, writes);
    });
  });

  group('markAllRead', () {
    test('deja todo leído en pantalla y en el almacenamiento', () async {
      await notify('user_1', 'Uno');
      await notify('user_1', 'Dos');
      await center.refresh();

      await center.markAllRead();

      expect(center.unreadCount.value, 0);
      expect(center.notifications.every((item) => item.isRead), isTrue);
      final stored = await source.getForRecipient('user_1');
      expect(stored.every((item) => item.isRead), isTrue);
    });

    test('sin nada pendiente no escribe', () async {
      await center.refresh();

      await center.markAllRead();

      expect(source.writes, 0);
    });

    test('si la escritura falla la pantalla queda leída igual', () async {
      await notify('user_1', 'Uno');
      await center.refresh();
      source.failWrites = true;

      await center.markAllRead();

      expect(center.unreadCount.value, 0);
      expect(center.notifications.single.isRead, isTrue);
    });
  });

  group('reset', () {
    test('olvida la lista y el contador', () async {
      await notify('user_1', 'Uno');
      await center.refresh();

      center.reset();

      expect(center.notifications, isEmpty);
      expect(center.unreadCount.value, 0);
    });

    test('después de reset vuelve a cargar con normalidad', () async {
      await notify('user_1', 'Uno');
      await center.refresh();
      center.reset();

      await center.refresh();

      expect(center.notifications, hasLength(1));
      expect(center.unreadCount.value, 1);
    });
  });
}
