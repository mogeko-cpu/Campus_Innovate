import 'package:campus_innovate/features/home/ui/widgets/action_card.dart';
import 'package:campus_innovate/features/notifications/domain/models/notification_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:integration_test/integration_test.dart';

import '../test/support/test_session.dart';
import 'flow_helpers.dart';

/// Dos personas en la misma app: una publica, otra pide entrar, la primera
/// acepta y la segunda se entera y ve el proyecto en su perfil.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  tearDown(Get.reset);

  testWidgets('pedir unirse a un proyecto, que el creador acepte y que el '
      'postulante se entere', (tester) async {
    final app = await CampusApp.start(tester, signedInAs: TestUsers.leonel);

    // Leonel publica.
    await app.tap(find.widgetWithText(ActionCard, 'Publicar idea'));
    await app.waitForText('Cuéntanos tu idea');
    await app.enter('Título del proyecto', 'Banco de apuntes');
    await app.enter(
      'Descripción',
      'Un repositorio de apuntes revisados por monitores para cada materia.',
    );
    await app.tapText('Publicar proyecto');
    await app.waitForText('Proyecto publicado');
    await app.waitForSnackbars();

    await app.logOut();

    // Mariana pide entrar.
    await app.logIn(TestUsers.mariana);
    await app.goToTab('Explorar');
    await app.waitForText('Explorar proyectos');
    await app.tapText('Banco de apuntes');
    await app.waitForText('Detalle del proyecto');

    expect(find.text('1 de 4 integrantes'), findsOneWidget);

    await app.tapText('Solicitar unirme');
    await app.waitForText('Preséntate al equipo');

    // Too short a motivation is stopped by the form.
    await app.enter('¿Por qué quieres participar?', 'Me gusta');
    await app.tap(find.widgetWithText(FilledButton, 'Enviar solicitud'));
    expect(
      find.text('Cuéntanos tu motivación en al menos 15 caracteres'),
      findsOneWidget,
    );

    await app.enter(
      '¿Por qué quieres participar?',
      'Fui monitora de Cálculo y tengo apuntes de tres semestres.',
    );
    await app.enter('¿Qué habilidades aportas?', 'Cálculo, edición');
    await app.enter('Disponibilidad semanal', '5 horas, martes y jueves');
    await app.tap(find.widgetWithText(FilledButton, 'Enviar solicitud'));

    await app.waitForText('Solicitud enviada — estado: Pendiente.');
    expect(find.text('Solicitar unirme'), findsNothing);
    await app.waitForSnackbars();

    await app.back();
    await app.logOut();

    // Leonel ve la campana, abre la notificación y acepta.
    await app.logIn(TestUsers.leonel);
    await app.waitFor(
      find.descendant(of: find.byType(Badge), matching: find.text('1')),
    );

    await app.tap(find.byTooltip('Notificaciones'));
    await app.waitForText('Nueva solicitud para tu proyecto');
    expect(
      find.text('Mariana Ospina quiere unirse a "Banco de apuntes".'),
      findsOneWidget,
    );

    await app.tapText('Nueva solicitud para tu proyecto');
    await app.waitForText('Detalle del proyecto');
    await app.waitForText('Mariana Ospina');

    await app.tap(find.widgetWithText(FilledButton, 'Aceptar'));
    await app.waitForText('Solicitud aceptada');
    await app.waitForText('2 de 4 integrantes');
    expect(find.text('No hay solicitudes pendientes'), findsOneWidget);
    await app.waitForSnackbars();

    await app.back();
    await app.back();
    await app.logOut();

    // Mariana se entera y lo ve en su perfil.
    await app.logIn(TestUsers.mariana);
    await app.tap(find.byTooltip('Notificaciones'));
    await app.waitForText('Solicitud aceptada');
    expect(
      find.text('Ya haces parte del proyecto "Banco de apuntes".'),
      findsOneWidget,
    );

    await app.back();
    await app.goToTab('Perfil');
    await app.waitForText('Proyectos en los que participo');

    expect(find.text('Banco de apuntes'), findsOneWidget);
    expect(find.text('Aceptada'), findsOneWidget);

    // Each person was told exactly what concerned them.
    expect(
      app.notifications.all.map((n) => (n.recipientId, n.type)),
      unorderedEquals([
        (TestUsers.leonel.id, NotificationType.requestReceived),
        (TestUsers.mariana.id, NotificationType.requestAccepted),
      ]),
    );
  });
}
