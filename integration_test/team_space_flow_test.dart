import 'package:campus_innovate/core/widgets/confirm_dialog.dart';
import 'package:campus_innovate/features/listings/domain/models/listing.dart';
import 'package:campus_innovate/features/listings/domain/models/listing_member.dart';
import 'package:campus_innovate/features/listings/domain/models/listing_role.dart';
import 'package:campus_innovate/features/notifications/domain/models/notification_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:integration_test/integration_test.dart';

import '../test/support/in_memory_listing_source.dart';
import '../test/support/test_session.dart';
import 'flow_helpers.dart';

/// El espacio de un equipo de principio a fin: el líder planea dos tareas,
/// termina una y cancela la otra, comparte un enlace y le pide mentoría a
/// alguien de afuera, que acepta y entra a seguir el proyecto.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  tearDown(Get.reset);

  const title = 'Tutorías entre pares';

  /// Leonel's project, with nobody else on it yet.
  Future<InMemoryListingSource> leonelsProject() async {
    final listings = InMemoryListingSource();

    await listings.createListing(
      Listing(
        id: '',
        title: title,
        description: 'Red de estudiantes que dictan refuerzos a compañeros '
            'de primeros semestres.',
        category: 'Impacto Social',
        creatorId: TestUsers.leonel.id,
        creatorName: TestUsers.leonel.name,
        maxMembers: 4,
        requiredSkills: const [],
        memberIds: [TestUsers.leonel.id],
        groupId: 'group_1',
        groupName: 'Innovación UN',
        members: [
          ListingMember(
            userId: TestUsers.leonel.id,
            userName: TestUsers.leonel.name,
            role: ListingRole.leader,
          ),
        ],
      ),
    );

    return listings;
  }

  Finder cardOf(String task) =>
      find.ancestor(of: find.text(task), matching: find.byType(Card));

  testWidgets('tareas con una cancelada, un enlace y una mentoría aceptada',
      (tester) async {
    final app = await CampusApp.start(
      tester,
      signedInAs: TestUsers.leonel,
      listings: await leonelsProject(),
    );

    // Leonel abre su proyecto desde "Mis proyectos".
    await app.waitFor(find.text(title));
    await app.tap(find.text(title).last);
    await app.waitForText('Espacio del equipo');

    // Dos tareas en el tablero.
    await app.tapText('Ver tablero');
    await app.waitForText('0%');

    for (final task in ['Armar el horario', 'Pedir patrocinio']) {
      await app.tap(find.widgetWithText(FloatingActionButton, 'Nueva tarea'));
      await app.enter('Título de la tarea', task);
      await app.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await app.waitFor(cardOf(task));
    }

    // Una se termina…
    await app.tap(
      find.descendant(
        of: cardOf('Armar el horario'),
        matching: find.byTooltip('Mover a En progreso'),
      ),
    );
    await app.tap(
      find.descendant(
        of: cardOf('Armar el horario'),
        matching: find.byTooltip('Mover a Hecho'),
      ),
    );
    await app.waitForText('50%');

    // …y la otra se cancela: sale de la cuenta.
    await app.tap(
      find.descendant(
        of: cardOf('Pedir patrocinio'),
        matching: find.byTooltip('Opciones de la tarea'),
      ),
    );
    await app.tapText('Cancelar tarea');
    await app.tap(
      find.descendant(
        of: find.byType(ConfirmDialog),
        matching: find.text('Cancelar tarea'),
      ),
    );
    await app.waitForText('100%');
    expect(find.text('Cancelado (1)'), findsOneWidget);

    await app.back();
    await app.waitForText('Espacio del equipo');
    expect(find.text('1 cancelada, fuera de la cuenta'), findsOneWidget);

    // Un enlace en la carpeta del equipo.
    await app.tapText('Ver archivos');
    await app.waitForText('Carpeta del equipo');
    await app.tapText('Agregar enlace');
    await app.enter('Nombre del enlace', 'Horario en Drive');
    await app.enter('Enlace', 'drive.google.com/tutorias');
    await app.tapText('Guardar enlace');
    await app.waitForText('Enlace guardado');
    await app.waitForSnackbars();
    expect(find.text('Horario en Drive'), findsOneWidget);

    await app.back();
    await app.waitForText('Espacio del equipo');

    // La mentoría se le pide a Mariana, que no está en el equipo.
    await app.tapText('Solicitar mentoría');
    await app.tapText('Mariana Ospina');
    await app.enter('Mensaje', '¿Nos ayudas a organizar el semestre?');
    await app.tapText('Enviar solicitud');
    await app.waitForText('Solicitud enviada');
    await app.waitForSnackbars();
    expect(
      find.text('Esperando la respuesta de Mariana Ospina.'),
      findsOneWidget,
    );

    await app.back();
    await app.logOut();

    // Mariana la ve en su inicio, acepta y entra al equipo como mentora.
    await app.logIn(TestUsers.mariana);
    await app.waitForText('Te piden ser mentor');
    await app.tapText('Leonel Triana te pidió acompañar al equipo');
    await app.waitForText('Leonel Triana te pidió ser mentor de este proyecto');

    await app.tap(find.widgetWithText(FilledButton, 'Aceptar'));
    await app.waitForText('Ahora eres mentor');
    await app.waitForSnackbars();

    expect(find.text('Espacio del equipo'), findsOneWidget);
    expect(find.text('Acompaña al equipo'), findsOneWidget);
    // She takes no seat: Leonel alone is the team.
    expect(find.text('1 de 4 integrantes'), findsOneWidget);

    await app.tapText('Ver archivos');
    await app.waitForText('Horario en Drive');
    await app.back();

    // Follows the board without moving it.
    await app.tapText('Ver tablero');
    await app.waitForText('100%');
    expect(find.widgetWithText(FloatingActionButton, 'Nueva tarea'), findsNothing);

    expect(
      app.notifications.all.map((n) => (n.recipientId, n.type)),
      unorderedEquals([
        (TestUsers.mariana.id, NotificationType.mentorshipRequested),
        (TestUsers.leonel.id, NotificationType.mentorshipAccepted),
      ]),
    );
  });
}
