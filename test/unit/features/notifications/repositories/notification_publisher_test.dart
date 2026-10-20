import 'package:campus_innovate/features/notifications/domain/models/app_notification.dart';
import 'package:campus_innovate/features/notifications/domain/models/notification_target.dart';
import 'package:campus_innovate/features/notifications/domain/models/notification_type.dart';
import 'package:campus_innovate/features/notifications/domain/notification_publisher.dart';
import 'package:campus_innovate/features/notifications/domain/repositories/i_notification_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wording and recipients of each event. The fan-out of a comment, the
/// accepted/rejected types and the swallowed failure are already covered in
/// `group_collaboration_test.dart`.
void main() {
  late _CapturingRepository repository;
  late NotificationPublisher publisher;

  setUp(() {
    repository = _CapturingRepository();
    publisher = NotificationPublisher(repository);
  });

  group('commentAdded', () {
    Future<AppNotification> commentWith(String text) async {
      await publisher.commentAdded(
        listingId: 'listing_1',
        listingTitle: 'Robot',
        authorId: 'user_1',
        authorName: 'Leonel',
        comment: text,
        recipientIds: ['user_2'],
      );

      return repository.sent.single;
    }

    test('nombra el proyecto en el título y al autor en el cuerpo', () async {
      final notification = await commentWith('Me gusta');

      expect(notification.title, 'Nuevo comentario en "Robot"');
      expect(notification.body, 'Leonel: Me gusta');
    });

    test('colapsa los saltos de línea y espacios del comentario', () async {
      final notification = await commentWith('  Hola\n\n   mundo  ');

      expect(notification.body, 'Leonel: Hola mundo');
    });

    test('un comentario largo se corta a 80 caracteres con puntos', () async {
      final notification = await commentWith('a' * 200);
      final snippet = notification.body.substring('Leonel: '.length);

      expect(snippet, hasLength(80));
      expect(snippet, endsWith('...'));
      expect(snippet, startsWith('a' * 77));
    });

    test('uno de exactamente 80 caracteres no se corta', () async {
      final notification = await commentWith('b' * 80);

      expect(notification.body, 'Leonel: ${'b' * 80}');
    });

    test('si el único destinatario es el autor no envía nada', () async {
      await publisher.commentAdded(
        listingId: 'listing_1',
        listingTitle: 'Robot',
        authorId: 'user_1',
        authorName: 'Leonel',
        comment: 'nota para mí',
        recipientIds: ['user_1', ''],
      );

      expect(repository.sendCalls, 0);
    });

    test('todos los destinatarios van en un solo envío', () async {
      await publisher.commentAdded(
        listingId: 'listing_1',
        listingTitle: 'Robot',
        authorId: 'user_1',
        authorName: 'Leonel',
        comment: 'hola',
        recipientIds: ['user_2', 'user_3', 'user_4'],
      );

      expect(repository.sendCalls, 1);
      expect(repository.sent, hasLength(3));
    });
  });

  test('ideaPublished avisa al resto del grupo con el nombre del grupo',
      () async {
    await publisher.ideaPublished(
      listingId: 'listing_9',
      listingTitle: 'Huerta',
      groupName: 'Innovación UN',
      authorId: 'user_1',
      authorName: 'Leonel',
      recipientIds: ['user_1', 'user_2', 'user_3'],
    );

    expect(repository.sent.map((n) => n.recipientId), ['user_2', 'user_3']);

    final notification = repository.sent.first;
    expect(notification.type, NotificationType.ideaPublished);
    expect(notification.title, 'Nueva idea en Innovación UN');
    expect(notification.body, 'Leonel publicó "Huerta".');
    expect(notification.target, NotificationTarget.listing);
    expect(notification.targetId, 'listing_9');
  });

  group('joinRequestReceived', () {
    test('para un grupo habla del grupo', () async {
      await publisher.joinRequestReceived(
        target: NotificationTarget.group,
        targetId: 'group_1',
        targetName: 'Innovación UN',
        applicantId: 'user_2',
        applicantName: 'Mariana',
        recipientId: 'user_1',
      );

      final notification = repository.sent.single;
      expect(notification.recipientId, 'user_1');
      expect(notification.type, NotificationType.requestReceived);
      expect(notification.title, 'Nueva solicitud para tu grupo');
      expect(notification.body, 'Mariana quiere unirse a "Innovación UN".');
      expect(notification.target, NotificationTarget.group);
      expect(notification.targetId, 'group_1');
    });

    test('para un proyecto habla del proyecto', () async {
      await publisher.joinRequestReceived(
        target: NotificationTarget.listing,
        targetId: 'listing_1',
        targetName: 'Robot',
        applicantId: 'user_2',
        applicantName: 'Mariana',
        recipientId: 'user_1',
      );

      expect(repository.sent.single.title, 'Nueva solicitud para tu proyecto');
    });

    test('quien pide entrar a lo suyo no se avisa a sí mismo', () async {
      await publisher.joinRequestReceived(
        target: NotificationTarget.listing,
        targetId: 'listing_1',
        targetName: 'Robot',
        applicantId: 'user_1',
        applicantName: 'Leonel',
        recipientId: 'user_1',
      );

      expect(repository.sendCalls, 0);
    });
  });

  group('requestResolved', () {
    test('aceptada en un proyecto dice que ya hace parte', () async {
      await publisher.requestResolved(
        accepted: true,
        target: NotificationTarget.listing,
        targetId: 'listing_1',
        targetName: 'Robot',
        deciderId: 'user_1',
        applicantId: 'user_2',
      );

      final notification = repository.sent.single;
      expect(notification.title, 'Solicitud aceptada');
      expect(notification.body, 'Ya haces parte del proyecto "Robot".');
      expect(notification.target, NotificationTarget.listing);
    });

    test('rechazada en un grupo dice que fue rechazada', () async {
      await publisher.requestResolved(
        accepted: false,
        target: NotificationTarget.group,
        targetId: 'group_1',
        targetName: 'Innovación UN',
        deciderId: 'user_1',
        applicantId: 'user_2',
      );

      final notification = repository.sent.single;
      expect(notification.title, 'Solicitud rechazada');
      expect(
        notification.body,
        'Tu solicitud para unirte al grupo "Innovación UN" fue rechazada.',
      );
    });
  });

  test('invitationReceived avisa a la persona invitada', () async {
    await publisher.invitationReceived(
      groupId: 'group_1',
      groupName: 'Innovación UN',
      inviterId: 'user_1',
      inviterName: 'Leonel',
      inviteeId: 'user_2',
    );

    final notification = repository.sent.single;
    expect(notification.recipientId, 'user_2');
    expect(notification.type, NotificationType.invitationReceived);
    expect(notification.title, 'Te invitaron a un grupo');
    expect(notification.body, 'Leonel te invitó a unirte a "Innovación UN".');
    expect(notification.target, NotificationTarget.group);
    expect(notification.targetId, 'group_1');
  });

  group('invitationResolved', () {
    Future<AppNotification> resolve({required bool accepted}) async {
      await publisher.invitationResolved(
        accepted: accepted,
        groupId: 'group_1',
        groupName: 'Innovación UN',
        inviteeId: 'user_2',
        inviteeName: 'Mariana',
        inviterId: 'user_1',
      );

      return repository.sent.last;
    }

    test('aceptada avisa a quien invitó', () async {
      final notification = await resolve(accepted: true);

      expect(notification.recipientId, 'user_1');
      expect(notification.type, NotificationType.invitationAccepted);
      expect(notification.title, 'Invitación aceptada');
      expect(notification.body, 'Mariana aceptó unirse a "Innovación UN".');
    });

    test('rechazada avisa a quien invitó', () async {
      final notification = await resolve(accepted: false);

      expect(notification.type, NotificationType.invitationRejected);
      expect(notification.title, 'Invitación rechazada');
      expect(
        notification.body,
        'Mariana rechazó la invitación a "Innovación UN".',
      );
    });
  });

  test('todas salen como borradores sin leer', () async {
    await publisher.invitationReceived(
      groupId: 'group_1',
      groupName: 'G',
      inviterId: 'user_1',
      inviterName: 'L',
      inviteeId: 'user_2',
    );

    expect(repository.sent.single.isPersisted, isFalse);
    expect(repository.sent.single.isRead, isFalse);
  });
}

class _CapturingRepository implements INotificationRepository {
  final List<AppNotification> sent = [];
  int sendCalls = 0;

  @override
  Future<void> send(List<AppNotification> notifications) async {
    sendCalls++;
    sent.addAll(notifications);
  }

  @override
  Future<List<AppNotification>> getMine(String userId) async => const [];

  @override
  Future<void> markRead(String notificationId) async {}

  @override
  Future<void> markAllRead(String userId) async {}
}
