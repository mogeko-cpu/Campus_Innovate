import 'package:campus_innovate/features/groups/domain/models/group_invitation.dart';
import 'package:campus_innovate/features/groups/domain/models/group_member.dart';
import 'package:campus_innovate/features/groups/domain/models/group_request.dart';
import 'package:campus_innovate/features/groups/ui/views/group_chat_page.dart';
import 'package:campus_innovate/features/groups/ui/views/group_detail_page.dart';
import 'package:campus_innovate/features/groups/ui/views/groups_page.dart';
import 'package:campus_innovate/features/groups/ui/views/invite_members_page.dart';
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

const _ownerBanner =
    'Este grupo es tuyo. Acepta o rechaza las solicitudes abajo.';

const _marianaAsks = GroupRequest.draft(
  groupId: 'group_1',
  applicantId: 'user_2',
  applicantName: 'Mariana Ospina',
  message: 'Sé programar en Flutter',
);

const _marianaInvited = GroupInvitation.draft(
  groupId: 'group_1',
  groupName: 'Innovación UN',
  inviterId: 'user_1',
  inviterName: 'Leonel Triana',
  inviteeId: 'user_2',
  inviteeName: 'Mariana Ospina',
);

const _marianaMember = GroupMember(
  groupId: 'group_1',
  userId: 'user_2',
  userName: 'Mariana Ospina',
);

Listing _projectOfGroup1() => const Listing(
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
    );

Finder _button<T extends Widget>(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(T));

