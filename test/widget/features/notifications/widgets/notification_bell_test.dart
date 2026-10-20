import 'package:campus_innovate/core/poller.dart';
import 'package:campus_innovate/features/notifications/data/repositories/notification_repository.dart';
import 'package:campus_innovate/features/notifications/domain/models/app_notification.dart';
import 'package:campus_innovate/features/notifications/domain/models/notification_type.dart';
import 'package:campus_innovate/features/notifications/ui/viewmodels/notification_center.dart';
import 'package:campus_innovate/features/notifications/ui/widgets/notification_bell.dart';
import 'package:campus_innovate/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../../support/in_memory_notification_source.dart';
import '../../../../support/test_bindings.dart';

void main() {
  late InMemoryNotificationSource source;

  setUp(() {
    Poller.enabled = false;
    source = InMemoryNotificationSource();
  });

  tearDown(Get.reset);

  Future<void> seed(int count, {String recipientId = 'user_1'}) {
    return source.insertAll([
      for (var i = 0; i < count; i++)
        AppNotification.draft(
          recipientId: recipientId,
          type: NotificationType.comment,
          title: 'Comentario $i',
          body: 'Alguien comentó tu proyecto',
        ),
    ]);
  }

  /// The bell alone in an app bar, with a stand-in for the notifications route
  /// so the tap can be followed without the real screen.
  Future<NotificationCenter> pumpBell(WidgetTester tester) async {
    final center = Get.put(
      NotificationCenter(
        NotificationRepository(source),
        const FakeSessionService(),
      ),
    );

    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: '/',
        getPages: [
          GetPage(
            name: '/',
            page: () => Scaffold(
              appBar: AppBar(actions: const [NotificationBell()]),
            ),
          ),
          GetPage(
            name: AppRoutes.notifications,
            page: () => const Scaffold(body: Text('Pantalla de notificaciones')),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    return center;
  }

  Badge badge(WidgetTester tester) => tester.widget<Badge>(find.byType(Badge));

  testWidgets('sin notificaciones sin leer no muestra el contador',
      (tester) async {
    await pumpBell(tester);

    expect(badge(tester).isLabelVisible, isFalse);
  });

  testWidgets('cuenta solo las notificaciones sin leer de la persona',
      (tester) async {
    await seed(3);
    // Somebody else's: must not be counted.
    await seed(2, recipientId: 'user_2');

    await pumpBell(tester);

    expect(badge(tester).isLabelVisible, isTrue);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('con más de 9 sin leer muestra "9+"', (tester) async {
    await seed(12);

    await pumpBell(tester);

    expect(find.text('9+'), findsOneWidget);
    expect(find.text('12'), findsNothing);
  });

  testWidgets('el contador baja cuando el centro marca una como leída',
      (tester) async {
    await seed(2);

    final center = await pumpBell(tester);
    expect(find.text('2'), findsOneWidget);

    await center.markRead(center.notifications.first);
    await tester.pump();

    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('tocar la campana abre la ruta de notificaciones',
      (tester) async {
    await pumpBell(tester);

    await tester.tap(find.byTooltip('Notificaciones'));
    await tester.pumpAndSettle();

    expect(Get.currentRoute, AppRoutes.notifications);
    expect(find.text('Pantalla de notificaciones'), findsOneWidget);
  });
}
