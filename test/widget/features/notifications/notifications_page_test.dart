import 'package:campus_innovate/features/groups/ui/views/group_detail_page.dart';
import 'package:campus_innovate/features/notifications/domain/models/app_notification.dart';
import 'package:campus_innovate/features/notifications/domain/models/notification_target.dart';
import 'package:campus_innovate/features/notifications/domain/models/notification_type.dart';
import 'package:campus_innovate/features/notifications/ui/views/notifications_page.dart';
import 'package:campus_innovate/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/app_tester.dart';
import '../../../support/in_memory_notification_source.dart';
import '../../../support/test_bindings.dart';

Finder get _markAll => find.byTooltip('Marcar todas como leídas');

/// The dot the list puts on every unread row.
Finder get _unreadDots => find.byIcon(Icons.circle);

void main() {
  tearDown(Get.reset);

  Future<InMemoryNotificationSource> seeded() async {
    final source = InMemoryNotificationSource();

    await source.insertAll([
      AppNotification.draft(
        recipientId: 'user_1',
        type: NotificationType.requestReceived,
        title: 'Nueva solicitud',
        body: 'Mariana quiere entrar a Innovación UN',
        target: NotificationTarget.group,
        targetId: 'group_1',
      ),
      AppNotification.draft(
        recipientId: 'user_1',
        type: NotificationType.ideaPublished,
        title: 'Idea publicada',
        body: 'Tu grupo publicó un proyecto',
      ),
      // Somebody else's: never on Leonel's list.
      AppNotification.draft(
        recipientId: 'user_2',
        type: NotificationType.comment,
        title: 'Comentario para Mariana',
        body: 'No debería verse',
      ),
    ]);

    return source;
  }

  /// Opens the list the way a person does: from the bell, which is what loads
  /// the notification center.
  Future<void> openFromBell(
    WidgetTester tester, {
    InMemoryNotificationSource? source,
  }) async {
    await tester.pumpApp(
      route: AppRoutes.groups,
      bindings: TestBindings(notificationSource: source),
    );
    await tester.tap(find.byTooltip('Notificaciones'));
    await tester.pumpAndSettle();
  }

  IconButton markAllButton(WidgetTester tester) => tester.widget<IconButton>(
        find.ancestor(of: _markAll, matching: find.byType(IconButton)),
      );

  testWidgets('sin notificaciones muestra el estado vacío', (tester) async {
    await openFromBell(tester);

    expect(find.byType(NotificationsPage), findsOneWidget);
    expect(find.text('Todavía no tienes notificaciones'), findsOneWidget);
    expect(markAllButton(tester).onPressed, isNull);
  });

  testWidgets('lista solo las de la persona, con un punto en las no leídas',
      (tester) async {
    await openFromBell(tester, source: await seeded());

    expect(find.text('Nueva solicitud'), findsOneWidget);
    expect(find.text('Mariana quiere entrar a Innovación UN'), findsOneWidget);
    expect(find.text('Idea publicada'), findsOneWidget);
    expect(find.text('Comentario para Mariana'), findsNothing);
    expect(find.text('ahora'), findsNWidgets(2));
    expect(_unreadDots, findsNWidgets(2));
    expect(markAllButton(tester).onPressed, isNotNull);
  });

  testWidgets('marcar todas como leídas quita los puntos y apaga el botón',
      (tester) async {
    final source = await seeded();
    await openFromBell(tester, source: source);

    await tester.tap(_markAll);
    await tester.pumpAndSettle();

    expect(_unreadDots, findsNothing);
    expect(markAllButton(tester).onPressed, isNull);
    // Written through, not only on screen.
    final mine = await source.getForRecipient('user_1');
    expect(mine.every((item) => item.isRead), isTrue);
  });

  testWidgets('tocar una notificación abre su destino y la marca leída',
      (tester) async {
    final source = await seeded();
    await openFromBell(tester, source: source);

    await tester.tapText('Nueva solicitud');

    expect(find.byType(GroupDetailPage), findsOneWidget);
    expect(Get.currentRoute, AppRoutes.groupOf('group_1'));

    Get.back();
    await tester.pumpAndSettle();

    expect(find.byType(NotificationsPage), findsOneWidget);
    expect(_unreadDots, findsOneWidget);
    final opened = (await source.getForRecipient('user_1'))
        .firstWhere((item) => item.title == 'Nueva solicitud');
    expect(opened.isRead, isTrue);
  });

  testWidgets('una notificación sin destino solo se marca leída',
      (tester) async {
    await openFromBell(tester, source: await seeded());

    await tester.tapText('Idea publicada');

    expect(find.byType(NotificationsPage), findsOneWidget);
    expect(_unreadDots, findsOneWidget);
  });

  testWidgets('al volver, la campana cuenta solo las que siguen sin leer',
      (tester) async {
    await openFromBell(tester, source: await seeded());

    await tester.tapText('Idea publicada');
    Get.back();
    await tester.pumpAndSettle();

    final badge = tester.widget<Badge>(find.byType(Badge));
    expect(badge.isLabelVisible, isTrue);
    expect(
      find.descendant(of: find.byType(Badge), matching: find.text('1')),
      findsOneWidget,
    );
  });
}
