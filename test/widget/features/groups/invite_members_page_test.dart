import 'package:campus_innovate/features/groups/domain/models/group_invitation.dart';
import 'package:campus_innovate/features/groups/domain/models/group_member.dart';
import 'package:campus_innovate/features/groups/domain/models/group_request.dart';
import 'package:campus_innovate/features/notifications/domain/models/notification_type.dart';
import 'package:campus_innovate/features/users/domain/models/app_user.dart';
import 'package:campus_innovate/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/app_tester.dart';
import '../../../support/in_memory_group_source.dart';
import '../../../support/in_memory_notification_source.dart';
import '../../../support/in_memory_user_source.dart';
import '../../../support/test_bindings.dart';

const _carlos = AppUser(
  id: 'user_3',
  name: 'Carlos Pérez',
  email: 'carlos@uninorte.edu.co',
);

Finder get _search => find.byType(TextField);

Finder _rowOf(String name) => find.ancestor(
      of: find.text(name),
      matching: find.byType(ListTile),
    );

void main() {
  tearDown(Get.reset);

  /// The directory knows Leonel (already in group_1), Mariana and Carlos.
  Future<InMemoryUserSource> campus() async {
    final users = InMemoryUserSource();
    await users.upsert(
      const AppUser(
        id: 'user_1',
        name: 'Leonel Triana',
        email: 'leonel@uninorte.edu.co',
      ),
    );
    await users.upsert(_carlos);

    return users;
  }

  Future<void> openInvite(
    WidgetTester tester, {
    InMemoryGroupSource? groups,
    InMemoryUserSource? users,
    InMemoryNotificationSource? notifications,
  }) async {
    await tester.pumpApp(
      route: AppRoutes.inviteOf('group_1'),
      bindings: TestBindings(
        groupSource: groups,
        userSource: users ?? await campus(),
        notificationSource: notifications,
      ),
    );
  }

  testWidgets('lista a quien se puede invitar, sin los que ya son del grupo',
      (tester) async {
    await openInvite(tester);

    expect(find.text('Invitar al grupo'), findsOneWidget);
    expect(find.text('Mariana Ospina'), findsOneWidget);
    expect(find.text('mariana@uninorte.edu.co'), findsOneWidget);
    expect(find.text('Carlos Pérez'), findsOneWidget);
    expect(find.text('Leonel Triana'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Invitar'), findsNWidgets(2));
  });

  testWidgets('la búsqueda filtra por nombre sin importar mayúsculas',
      (tester) async {
    await openInvite(tester);

    await tester.enterText(_search, 'MARI');
    await tester.pumpAndSettle();

    expect(find.text('Mariana Ospina'), findsOneWidget);
    expect(find.text('Carlos Pérez'), findsNothing);
  });

  testWidgets('la búsqueda también filtra por correo', (tester) async {
    await openInvite(tester);

    await tester.enterText(_search, 'carlos@');
    await tester.pumpAndSettle();

    expect(find.text('Carlos Pérez'), findsOneWidget);
    expect(find.text('Mariana Ospina'), findsNothing);
  });

  testWidgets('sin coincidencias dice "Nadie coincide con tu búsqueda"',
      (tester) async {
    await openInvite(tester);

    await tester.enterText(_search, 'zzz');
    await tester.pumpAndSettle();

    expect(find.text('Nadie coincide con tu búsqueda'), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('si todos ya están en el grupo no hay nadie para invitar',
      (tester) async {
    final groups = InMemoryGroupSource();
    await groups.addMember(
      const GroupMember(
        groupId: 'group_1',
        userId: 'user_2',
        userName: 'Mariana Ospina',
      ),
    );

    // The default directory: only Mariana, who is now a member.
    await openInvite(tester, groups: groups, users: InMemoryUserSource());

    expect(find.text('No hay nadie más para invitar'), findsOneWidget);
  });

  testWidgets('invitar guarda la invitación y avisa a la persona',
      (tester) async {
    final groups = InMemoryGroupSource();
    final notifications = InMemoryNotificationSource();

    await openInvite(tester, groups: groups, notifications: notifications);

    await tester.tap(
      find.descendant(
        of: _rowOf('Mariana Ospina'),
        matching: find.widgetWithText(FilledButton, 'Invitar'),
      ),
    );
    await tester.pumpAndSettle();

    // The toast; the row changing is checked by the next test.
    expect(
      find.text('Mariana Ospina recibirá una notificación'),
      findsOneWidget,
    );

    final invitations = await groups.getInvitationsForGroup('group_1');
    expect(invitations.single.inviteeId, 'user_2');
    expect(invitations.single.inviterId, 'user_1');
    expect(invitations.single.groupName, 'Innovación UN');
    expect(
      notifications.all.single.type,
      NotificationType.invitationReceived,
    );
    expect(notifications.all.single.recipientId, 'user_2');

    await tester.settleSnackbars();
  });

  testWidgets('tras invitar, la fila cambia el botón por "Invitación enviada"', (tester) async {
    await openInvite(tester);

    await tester.tap(
      find.descendant(
        of: _rowOf('Mariana Ospina'),
        matching: find.widgetWithText(FilledButton, 'Invitar'),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: _rowOf('Mariana Ospina'),
        matching: find.widgetWithText(Chip, 'Invitación enviada'),
      ),
      findsOneWidget,
    );
    // Carlos can still be invited.
    expect(
      find.descendant(
        of: _rowOf('Carlos Pérez'),
        matching: find.widgetWithText(FilledButton, 'Invitar'),
      ),
      findsOneWidget,
    );

    await tester.settleSnackbars();
  });

  testWidgets('quien ya tiene una invitación pendiente aparece marcado',
      (tester) async {
    final groups = InMemoryGroupSource();
    await groups.createInvitation(
      const GroupInvitation.draft(
        groupId: 'group_1',
        groupName: 'Innovación UN',
        inviterId: 'user_1',
        inviterName: 'Leonel Triana',
        inviteeId: 'user_2',
        inviteeName: 'Mariana Ospina',
      ),
    );

    await openInvite(tester, groups: groups);

    expect(
      find.descendant(
        of: _rowOf('Mariana Ospina'),
        matching: find.widgetWithText(Chip, 'Invitación enviada'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: _rowOf('Mariana Ospina'),
        matching: find.byType(FilledButton),
      ),
      findsNothing,
    );
  });

  testWidgets('quien ya pidió entrar aparece con "Ya solicitó" y sin botón',
      (tester) async {
    final groups = InMemoryGroupSource();
    await groups.createRequest(
      const GroupRequest.draft(
        groupId: 'group_1',
        applicantId: 'user_3',
        applicantName: 'Carlos Pérez',
        message: '',
      ),
    );

    await openInvite(tester, groups: groups);

    expect(
      find.descendant(
        of: _rowOf('Carlos Pérez'),
        matching: find.widgetWithText(Chip, 'Ya solicitó'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: _rowOf('Carlos Pérez'),
        matching: find.byType(FilledButton),
      ),
      findsNothing,
    );
  });

  testWidgets('un grupo que no existe muestra el error', (tester) async {
    await tester.pumpApp(route: AppRoutes.inviteOf('no_existe'));

    expect(find.text('No se pudo cargar'), findsOneWidget);
    expect(find.text('Grupo no encontrado'), findsOneWidget);
  });
}
