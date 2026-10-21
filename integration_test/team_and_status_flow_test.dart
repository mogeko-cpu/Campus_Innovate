import 'package:campus_innovate/features/listings/domain/models/join_request.dart';
import 'package:campus_innovate/features/listings/domain/models/join_request_status.dart';
import 'package:campus_innovate/features/listings/domain/models/listing.dart';
import 'package:campus_innovate/features/listings/domain/models/listing_member.dart';
import 'package:campus_innovate/features/listings/domain/models/listing_role.dart';
import 'package:campus_innovate/features/listings/domain/models/listing_status.dart';
import 'package:campus_innovate/features/listings/ui/widgets/status_chip.dart';
import 'package:campus_innovate/features/notifications/domain/models/notification_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:integration_test/integration_test.dart';

import '../test/support/in_memory_listing_source.dart';
import '../test/support/test_session.dart';
import 'flow_helpers.dart';

/// Llevar un proyecto de principio a fin con su equipo: cambiar roles, ponerlo
/// en curso, pasarle el liderazgo a otra persona y que ella lo dé por
/// terminado, cerrando las solicitudes que quedaban.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  tearDown(Get.reset);

  const title = 'Radio Uninorte Online';

  /// Leonel leads it, Mariana is on the team, and Camilo is still waiting for
  /// an answer.
  Future<InMemoryListingSource> projectWithTeam() async {
    final listings = InMemoryListingSource();

    final project = await listings.createListing(
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

    await listings.createJoinRequest(
      JoinRequest.draft(
        listingId: project.id,
        applicantId: 'user_9',
        applicantName: 'Camilo Pérez',
        motivation: 'Hago radio comunitaria en mi barrio desde hace dos años.',
        skills: 'Locución',
        availability: 'Fines de semana',
      ),
    );

    return listings;
  }

  testWidgets('roles, estado y traspaso del liderazgo hasta terminar el '
      'proyecto', (tester) async {
    final listings = await projectWithTeam();
    final app = await CampusApp.start(
      tester,
      signedInAs: TestUsers.leonel,
      listings: listings,
    );

    await app.goToTab('Explorar');
    await app.waitForText('Explorar proyectos');
    await app.tapText(title);
    await app.waitForText('Detalle del proyecto');

    expect(find.text('Líder · tú'), findsOneWidget);
    expect(find.text('Integrante'), findsOneWidget);
    expect(find.text('Camilo Pérez'), findsOneWidget);

    // Mariana pasa a mentora.
    await app.tap(find.byTooltip('Opciones de Mariana Ospina'));
    await app.tapText('Hacer mentor');
    await app.waitForText('Rol actualizado');
    expect(find.text('Mentor'), findsOneWidget);
    await app.waitForSnackbars();

    // El proyecto arranca.
    await app.tap(find.byTooltip('Editar proyecto'));
    await app.waitForText('Guardar cambios');
    await app.tap(find.widgetWithText(ChoiceChip, 'En curso'));
    await app.tapText('Guardar cambios');
    await app.waitForText('Cambios guardados');
    // The detail reloads after the form closes; its chip is what says so.
    await app.waitFor(find.widgetWithText(StatusChip, 'En curso'));
    await app.waitForSnackbars();

    // Y Leonel le pasa el liderazgo.
    await app.tap(find.byTooltip('Opciones de Mariana Ospina'));
    await app.tapText('Transferir liderazgo');
    expect(find.text('¿Transferir el liderazgo?'), findsOneWidget);
    await app.tap(find.widgetWithText(FilledButton, 'Transferir'));
    await app.waitForText('Liderazgo transferido');

    expect(find.text('Ya formas parte de este equipo.'), findsOneWidget);
    expect(find.text('Salir del proyecto'), findsOneWidget);
    expect(find.byTooltip('Editar proyecto'), findsNothing);
    expect(find.byTooltip('Opciones de Mariana Ospina'), findsNothing);
    await app.waitForSnackbars();

    await app.back();
    await app.logOut();

    // Mariana, ahora líder, lo da por terminado.
    await app.logIn(TestUsers.mariana);
    await app.tap(find.byTooltip('Notificaciones'));
    await app.waitForText('Ahora lideras "$title"');
    await app.tapText('Ahora lideras "$title"');
    await app.waitForText('Detalle del proyecto');

    expect(find.text('Este es tu proyecto.'), findsOneWidget);

    await app.tap(find.byTooltip('Editar proyecto'));
    await app.waitForText('Guardar cambios');
    await app.tap(find.widgetWithText(ChoiceChip, 'Terminado'));
    expect(
      find.text(
        'Al guardar, las solicitudes pendientes se rechazan y el proyecto '
        'deja de recibir nuevas.',
      ),
      findsOneWidget,
    );
    await app.tapText('Guardar cambios');
    await app.waitForText('Cambios guardados');
    await app.waitFor(find.widgetWithText(StatusChip, 'Terminado'));
    expect(
      find.text('Este proyecto ya terminó y no recibe solicitudes.'),
      findsNothing,
    );

    // Further down a lazy list: built only once it is scrolled to.
    await tester.scrollUntilVisible(
      find.text('No hay solicitudes pendientes'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('No hay solicitudes pendientes'), findsOneWidget);
    await app.waitForSnackbars();

    final stored = await listings.getListingById('listing_100');
    expect(stored!.status, ListingStatus.done);
    expect(stored.leaderId, TestUsers.mariana.id);

    final requests = await listings.getRequestsForListing('listing_100');
    expect(requests.single.status, JoinRequestStatus.rejected);

    expect(
      app.notifications.all.map((n) => (n.recipientId, n.type)),
      unorderedEquals([
        (TestUsers.mariana.id, NotificationType.roleChanged),
        (TestUsers.mariana.id, NotificationType.roleChanged),
        ('user_9', NotificationType.requestRejected),
      ]),
    );
  });
}
