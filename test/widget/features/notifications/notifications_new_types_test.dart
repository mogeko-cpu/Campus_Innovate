import 'package:campus_innovate/features/listings/ui/views/listing_detail_page.dart';
import 'package:campus_innovate/features/notifications/data/repositories/notification_repository.dart';
import 'package:campus_innovate/features/notifications/domain/models/app_notification.dart';
import 'package:campus_innovate/features/notifications/domain/models/notification_target.dart';
import 'package:campus_innovate/features/notifications/domain/models/notification_type.dart';
import 'package:campus_innovate/features/notifications/domain/notification_publisher.dart';
import 'package:campus_innovate/features/notifications/ui/views/notifications_page.dart';
import 'package:campus_innovate/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/app_tester.dart';
import '../../../support/in_memory_notification_source.dart';
import '../../../support/test_bindings.dart';

void main() {
  tearDown(Get.reset);

  AppNotification draft(NotificationType type, String title, String body) =>
      AppNotification.draft(
        recipientId: 'user_1',
        type: type,
        title: title,
        body: body,
        target: NotificationTarget.listing,
        targetId: 'listing_1',
      );

  Future<InMemoryNotificationSource> seeded() async {
    final source = InMemoryNotificationSource();

    await source.insertAll([
      draft(
        NotificationType.taskAssigned,
        'Tienes una tarea nueva',
        'Mariana te asignó "Diseñar el logo" en "Campus App".',
      ),
      draft(
        NotificationType.memberRemoved,
        'Ya no estás en un proyecto',
        'El líder te retiró del equipo de "Campus App".',
      ),
      draft(
        NotificationType.roleChanged,
        'Tu rol cambió en "Campus App"',
        'Ahora eres mentor del equipo.',
      ),
    ]);

    return source;
  }

  Future<void> openFromBell(
    WidgetTester tester,
    InMemoryNotificationSource source,
  ) async {
    await tester.pumpApp(
      route: AppRoutes.groups,
      bindings: TestBindings(notificationSource: source),
    );
    await tester.tap(find.byTooltip('Notificaciones'));
    await tester.pumpAndSettle();
  }

  /// The icon on the row whose title is [title].
  Icon iconOf(WidgetTester tester, String title) => tester.widget<Icon>(
        find.descendant(
          of: find.ancestor(of: find.text(title), matching: find.byType(ListTile)),
          matching: find.descendant(
            of: find.byType(CircleAvatar),
            matching: find.byType(Icon),
          ),
        ),
      );

  ColorScheme colors(WidgetTester tester) =>
      Theme.of(tester.element(find.byType(NotificationsPage))).colorScheme;

  testWidgets('lista los tres tipos nuevos con su título y su texto',
      (tester) async {
    await openFromBell(tester, await seeded());

    expect(find.text('Tienes una tarea nueva'), findsOneWidget);
    expect(
      find.text('Mariana te asignó "Diseñar el logo" en "Campus App".'),
      findsOneWidget,
    );
    expect(find.text('Ya no estás en un proyecto'), findsOneWidget);
    expect(find.text('Tu rol cambió en "Campus App"'), findsOneWidget);
    expect(find.text('Ahora eres mentor del equipo.'), findsOneWidget);
    expect(find.byIcon(Icons.circle), findsNWidgets(3));
  });

  testWidgets('cada tipo nuevo tiene su propio ícono y color', (tester) async {
    await openFromBell(tester, await seeded());

    final task = iconOf(tester, 'Tienes una tarea nueva');
    final removed = iconOf(tester, 'Ya no estás en un proyecto');
    final role = iconOf(tester, 'Tu rol cambió en "Campus App"');

    expect(task.icon, Icons.task_alt);
    expect(task.color, colors(tester).primary);
    expect(removed.icon, Icons.person_remove_outlined);
    expect(removed.color, colors(tester).error);
    expect(role.icon, Icons.manage_accounts_outlined);
    expect(role.color, const Color(0xFF7A4FE0));
    // None of them falls back to the icon of an unknown type.
    expect(find.byIcon(Icons.notifications_outlined), findsNothing);
  });

  testWidgets('tocar una tarea asignada la marca leída y abre el proyecto',
      (tester) async {
    final source = await seeded();
    await openFromBell(tester, source);

    await tester.tap(find.text('Tienes una tarea nueva'));
    await tester.pumpAndSettle();

    expect(find.byType(ListingDetailPage), findsOneWidget);
    expect(find.text('Campus App'), findsWidgets);
    expect(
      source.all
          .firstWhere((n) => n.type == NotificationType.taskAssigned)
          .isRead,
      isTrue,
    );
  });

  testWidgets('lo que escribe el publicador se ve tal cual en la lista',
      (tester) async {
    final source = InMemoryNotificationSource();
    final publisher = NotificationPublisher(NotificationRepository(source));

    await publisher.roleChanged(
      listingId: 'listing_1',
      listingTitle: 'Campus App',
      deciderId: 'user_2',
      userId: 'user_1',
      roleLabel: 'Líder',
      isLeadership: true,
    );
    await publisher.memberRemoved(
      listingId: 'listing_1',
      listingTitle: 'Campus App',
      deciderId: 'user_2',
      userId: 'user_1',
    );
    await publisher.taskAssigned(
      listingId: 'listing_1',
      listingTitle: 'Campus App',
      taskTitle: 'Probar en iOS',
      assignerId: 'user_2',
      assignerName: 'Mariana Ospina',
      assigneeId: 'user_1',
    );

    await openFromBell(tester, source);

    expect(find.text('Ahora lideras "Campus App"'), findsOneWidget);
    expect(
      find.text('Te transfirieron el liderazgo del proyecto.'),
      findsOneWidget,
    );
    expect(
      find.text('El líder te retiró del equipo de "Campus App".'),
      findsOneWidget,
    );
    expect(
      find.text('Mariana Ospina te asignó "Probar en iOS" en "Campus App".'),
      findsOneWidget,
    );
  });
}
