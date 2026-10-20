import 'package:campus_innovate/features/notifications/domain/models/notification_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:integration_test/integration_test.dart';

import '../test/support/test_session.dart';
import 'flow_helpers.dart';

/// Un grupo de principio a fin: se crea, se invita a alguien, se escribe en el
/// chat, la persona invitada acepta y contesta.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  tearDown(Get.reset);

  testWidgets('crear un grupo, invitar, escribir en el chat y que la persona '
      'invitada entre y responda', (tester) async {
    final app = await CampusApp.start(tester, signedInAs: TestUsers.leonel);

    // Leonel crea el grupo.
    await app.goToTab('Grupos');
    await app.waitForText('Mis grupos');
    await app.tap(find.byType(FloatingActionButton));
    await app.waitForText('Arma tu equipo');

    await app.enter('Nombre del grupo', 'Club de Datos');
    await app.enter(
      'Descripción',
      'Analizamos datos abiertos de la ciudad cada semana.',
    );
    await app.tap(find.widgetWithText(FilledButton, 'Crear grupo'));

    await app.waitForText('Grupo creado');
    await app.waitForSnackbars();
    expect(find.text('Club de Datos'), findsOneWidget);

    // La invitación.
    await app.tapText('Club de Datos');
    await app.waitForText(
      'Este grupo es tuyo. Acepta o rechaza las solicitudes abajo.',
    );

    await app.tapText('Invitar');
    await app.waitForText('Invitar al grupo');
    await app.waitForText('Mariana Ospina');

    await app.tap(find.widgetWithText(FilledButton, 'Invitar'));
    await app.waitFor(find.widgetWithText(Chip, 'Invitación enviada'));
    await app.waitForSnackbars();

    await app.back();
    await app.waitForText('Invitaciones enviadas');
    expect(find.text('Invitó Leonel Triana · pendiente'), findsOneWidget);

    // El primer mensaje del chat.
    await app.tapText('Chat');
    await app.waitForText('Chat · Club de Datos');
    expect(find.text('Todavía no hay mensajes'), findsOneWidget);

    await app.enter(
      'Escribe un mensaje',
      'Bienvenidos al club, el jueves arrancamos.',
    );
    await app.tap(find.byTooltip('Enviar'));
    await app.waitForText('Bienvenidos al club, el jueves arrancamos.');

    await app.back();
    await app.back();
    await app.logOut();

    // Mariana acepta desde la pestaña de grupos.
    await app.logIn(TestUsers.mariana);
    await app.goToTab('Grupos');
    await app.waitForText('Invitaciones (1)');
    expect(find.text('Leonel Triana te invitó a unirte'), findsOneWidget);

    await app.tap(find.widgetWithText(FilledButton, 'Aceptar'));
    await app.waitForText('Ya eres parte de Club de Datos');
    await app.waitForSnackbars();

    expect(find.text('Invitaciones (1)'), findsNothing);
    expect(find.text('Integrante'), findsOneWidget);

    // Y contesta en el chat, donde ya está el mensaje de Leonel.
    await app.tapText('Club de Datos');
    await app.waitForText('Salir del grupo');
    await app.tapText('Chat');
    await app.waitForText('Bienvenidos al club, el jueves arrancamos.');

    await app.enter('Escribe un mensaje', 'Gracias, ahí estaré.');
    await app.tap(find.byTooltip('Enviar'));
    await app.waitForText('Gracias, ahí estaré.');

    expect(
      app.notifications.all.map((n) => (n.recipientId, n.type)),
      unorderedEquals([
        (TestUsers.mariana.id, NotificationType.invitationReceived),
        (TestUsers.leonel.id, NotificationType.invitationAccepted),
      ]),
    );
  });
}
