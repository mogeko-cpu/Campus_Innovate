import 'package:campus_innovate/features/notifications/domain/models/app_notification.dart';
import 'package:campus_innovate/features/notifications/domain/models/notification_target.dart';
import 'package:campus_innovate/features/notifications/domain/models/notification_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppNotification', () {
    test('un borrador no tiene id, está sin leer y sin destino', () {
      final draft = AppNotification.draft(
        recipientId: 'user_2',
        type: NotificationType.comment,
        title: 'Nuevo comentario',
        body: 'Leonel: hola',
      );

      expect(draft.id, isEmpty);
      expect(draft.isPersisted, isFalse);
      expect(draft.isRead, isFalse);
      expect(draft.target, NotificationTarget.none);
      expect(draft.targetId, isEmpty);
    });

    test('copyWith marca como leída sin tocar lo demás', () {
      final original = AppNotification(
        id: 'n1',
        recipientId: 'user_2',
        type: NotificationType.requestAccepted,
        title: 't',
        body: 'b',
        target: NotificationTarget.group,
        targetId: 'group_1',
        isRead: false,
        createdAt: DateTime(2026, 1, 2),
      );

      final read = original.copyWith(isRead: true);

      expect(read.isRead, isTrue);
      expect(read.id, 'n1');
      expect(read.recipientId, 'user_2');
      expect(read.type, NotificationType.requestAccepted);
      expect(read.title, 't');
      expect(read.body, 'b');
      expect(read.target, NotificationTarget.group);
      expect(read.targetId, 'group_1');
      expect(read.createdAt, DateTime(2026, 1, 2));
      expect(original.copyWith().isRead, isFalse);
    });

    test('admite un tipo desconocido para poder listarla igual', () {
      final unknown = AppNotification(
        id: 'n1',
        recipientId: 'u',
        type: null,
        title: 't',
        body: 'b',
        target: NotificationTarget.none,
        targetId: '',
        isRead: false,
        createdAt: DateTime(2026),
      );

      expect(unknown.type, isNull);
      expect(unknown.isPersisted, isTrue);
    });
  });

  group('NotificationType.fromName', () {
    test('lee cada tipo por su nombre', () {
      for (final type in NotificationType.values) {
        expect(NotificationType.fromName(type.name), type);
      }
    });

    test('un nombre desconocido o ausente es null', () {
      expect(NotificationType.fromName('pollVoted'), isNull);
      expect(NotificationType.fromName(null), isNull);
      expect(NotificationType.fromName('Comment'), isNull);
    });
  });

  group('NotificationTarget.fromName', () {
    test('lee cada destino por su nombre', () {
      expect(NotificationTarget.fromName('listing'), NotificationTarget.listing);
      expect(NotificationTarget.fromName('group'), NotificationTarget.group);
      expect(NotificationTarget.fromName('none'), NotificationTarget.none);
    });

    test('un nombre desconocido o ausente no lleva a ninguna parte', () {
      expect(NotificationTarget.fromName('profile'), NotificationTarget.none);
      expect(NotificationTarget.fromName(null), NotificationTarget.none);
    });
  });
}
