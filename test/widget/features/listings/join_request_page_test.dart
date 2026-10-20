import 'package:campus_innovate/features/listings/domain/listing_exception.dart';
import 'package:campus_innovate/features/listings/domain/models/join_request.dart';
import 'package:campus_innovate/features/listings/domain/models/join_request_status.dart';
import 'package:campus_innovate/features/listings/ui/views/join_request_page.dart';
import 'package:campus_innovate/features/listings/ui/views/listing_detail_page.dart';
import 'package:campus_innovate/features/notifications/domain/models/notification_type.dart';
import 'package:campus_innovate/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/app_tester.dart';
import '../../../support/in_memory_listing_source.dart';
import '../../../support/in_memory_notification_source.dart';
import '../../../support/test_bindings.dart';

/// The request is refused on the server side, as when the team filled up
/// between opening the form and sending it.
class _RefusingListingSource extends InMemoryListingSource {
  @override
  Future<JoinRequest> createJoinRequest(JoinRequest request) async =>
      throw const ListingException(
        'El proyecto ya alcanzó su número máximo de integrantes.',
      );
}

void main() {
  tearDown(Get.reset);

  const motivation = '¿Por qué quieres participar?';
  const skills = '¿Qué habilidades aportas?';
  const availability = 'Disponibilidad semanal';

  Finder sendButton() => find.widgetWithText(FilledButton, 'Enviar solicitud');

  /// From the project's detail, as the app does, so sending has a screen to go
  /// back to.
  Future<void> openForm(WidgetTester tester, {TestBindings? bindings}) async {
    await tester.pumpApp(
      route: AppRoutes.detailOf('listing_2'),
      bindings: bindings,
    );
    await tester.tapText('Solicitar unirme');
    expect(find.byType(JoinRequestPage), findsOneWidget);
  }

  Future<void> fill(WidgetTester tester) async {
    await tester.enterField(
      motivation,
      '  Quiero llevar lo aprendido en Ecología a un proyecto real.  ',
    );
    await tester.enterField(skills, ' Biología, trabajo de campo ');
    await tester.enterField(availability, ' 6 horas, martes y jueves ');
  }

  testWidgets('presenta el formulario con sus tres campos', (tester) async {
    await openForm(tester);

    expect(find.text('Preséntate al equipo'), findsOneWidget);
    expect(find.text(motivation), findsOneWidget);
    expect(find.text(skills), findsOneWidget);
    expect(find.text(availability), findsOneWidget);
    expect(
      tester.widget<FilledButton>(sendButton()).onPressed,
      isNotNull,
    );
  });

  testWidgets('enviar vacío muestra un mensaje por campo y no envía nada',
      (tester) async {
    final source = InMemoryListingSource();
    await openForm(tester, bindings: TestBindings(source: source));

    await tester.tapVisible(sendButton());

    expect(
      find.text('Cuéntanos tu motivación en al menos 15 caracteres'),
      findsOneWidget,
    );
    expect(find.text('Indica al menos una habilidad'), findsOneWidget);
    expect(find.text('Indica tu disponibilidad'), findsOneWidget);
    expect(find.byType(JoinRequestPage), findsOneWidget);
    expect(await source.getRequestsForListing('listing_2'), isEmpty);
  });

  testWidgets('una motivación corta o campos en blanco no pasan',
      (tester) async {
    await openForm(tester);

    // Fourteen characters once trimmed.
    await tester.enterField(motivation, '   Me interesa   ');
    await tester.enterField(skills, '    ');
    await tester.enterField(availability, 'Lunes');
    await tester.tapVisible(sendButton());

    expect(
      find.text('Cuéntanos tu motivación en al menos 15 caracteres'),
      findsOneWidget,
    );
    expect(find.text('Indica al menos una habilidad'), findsOneWidget);
    expect(find.text('Indica tu disponibilidad'), findsNothing);
  });

  testWidgets('enviar guarda la solicitud limpia, avisa al creador y vuelve '
      'al detalle', (tester) async {
    final source = InMemoryListingSource();
    final notifications = InMemoryNotificationSource();
    await openForm(
      tester,
      bindings: TestBindings(source: source, notificationSource: notifications),
    );

    await fill(tester);
    await tester.tapVisible(sendButton());

    expect(find.byType(ListingDetailPage), findsOneWidget);
    expect(find.text('Solicitud enviada'), findsOneWidget);
    expect(
      find.text('El creador del proyecto revisará tu postulación'),
      findsOneWidget,
    );

    final stored = await source.getRequestsForListing('listing_2');
    expect(stored, hasLength(1));
    expect(stored.single.applicantId, 'user_1');
    expect(stored.single.applicantName, 'Leonel Triana');
    expect(
      stored.single.motivation,
      'Quiero llevar lo aprendido en Ecología a un proyecto real.',
    );
    expect(stored.single.skills, 'Biología, trabajo de campo');
    expect(stored.single.availability, '6 horas, martes y jueves');
    expect(stored.single.status, JoinRequestStatus.pending);

    // The creator of "Huerta Universitaria" is user_3.
    expect(
      notifications.all.where(
        (n) =>
            n.recipientId == 'user_3' &&
            n.type == NotificationType.requestReceived,
      ),
      hasLength(1),
    );

    await tester.settleSnackbars();
  });

  testWidgets('si el servidor rechaza la solicitud lo dice y deja el '
      'formulario abierto', (tester) async {
    await openForm(
      tester,
      bindings: TestBindings(source: _RefusingListingSource()),
    );

    await fill(tester);
    await tester.tapVisible(sendButton());

    expect(find.text('Error'), findsOneWidget);
    expect(
      find.text('El proyecto ya alcanzó su número máximo de integrantes.'),
      findsOneWidget,
    );
    expect(find.byType(JoinRequestPage), findsOneWidget);
    // What was typed is still there to retry.
    expect(find.text(' 6 horas, martes y jueves '), findsOneWidget);

    await tester.settleSnackbars();
  });
}
