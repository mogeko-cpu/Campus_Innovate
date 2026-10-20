import 'package:campus_innovate/features/groups/domain/group_exception.dart';
import 'package:campus_innovate/features/groups/domain/models/group.dart';
import 'package:campus_innovate/features/groups/domain/models/group_invitation.dart';
import 'package:campus_innovate/features/groups/domain/models/group_request.dart';
import 'package:campus_innovate/features/groups/ui/views/create_group_page.dart';
import 'package:campus_innovate/features/groups/ui/views/group_detail_page.dart';
import 'package:campus_innovate/features/groups/ui/widgets/group_card.dart';
import 'package:campus_innovate/features/groups/ui/widgets/invitation_card.dart';
import 'package:campus_innovate/features/listings/domain/models/listing.dart';
import 'package:campus_innovate/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/app_tester.dart';
import '../../../support/in_memory_group_source.dart';
import '../../../support/in_memory_listing_source.dart';
import '../../../support/in_memory_notification_source.dart';
import '../../../support/test_bindings.dart';
import '../../../support/test_session.dart';

/// A source whose list cannot be read, for the error state of the screen.
class _UnreachableGroupSource extends InMemoryGroupSource {
  @override
  Future<List<Group>> getGroups() async =>
      throw const GroupException('Sin conexión con ROBLE');
}

/// What the header chip shows above [label]: the chip is a column with the
/// value first.
String _headerValue(WidgetTester tester, String label) {
  final chip = find
      .ancestor(of: find.text(label), matching: find.byType(Column))
      .first;

  return tester
      .widgetList<Text>(find.descendant(of: chip, matching: find.byType(Text)))
      .first
      .data!;
}

Finder _cardOf(String name) => find.widgetWithText(GroupCard, name);

GroupInvitation _invitationForMariana() => const GroupInvitation.draft(
      groupId: 'group_1',
      groupName: 'Innovación UN',
      inviterId: 'user_1',
      inviterName: 'Leonel Triana',
      inviteeId: 'user_2',
      inviteeName: 'Mariana Ospina',
    );

