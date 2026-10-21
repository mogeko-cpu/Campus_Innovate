import 'package:campus_innovate/features/listings/domain/models/listing.dart';
import 'package:campus_innovate/features/listings/domain/models/listing_member.dart';
import 'package:campus_innovate/features/listings/domain/models/listing_role.dart';
import 'package:campus_innovate/features/listings/domain/models/task_column.dart';
import 'package:campus_innovate/features/notifications/domain/models/notification_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:integration_test/integration_test.dart';

import '../test/support/in_memory_listing_source.dart';
import '../test/support/test_session.dart';
import 'flow_helpers.dart';

/// El tablero de un proyecto entre dos personas: el líder crea y reparte las
/// tareas, la integrante se entera, avanza la suya y el avance se ve en el
/// proyecto.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  tearDown(Get.reset);

  const title = 'Radio Uninorte Online';

  /// Leonel leads it and Mariana is already on the team.
  Future<InMemoryListingSource> projectWithTeam() async {
    final listings = InMemoryListingSource();

    await listings.createListing(
      Listing(
        id: '',
        title: title,
        description: 'Una emisora estudiantil por internet con programas '
            'hechos por cada facultad.',
        category: 'Arte y Cultura',
        creatorId: TestUsers.leonel.id,
        creatorName: TestUsers.leonel.name,
        maxMembers: 5,
        requiredSkills: const ['Edición de audio'],
        memberIds: [TestUsers.leonel.id, TestUsers.mariana.id],
        groupId: 'group_1',
        groupName: 'Innovación UN',
        members: [
          ListingMember(
            userId: TestUsers.leonel.id,
            userName: TestUsers.leonel.name,
            role: ListingRole.leader,
          ),
          ListingMember(
            userId: TestUsers.mariana.id,
            userName: TestUsers.mariana.name,
            role: ListingRole.member,
          ),
        ],
      ),
    );

    return listings;
  }

  /// The card that holds [taskTitle], to press its own buttons.
  Finder cardOf(String taskTitle) => find.ancestor(
        of: find.text(taskTitle),
        matching: find.byType(Card),
      );

  Future<void> openProject(CampusApp app) async {
    await app.goToTab('Explorar');
    await app.waitForText('Explorar proyectos');
    await app.tapText(title);
    await app.waitForText('Detalle del proyecto');
  }

  Future<void> createTask(
    CampusApp app,
    WidgetTester tester, {
    required String taskTitle,
    String? assignee,
  }) async {
    await app.tap(find.text('Nueva tarea'));
    await app.waitFor(find.widgetWithText(AlertDialog, 'Nueva tarea'));
    await app.enter('Título de la tarea', taskTitle);

    if (assignee != null) {
      await app.tap(find.byType(DropdownButtonFormField<String>));
      await app.tap(find.text(assignee).last);
    }

    await app.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await app.waitForText(taskTitle);
  }

  testWidgets('el líder reparte tareas y la integrante avanza la suya',
      (tester) async {
    final app = await CampusApp.start(
      tester,
      signedInAs: TestUsers.leonel,
      listings: await projectWithTeam(),
    );

    // Leonel arma el tablero.
    await openProject(app);
    expect(find.text('Todavía no hay tareas'), findsOneWidget);

    await app.tapText('Ver tablero');
    await app.waitForText('Tareas · $title');
    expect(find.text('0 de 0 tareas hechas'), findsOneWidget);

    await createTask(
      app,
      tester,
      taskTitle: 'Diseñar el logo',
      assignee: TestUsers.mariana.name,
    );
    await createTask(app, tester, taskTitle: 'Escribir el reglamento');

    expect(find.text('0 de 2 tareas hechas'), findsOneWidget);
    expect(
      find.descendant(
        of: cardOf('Escribir el reglamento'),
        matching: find.text('Sin asignar'),
      ),
      findsOneWidget,
    );

    await app.tap(
      find.descendant(
        of: cardOf('Diseñar el logo'),
        matching: find.byTooltip('Mover a En progreso'),
      ),
    );
    await app.waitForText('En progreso (1)');

    await app.back();
    await app.waitForText('0 de 2 tareas hechas');
    await app.back();
    await app.logOut();

    // Mariana se entera por la campana y termina su tarea.
    await app.logIn(TestUsers.mariana);
    await app.tap(find.byTooltip('Notificaciones'));
    await app.waitForText('Tienes una tarea nueva');
    expect(
      find.text('Leonel Triana te asignó "Diseñar el logo" en "$title".'),
      findsOneWidget,
    );

    await app.tapText('Tienes una tarea nueva');
    await app.waitForText('Detalle del proyecto');
    await app.tapText('Ver tablero');
    await app.waitForText('Tareas · $title');

    await app.tap(
      find.descendant(
        of: cardOf('Diseñar el logo'),
        matching: find.byTooltip('Mover a Hecho'),
      ),
    );
    await app.waitForText('1 de 2 tareas hechas');

    // A member may edit somebody else's card but only its author or the leader
    // may delete it.
    await app.tap(
      find.descendant(
        of: cardOf('Escribir el reglamento'),
        matching: find.byTooltip('Opciones de la tarea'),
      ),
    );
    expect(find.text('Editar'), findsOneWidget);
    expect(find.text('Eliminar'), findsNothing);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    await app.back();
    await app.waitForText('1 de 2 tareas hechas');

    final stored = app.tasks.all;
    expect(
      stored.map((task) => (task.title, task.column)),
      unorderedEquals([
        ('Diseñar el logo', TaskColumn.done),
        ('Escribir el reglamento', TaskColumn.todo),
      ]),
    );
    expect(
      app.notifications.all.map((n) => (n.recipientId, n.type)),
      [(TestUsers.mariana.id, NotificationType.taskAssigned)],
    );
  });
}