void main() {
  tearDown(Get.reset);

  Future<void> openGroup1(
    WidgetTester tester, {
    InMemoryGroupSource? groups,
    InMemoryListingSource? listings,
    InMemoryNotificationSource? notifications,
    TestUser user = TestUsers.leonel,
  }) {
    return tester.pumpApp(
      route: AppRoutes.groupOf('group_1'),
      bindings: TestBindings(
        groupSource: groups,
        source: listings,
        notificationSource: notifications,
        session: TestSession(user),
      ),
    );
  }

  group('como creador', () {
    testWidgets('ve el aviso de dueño, los integrantes y los proyectos',
        (tester) async {
      await openGroup1(tester);

      expect(find.text('Innovación UN'), findsOneWidget);
      expect(find.text('Creado por Leonel Triana'), findsOneWidget);
      expect(find.text(_ownerBanner), findsOneWidget);
      expect(find.byTooltip('Eliminar grupo'), findsOneWidget);
      expect(find.text('Solicitar ingreso'), findsNothing);
      expect(find.text('Salir del grupo'), findsNothing);

      expect(find.text('Leonel Triana'), findsOneWidget);
      expect(find.text('Creador'), findsOneWidget);
      // The owner cannot be removed, so nobody has the button.
      expect(find.byTooltip('Quitar del grupo'), findsNothing);

      expect(find.text('No hay solicitudes pendientes'), findsOneWidget);
      expect(
        find.text('Este grupo todavía no ha publicado proyectos'),
        findsOneWidget,
      );
    });

    testWidgets('tiene a mano el chat y las invitaciones', (tester) async {
      await openGroup1(tester);

      await tester.tapVisible(_button<FilledButton>('Chat'));
      expect(find.byType(GroupChatPage), findsOneWidget);

      Get.back();
      await tester.pumpAndSettle();

      await tester.tapVisible(_button<FilledButton>('Invitar'));
      expect(find.byType(InviteMembersPage), findsOneWidget);
    });

    testWidgets('no puede eliminar el grupo mientras tenga proyectos',
        (tester) async {
      final listings = InMemoryListingSource();
      await listings.createListing(_projectOfGroup1());
      final groups = InMemoryGroupSource();

      await openGroup1(tester, groups: groups, listings: listings);

      expect(find.text('Tutorías entre pares'), findsOneWidget);
      expect(find.text('1 de 4 integrantes · Impacto Social'), findsOneWidget);

      await tester.tap(find.byTooltip('Eliminar grupo'));
      await tester.pumpAndSettle();
      expect(find.text('¿Eliminar el grupo?'), findsOneWidget);

      await tester.tapText('Eliminar');

      const refusal = 'Este grupo tiene 1 proyecto publicado. Elimínalo antes '
          'de eliminar el grupo.';

      expect(find.text('No se pudo eliminar'), findsOneWidget);
      // Once in the toast and once in the banner on the screen.
      expect(find.text(refusal), findsNWidgets(2));
      expect(find.byType(GroupDetailPage), findsOneWidget);
      expect(await groups.getGroupById('group_1'), isNotNull);

      await tester.settleSnackbars();
    });

    testWidgets('cancelar el diálogo de eliminar no borra nada',
        (tester) async {
      final groups = InMemoryGroupSource();
      await openGroup1(tester, groups: groups);

      await tester.tap(find.byTooltip('Eliminar grupo'));
      await tester.pumpAndSettle();
      await tester.tapText('Cancelar');

      expect(find.text('¿Eliminar el grupo?'), findsNothing);
      expect(await groups.getGroupById('group_1'), isNotNull);
    });

    testWidgets('sin proyectos lo elimina y vuelve a la lista de grupos',
        (tester) async {
      final groups = InMemoryGroupSource();

      // Through the list, so that going back after deleting has a screen to
      // land on.
      await tester.pumpApp(
        route: AppRoutes.groups,
        bindings: TestBindings(groupSource: groups),
      );
      await tester.tapVisible(find.widgetWithText(GroupCard, 'Innovación UN'));

      await tester.tap(find.byTooltip('Eliminar grupo'));
      await tester.pumpAndSettle();
      await tester.tapText('Eliminar');

      expect(find.byType(GroupDetailPage), findsNothing);
      expect(find.byType(GroupsPage), findsOneWidget);
      expect(find.text('Grupo eliminado'), findsOneWidget);
      expect(find.text('Todavía no tienes grupos'), findsOneWidget);
      expect(await groups.getGroupById('group_1'), isNull);

      await tester.settleSnackbars();
    });

    testWidgets('acepta una solicitud y la persona pasa a ser integrante',
        (tester) async {
      final groups = InMemoryGroupSource();
      final notifications = InMemoryNotificationSource();
      await groups.createRequest(_marianaAsks);

      await openGroup1(tester, groups: groups, notifications: notifications);

      expect(find.text('Mariana Ospina'), findsOneWidget);
      expect(find.text('Sé programar en Flutter'), findsOneWidget);
      expect(find.text('No hay solicitudes pendientes'), findsNothing);

      await tester.tapText('Aceptar');

      expect(find.text('Solicitud aceptada'), findsOneWidget);
      expect(find.text('Mariana Ospina ya es integrante'), findsOneWidget);
      expect(find.text('No hay solicitudes pendientes'), findsOneWidget);
      expect(find.text('Sé programar en Flutter'), findsNothing);
      // Now in the roster, with the button to remove her.
      expect(find.text('Integrante'), findsOneWidget);
      expect(find.byTooltip('Quitar del grupo'), findsOneWidget);
      expect((await groups.getGroupById('group_1'))!.hasMember('user_2'), isTrue);
      expect(
        notifications.all.where((item) => item.recipientId == 'user_2'),
        hasLength(1),
      );

      await tester.settleSnackbars();
    });

    testWidgets('rechaza una solicitud y desaparece sin sumar a nadie',
        (tester) async {
      final groups = InMemoryGroupSource();
      await groups.createRequest(_marianaAsks);

      await openGroup1(tester, groups: groups);

      await tester.tapText('Rechazar');

      expect(find.text('Solicitud rechazada'), findsOneWidget);
      expect(find.text('No hay solicitudes pendientes'), findsOneWidget);
      expect(find.text('Mariana Ospina'), findsNothing);
      expect(
        (await groups.getGroupById('group_1'))!.hasMember('user_2'),
        isFalse,
      );

      await tester.settleSnackbars();
    });

    testWidgets('quita a un integrante del grupo', (tester) async {
      final groups = InMemoryGroupSource();
      await groups.addMember(_marianaMember);

      await openGroup1(tester, groups: groups);

      expect(find.text('Mariana Ospina'), findsOneWidget);

      await tester.tap(find.byTooltip('Quitar del grupo'));
      await tester.pumpAndSettle();

      expect(find.text('Mariana Ospina salió del grupo'), findsOneWidget);
      expect(find.text('Mariana Ospina'), findsNothing);
      expect(
        (await groups.getGroupById('group_1'))!.hasMember('user_2'),
        isFalse,
      );

      await tester.settleSnackbars();
    });

    testWidgets('ve las invitaciones enviadas y puede cancelarlas',
        (tester) async {
      final groups = InMemoryGroupSource();
      await groups.createInvitation(_marianaInvited);

      await openGroup1(tester, groups: groups);

      expect(find.text('Invitaciones enviadas'), findsOneWidget);
      expect(find.text('Mariana Ospina'), findsOneWidget);
      expect(find.text('Invitó Leonel Triana · pendiente'), findsOneWidget);

      await tester.tapVisible(find.byTooltip('Cancelar invitación'));

      expect(find.text('Invitación cancelada'), findsOneWidget);
      expect(find.text('Invitaciones enviadas'), findsNothing);
      expect(await groups.getInvitationsForGroup('group_1'), isEmpty);

      await tester.settleSnackbars();
    });
  });

  group('como integrante', () {
    Future<InMemoryGroupSource> openAsMember(WidgetTester tester) async {
      final groups = InMemoryGroupSource();
      await groups.addMember(_marianaMember);

      await openGroup1(tester, groups: groups, user: TestUsers.mariana);

      return groups;
    }

    testWidgets('puede salir, chatear e invitar, pero no administrar',
        (tester) async {
      await openAsMember(tester);

      expect(find.text('Salir del grupo'), findsOneWidget);
      expect(find.text(_ownerBanner), findsNothing);
      expect(find.byTooltip('Eliminar grupo'), findsNothing);
      expect(find.byTooltip('Quitar del grupo'), findsNothing);
      expect(find.text('Solicitudes'), findsNothing);
      expect(_button<FilledButton>('Chat'), findsOneWidget);
      expect(_button<FilledButton>('Invitar'), findsOneWidget);
    });

    testWidgets('cancelar el diálogo de salida lo deja dentro',
        (tester) async {
      final groups = await openAsMember(tester);

      await tester.tapText('Salir del grupo');
      expect(find.text('¿Salir del grupo?'), findsOneWidget);

      await tester.tapText('Cancelar');

      expect(find.text('Salir del grupo'), findsOneWidget);
      expect(
        (await groups.getGroupById('group_1'))!.hasMember('user_2'),
        isTrue,
      );
    });

    testWidgets('confirmar la salida lo deja como alguien de afuera',
        (tester) async {
      final groups = await openAsMember(tester);

      await tester.tapText('Salir del grupo');
      await tester.tapVisible(_button<FilledButton>('Salir'));

      expect(find.text('Saliste del grupo'), findsOneWidget);
      expect(find.text('Salir del grupo'), findsNothing);
      expect(find.text('Solicitar ingreso'), findsOneWidget);
      expect(_button<FilledButton>('Chat'), findsNothing);
      expect(
        (await groups.getGroupById('group_1'))!.hasMember('user_2'),
        isFalse,
      );

      await tester.settleSnackbars();
    });
  });

  group('como alguien de afuera', () {
    testWidgets('solo puede solicitar ingreso; no ve chat ni invitar',
        (tester) async {
      await openGroup1(tester, user: TestUsers.mariana);

      expect(find.text('Solicitar ingreso'), findsOneWidget);
      expect(_button<FilledButton>('Chat'), findsNothing);
      expect(_button<FilledButton>('Invitar'), findsNothing);
      expect(find.text('Solicitudes'), findsNothing);
      expect(find.byTooltip('Eliminar grupo'), findsNothing);
    });

    testWidgets('"Solicitar ingreso" abre el diálogo para escribir una nota',
        (tester) async {
      await openGroup1(tester, user: TestUsers.mariana);

      await tester.tapText('Solicitar ingreso');

      final dialog = find.byType(AlertDialog);
      expect(dialog, findsOneWidget);
      expect(
        find.descendant(of: dialog, matching: find.byType(TextField)),
        findsOneWidget,
      );
      expect(
        find.text('¿Por qué quieres entrar y qué aportas?'),
        findsOneWidget,
      );
      expect(
        find.descendant(of: dialog, matching: find.text('Enviar')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: dialog, matching: find.text('Cancelar')),
        findsOneWidget,
      );
    });

    testWidgets('enviar la solicitud deja el aviso de pendiente', (tester) async {
      final groups = InMemoryGroupSource();
      final notifications = InMemoryNotificationSource();

      await openGroup1(
        tester,
        groups: groups,
        notifications: notifications,
        user: TestUsers.mariana,
      );

      await tester.tapText('Solicitar ingreso');
      expect(find.byType(AlertDialog), findsOneWidget);

      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        '  Quiero aportar en diseño  ',
      );
      await tester.tapText('Enviar');

      expect(find.text('Solicitud enviada'), findsOneWidget);
      expect(
        find.text('Solicitud enviada — estado: Pendiente.'),
        findsOneWidget,
      );
      expect(find.text('Solicitar ingreso'), findsNothing);

      final requests = await groups.getRequestsForGroup('group_1');
      expect(requests.single.applicantId, 'user_2');
      expect(requests.single.message, 'Quiero aportar en diseño');
      // The owner hears about it.
      expect(
        notifications.all.where((item) => item.recipientId == 'user_1'),
        hasLength(1),
      );

      await tester.settleSnackbars();
    });

    testWidgets('cancelar el diálogo no envía nada', (tester) async {
      final groups = InMemoryGroupSource();

      await openGroup1(tester, groups: groups, user: TestUsers.mariana);

      await tester.tapText('Solicitar ingreso');
      await tester.tapText('Cancelar');

      expect(find.text('Solicitar ingreso'), findsOneWidget);
      expect(await groups.getRequestsForGroup('group_1'), isEmpty);
    });

    testWidgets('con una solicitud ya enviada ve su estado', (tester) async {
      final groups = InMemoryGroupSource();
      await groups.createRequest(_marianaAsks);

      await openGroup1(tester, groups: groups, user: TestUsers.mariana);

      expect(
        find.text('Solicitud enviada — estado: Pendiente.'),
        findsOneWidget,
      );
      expect(find.text('Solicitar ingreso'), findsNothing);
    });
  });

  group('como invitado', () {
    testWidgets('ve la invitación en lugar de "Solicitar ingreso"',
        (tester) async {
      final groups = InMemoryGroupSource();
      await groups.createInvitation(_marianaInvited);

      await openGroup1(tester, groups: groups, user: TestUsers.mariana);

      expect(find.byType(InvitationCard), findsOneWidget);
      expect(find.text('Leonel Triana te invitó a unirte'), findsOneWidget);
      expect(find.text('Solicitar ingreso'), findsNothing);
      // An outsider does not see who else has been invited.
      expect(find.text('Invitaciones enviadas'), findsNothing);
    });

    testWidgets('aceptar la invitación lo vuelve integrante', (tester) async {
      final groups = InMemoryGroupSource();
      await groups.createInvitation(_marianaInvited);

      await openGroup1(tester, groups: groups, user: TestUsers.mariana);

      await tester.tapText('Aceptar');

      expect(find.text('Bienvenido al grupo'), findsOneWidget);
      expect(find.byType(InvitationCard), findsNothing);
      expect(find.text('Salir del grupo'), findsOneWidget);
      expect(_button<FilledButton>('Chat'), findsOneWidget);
      expect(find.text('Mariana Ospina'), findsOneWidget);
      expect(
        (await groups.getGroupById('group_1'))!.hasMember('user_2'),
        isTrue,
      );

      await tester.settleSnackbars();
    });

    testWidgets('rechazar la invitación la quita y ofrece solicitar ingreso',
        (tester) async {
      final groups = InMemoryGroupSource();
      await groups.createInvitation(_marianaInvited);

      await openGroup1(tester, groups: groups, user: TestUsers.mariana);

      await tester.tapText('Rechazar');

      expect(find.text('Invitación rechazada'), findsOneWidget);
      expect(find.byType(InvitationCard), findsNothing);
      expect(find.text('Solicitar ingreso'), findsOneWidget);
      expect(await groups.getInvitationsForGroup('group_1'), isEmpty);

      await tester.settleSnackbars();
    });
  });

  testWidgets('un grupo que no existe dice "Grupo no encontrado"',
      (tester) async {
    await tester.pumpApp(route: AppRoutes.groupOf('no_existe'));

    expect(find.text('Grupo no encontrado'), findsOneWidget);
    expect(find.text('Integrantes'), findsNothing);
    expect(find.byTooltip('Eliminar grupo'), findsNothing);
  });
}