void main() {
  tearDown(Get.reset);

  testWidgets('el encabezado cuenta los grupos propios y los del campus',
      (tester) async {
    await tester.pumpApp(route: AppRoutes.groups);

    expect(_headerValue(tester, 'tuyos'), '1');
    expect(_headerValue(tester, 'en el campus'), '0');
  });

  testWidgets('"Mis grupos" lista el grupo propio con la insignia Creador',
      (tester) async {
    await tester.pumpApp(route: AppRoutes.groups);

    expect(find.text('Mis grupos'), findsOneWidget);
    expect(_cardOf('Innovación UN'), findsOneWidget);
    expect(
      find.descendant(of: _cardOf('Innovación UN'), matching: find.text('Creador')),
      findsOneWidget,
    );
    expect(find.text('No hay otros grupos por ahora'), findsOneWidget);
  });

  testWidgets('la tarjeta cuenta los proyectos publicados por el grupo',
      (tester) async {
    final listings = InMemoryListingSource();
    await listings.createListing(
      const Listing(
        id: '',
        title: 'Tutorías entre pares',
        description: 'Refuerzos para primeros semestres.',
        category: 'Impacto Social',
        creatorId: 'user_1',
        creatorName: 'Leonel Triana',
        maxMembers: 4,
        requiredSkills: [],
        memberIds: ['user_1'],
        groupId: 'group_1',
        groupName: 'Innovación UN',
      ),
    );

    await tester.pumpApp(
      route: AppRoutes.groups,
      bindings: TestBindings(source: listings),
    );

    // One member and one project, both drawn as "1" inside the card.
    expect(
      find.descendant(of: _cardOf('Innovación UN'), matching: find.text('1')),
      findsNWidgets(2),
    );
  });

  testWidgets('quien no tiene grupos ve el estado vacío y los demás del campus',
      (tester) async {
    await tester.pumpApp(
      route: AppRoutes.groups,
      bindings: TestBindings(session: TestSession(TestUsers.mariana)),
    );

    expect(find.text('Todavía no tienes grupos'), findsOneWidget);
    expect(_cardOf('Innovación UN'), findsOneWidget);
    expect(find.text('No hay otros grupos por ahora'), findsNothing);
    expect(_headerValue(tester, 'tuyos'), '0');
    expect(_headerValue(tester, 'en el campus'), '1');
  });

  testWidgets('una solicitud pendiente marca el grupo del campus',
      (tester) async {
    final groups = InMemoryGroupSource();
    await groups.createRequest(
      const GroupRequest.draft(
        groupId: 'group_1',
        applicantId: 'user_2',
        applicantName: 'Mariana Ospina',
        message: 'Me interesa',
      ),
    );

    await tester.pumpApp(
      route: AppRoutes.groups,
      bindings: TestBindings(
        groupSource: groups,
        session: TestSession(TestUsers.mariana),
      ),
    );

    expect(
      find.descendant(
        of: _cardOf('Innovación UN'),
        matching: find.text('Solicitud pendiente'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('sin invitaciones no aparece la sección', (tester) async {
    await tester.pumpApp(route: AppRoutes.groups);

    expect(find.byType(InvitationCard), findsNothing);
    expect(find.textContaining('Invitaciones'), findsNothing);
  });

  testWidgets(
      'aceptar una invitación avisa, la quita y pasa el grupo a "Mis grupos"',
      (tester) async {
    final groups = InMemoryGroupSource();
    final notifications = InMemoryNotificationSource();
    await groups.createInvitation(_invitationForMariana());

    await tester.pumpApp(
      route: AppRoutes.groups,
      bindings: TestBindings(
        groupSource: groups,
        notificationSource: notifications,
        session: TestSession(TestUsers.mariana),
      ),
    );

    expect(find.text('Invitaciones (1)'), findsOneWidget);
    expect(find.byType(InvitationCard), findsOneWidget);

    await tester.tapVisible(
      find.descendant(
        of: find.byType(InvitationCard),
        matching: find.text('Aceptar'),
      ),
    );

    expect(find.text('Ya eres parte de Innovación UN'), findsOneWidget);
    expect(find.byType(InvitationCard), findsNothing);
    expect(find.text('Todavía no tienes grupos'), findsNothing);
    expect(
      find.descendant(of: _cardOf('Innovación UN'), matching: find.text('Integrante')),
      findsOneWidget,
    );
    expect(find.text('No hay otros grupos por ahora'), findsOneWidget);

    // Whoever invited is told.
    expect(
      notifications.all.where((item) => item.recipientId == 'user_1'),
      hasLength(1),
    );

    await tester.settleSnackbars();
  });

  testWidgets('rechazar una invitación la quita y el grupo sigue en el campus',
      (tester) async {
    final groups = InMemoryGroupSource();
    await groups.createInvitation(_invitationForMariana());

    await tester.pumpApp(
      route: AppRoutes.groups,
      bindings: TestBindings(
        groupSource: groups,
        session: TestSession(TestUsers.mariana),
      ),
    );

    await tester.tapVisible(
      find.descendant(
        of: find.byType(InvitationCard),
        matching: find.text('Rechazar'),
      ),
    );

    expect(find.text('Invitación rechazada'), findsOneWidget);
    expect(find.byType(InvitationCard), findsNothing);
    expect(find.text('Todavía no tienes grupos'), findsOneWidget);
    expect(_cardOf('Innovación UN'), findsOneWidget);

    await tester.settleSnackbars();
  });

  testWidgets('tocar la invitación abre el grupo al que invita',
      (tester) async {
    final groups = InMemoryGroupSource();
    await groups.createInvitation(_invitationForMariana());

    await tester.pumpApp(
      route: AppRoutes.groups,
      bindings: TestBindings(
        groupSource: groups,
        session: TestSession(TestUsers.mariana),
      ),
    );

    await tester.tapVisible(
      find.descendant(
        of: find.byType(InvitationCard),
        matching: find.text('Leonel Triana te invitó a unirte'),
      ),
    );

    expect(find.byType(GroupDetailPage), findsOneWidget);
    expect(Get.currentRoute, AppRoutes.groupOf('group_1'));
  });

  testWidgets('tocar un grupo abre su detalle', (tester) async {
    await tester.pumpApp(route: AppRoutes.groups);

    await tester.tapVisible(_cardOf('Innovación UN'));

    expect(find.byType(GroupDetailPage), findsOneWidget);
    expect(
      find.text('Este grupo es tuyo. Acepta o rechaza las solicitudes abajo.'),
      findsOneWidget,
    );
  });

  testWidgets('el botón flotante abre el formulario para crear un grupo',
      (tester) async {
    await tester.pumpApp(route: AppRoutes.groups);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.byType(CreateGroupPage), findsOneWidget);
    expect(Get.currentRoute, AppRoutes.createGroup);
  });

  testWidgets('si los grupos no cargan muestra el error', (tester) async {
    await tester.pumpApp(
      route: AppRoutes.groups,
      bindings: TestBindings(groupSource: _UnreachableGroupSource()),
    );

    expect(find.text('No se pudieron cargar los grupos'), findsOneWidget);
    expect(find.text('Sin conexión con ROBLE'), findsOneWidget);
    expect(find.byType(GroupCard), findsNothing);
  });
}
