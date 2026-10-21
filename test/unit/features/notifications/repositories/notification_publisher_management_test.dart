import 'package:campus_innovate/features/notifications/domain/models/app_notification.dart';
import 'package:campus_innovate/features/notifications/domain/models/notification_target.dart';
import 'package:campus_innovate/features/notifications/domain/models/notification_type.dart';
import 'package:campus_innovate/features/notifications/domain/notification_publisher.dart';
import 'package:campus_innovate/features/notifications/domain/repositories/i_notification_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// The notifications project management raises: a task given to somebody, a
/// member taken off the team, a role or the leadership changing hands.
void main() {
  late _CapturingRepository repository;
  late NotificationPublisher publisher;

  setUp(() {
    repository = _CapturingRepository();
    publisher = NotificationPublisher(repository);
  });

  test('los tipos nuevos se leen de vuelta por su nombre', () {
    for (final type in [
      NotificationType.taskAssigned,
      NotificationType.memberRemoved,
      NotificationType.roleChanged,
    ]) {
      expect(NotificationType.fromName(type.name), type);
    }
  });

  group('taskAssigned', () {
    Future<void> assign({
      String taskTitle = 'Diseñar el logo',
      String assignerId = 'user_1',
      String assigneeId = 'user_2',
    }) =>
        publisher.taskAssigned(
          listingId: 'listing_1',
          listingTitle: 'Campus App',
          taskTitle: taskTitle,
          assignerId: assignerId,
          assignerName: 'Leonel',
          assigneeId: assigneeId,
        );

    test('avisa a quien recibe la tarea y lleva al proyecto', () async {
      await assign();

      final notification = repository.sent.single;
      expect(notification.recipientId, 'user_2');
      expect(notification.type, NotificationType.taskAssigned);
      expect(notification.title, 'Tienes una tarea nueva');
      expect(
        notification.body,
        'Leonel te asignó "Diseñar el logo" en "Campus App".',
      );
      expect(notification.target, NotificationTarget.listing);
      expect(notification.targetId, 'listing_1');
      expect(notification.isPersisted, isFalse);
    });

    test('quien se asigna una tarea a sí mismo no se avisa', () async {
      await assign(assigneeId: 'user_1');

      expect(repository.sendCalls, 0);
    });

    test('una tarea sin asignar no avisa a nadie', () async {
      await assign(assigneeId: '');

      expect(repository.sendCalls, 0);
    });

    test('un título largo o con saltos de línea se resume en una línea',
        () async {
      await assign(taskTitle: '  Revisar\n\n  ${'x' * 120}  ');

      final body = repository.sent.single.body;
      final quoted = body.substring(
        'Leonel te asignó "'.length,
        body.indexOf('" en "Campus App"'),
      );

      expect(quoted, hasLength(80));
      expect(quoted, startsWith('Revisar x'));
      expect(quoted, endsWith('...'));
    });
  });

  group('memberRemoved', () {
    test('avisa a la persona retirada', () async {
      await publisher.memberRemoved(
        listingId: 'listing_1',
        listingTitle: 'Campus App',
        deciderId: 'user_1',
        userId: 'user_3',
      );

      final notification = repository.sent.single;
      expect(notification.recipientId, 'user_3');
      expect(notification.type, NotificationType.memberRemoved);
      expect(notification.title, 'Ya no estás en un proyecto');
      expect(
        notification.body,
        'El líder te retiró del equipo de "Campus App".',
      );
      expect(notification.target, NotificationTarget.listing);
      expect(notification.targetId, 'listing_1');
    });

    test('no se avisa a quien tomó la decisión', () async {
      await publisher.memberRemoved(
        listingId: 'listing_1',
        listingTitle: 'Campus App',
        deciderId: 'user_1',
        userId: 'user_1',
      );

      expect(repository.sendCalls, 0);
    });
  });

  group('roleChanged', () {
    Future<AppNotification> change({
      required String roleLabel,
      required bool isLeadership,
    }) async {
      await publisher.roleChanged(
        listingId: 'listing_1',
        listingTitle: 'Campus App',
        deciderId: 'user_1',
        userId: 'user_3',
        roleLabel: roleLabel,
        isLeadership: isLeadership,
      );

      return repository.sent.last;
    }

    test('un rol nuevo se nombra en minúscula', () async {
      final notification = await change(
        roleLabel: 'Mentor',
        isLeadership: false,
      );

      expect(notification.recipientId, 'user_3');
      expect(notification.type, NotificationType.roleChanged);
      expect(notification.title, 'Tu rol cambió en "Campus App"');
      expect(notification.body, 'Ahora eres mentor del equipo.');
      expect(notification.target, NotificationTarget.listing);
      expect(notification.targetId, 'listing_1');
    });

    test('recibir el liderazgo tiene su propio mensaje', () async {
      final notification = await change(
        roleLabel: 'Líder',
        isLeadership: true,
      );

      expect(notification.type, NotificationType.roleChanged);
      expect(notification.title, 'Ahora lideras "Campus App"');
      expect(notification.body, 'Te transfirieron el liderazgo del proyecto.');
    });

    test('quien se cambia el rol a sí mismo no se avisa', () async {
      await publisher.roleChanged(
        listingId: 'listing_1',
        listingTitle: 'Campus App',
        deciderId: 'user_1',
        userId: 'user_1',
        roleLabel: 'Integrante',
        isLeadership: false,
      );

      expect(repository.sendCalls, 0);
    });
  });

  test('si avisar falla, el error no llega a quien gestionó el equipo',
      () async {
    // The removal or the role change is already stored; a bell that did not
    // ring must not make it look as if it failed.
    final failing = NotificationPublisher(_FailingRepository());

    await expectLater(
      failing.memberRemoved(
        listingId: 'listing_1',
        listingTitle: 'Campus App',
        deciderId: 'user_1',
        userId: 'user_3',
      ),
      completes,
    );
    await expectLater(
      failing.taskAssigned(
        listingId: 'listing_1',
        listingTitle: 'Campus App',
        taskTitle: 'Diseñar el logo',
        assignerId: 'user_1',
        assignerName: 'Leonel',
        assigneeId: 'user_2',
      ),
      completes,
    );
    await expectLater(
      failing.roleChanged(
        listingId: 'listing_1',
        listingTitle: 'Campus App',
        deciderId: 'user_1',
        userId: 'user_3',
        roleLabel: 'Líder',
        isLeadership: true,
      ),
      completes,
    );
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

class _FailingRepository extends _CapturingRepository {
  @override
  Future<void> send(List<AppNotification> notifications) async {
    throw StateError('ROBLE no responde');
  }
}
