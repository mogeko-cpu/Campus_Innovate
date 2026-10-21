import 'package:campus_innovate/features/notifications/domain/models/app_notification.dart';
import 'package:campus_innovate/features/notifications/domain/models/notification_target.dart';
import 'package:campus_innovate/features/notifications/domain/models/notification_type.dart';
import 'package:campus_innovate/features/notifications/domain/notification_publisher.dart';
import 'package:campus_innovate/features/notifications/domain/repositories/i_notification_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// The notifications of finding a mentor: who is told, with what words, and
/// where opening them leads.
void main() {
  late _CapturingRepository repository;
  late NotificationPublisher publisher;

  setUp(() {
    repository = _CapturingRepository();
    publisher = NotificationPublisher(repository);
  });

  test('los tipos nuevos se leen de vuelta por su nombre', () {
    for (final type in [
      NotificationType.mentorshipRequested,
      NotificationType.mentorshipAccepted,
      NotificationType.mentorshipRejected,
    ]) {
      expect(NotificationType.fromName(type.name), type);
    }
  });

  test('la solicitud le llega a quien se le pide y abre el proyecto', () async {
    await publisher.mentorshipRequested(
      listingId: 'listing_1',
      listingTitle: 'Robot',
      requesterId: 'user_1',
      requesterName: 'Leonel',
      mentorId: 'prof_1',
    );

    final notification = repository.sent.single;
    expect(notification.recipientId, 'prof_1');
    expect(notification.type, NotificationType.mentorshipRequested);
    expect(notification.title, 'Te pidieron ser mentor');
    expect(
      notification.body,
      'Leonel quiere que acompañes el proyecto "Robot".',
    );
    expect(notification.target, NotificationTarget.listing);
    expect(notification.targetId, 'listing_1');
  });

  test('aceptar le avisa al equipo una vez a cada uno, sin el mentor',
      () async {
    await publisher.mentorshipResolved(
      accepted: true,
      listingId: 'listing_1',
      listingTitle: 'Robot',
      mentorId: 'prof_1',
      mentorName: 'Profesora Díaz',
      recipientIds: ['user_1', 'user_2', 'user_1', 'prof_1'],
    );

    expect(repository.sent.map((n) => n.recipientId), ['user_1', 'user_2']);
    expect(repository.sent.first.type, NotificationType.mentorshipAccepted);
    expect(repository.sent.first.title, 'Su proyecto ya tiene mentor');
    expect(
      repository.sent.first.body,
      'Profesora Díaz aceptó acompañar "Robot".',
    );
  });

  test('rechazar dice que pueden pedírsela a otra persona', () async {
    await publisher.mentorshipResolved(
      accepted: false,
      listingId: 'listing_1',
      listingTitle: 'Robot',
      mentorId: 'prof_1',
      mentorName: 'Profesora Díaz',
      recipientIds: ['user_1'],
    );

    final notification = repository.sent.single;
    expect(notification.type, NotificationType.mentorshipRejected);
    expect(notification.title, 'Solicitud de mentoría rechazada');
    expect(notification.body, contains('Pueden pedírsela a otra persona.'));
  });
}

class _CapturingRepository implements INotificationRepository {
  final List<AppNotification> sent = [];

  @override
  Future<void> send(List<AppNotification> notifications) async =>
      sent.addAll(notifications);

  @override
  Future<List<AppNotification>> getMine(String userId) async => const [];

  @override
  Future<void> markRead(String notificationId) async {}

  @override
  Future<void> markAllRead(String userId) async {}
}
