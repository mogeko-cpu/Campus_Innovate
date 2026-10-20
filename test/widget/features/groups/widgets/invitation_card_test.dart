import 'package:campus_innovate/features/groups/domain/models/group_invitation.dart';
import 'package:campus_innovate/features/groups/ui/widgets/invitation_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../../support/app_tester.dart';

const _invitation = GroupInvitation(
  id: 'group_invitation_1',
  groupId: 'group_1',
  groupName: 'Innovación UN',
  inviterId: 'user_1',
  inviterName: 'Leonel Triana',
  inviteeId: 'user_2',
  inviteeName: 'Mariana Ospina',
);

void main() {
  tearDown(Get.reset);

  Widget card({
    GroupInvitation invitation = _invitation,
    bool isBusy = false,
    VoidCallback? onAccept,
    VoidCallback? onReject,
    VoidCallback? onOpenGroup,
  }) {
    return wrapWidget(
      InvitationCard(
        invitation: invitation,
        isBusy: isBusy,
        onAccept: onAccept ?? () {},
        onReject: onReject ?? () {},
        onOpenGroup: onOpenGroup,
      ),
    );
  }

  testWidgets('muestra el grupo, quién invitó y sus iniciales', (tester) async {
    await tester.pumpWidget(card());

    expect(find.text('Innovación UN'), findsOneWidget);
    expect(find.text('Leonel Triana te invitó a unirte'), findsOneWidget);
    expect(find.text('LT'), findsOneWidget);
  });

  testWidgets('sin nombre de grupo usa un título genérico', (tester) async {
    const nameless = GroupInvitation(
      id: 'group_invitation_2',
      groupId: 'group_1',
      groupName: '',
      inviterId: 'user_1',
      inviterName: 'Leonel Triana',
      inviteeId: 'user_2',
      inviteeName: 'Mariana Ospina',
    );

    await tester.pumpWidget(card(invitation: nameless));

    expect(find.text('Invitación a un grupo'), findsOneWidget);
  });

  testWidgets('aceptar y rechazar llaman a su callback', (tester) async {
    var accepted = 0;
    var rejected = 0;

    await tester.pumpWidget(
      card(onAccept: () => accepted++, onReject: () => rejected++),
    );

    await tester.tap(find.text('Aceptar'));
    await tester.tap(find.text('Rechazar'));
    await tester.pump();

    expect(accepted, 1);
    expect(rejected, 1);
  });

  testWidgets('mientras está ocupada los dos botones quedan deshabilitados',
      (tester) async {
    var calls = 0;

    await tester.pumpWidget(
      card(isBusy: true, onAccept: () => calls++, onReject: () => calls++),
    );

    final accept =
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Aceptar'));
    final reject =
        tester.widget<TextButton>(find.widgetWithText(TextButton, 'Rechazar'));

    expect(accept.onPressed, isNull);
    expect(reject.onPressed, isNull);

    await tester.tap(find.text('Aceptar'));
    await tester.pump();
    expect(calls, 0);
  });

  testWidgets('tocar la tarjeta abre el grupo cuando hay onOpenGroup',
      (tester) async {
    var opened = 0;

    await tester.pumpWidget(card(onOpenGroup: () => opened++));

    await tester.tap(find.text('Innovación UN'));
    await tester.pump();

    expect(opened, 1);
  });

  testWidgets('sin onOpenGroup la tarjeta no es tocable', (tester) async {
    await tester.pumpWidget(card());

    final ink = tester.widget<InkWell>(
      find.ancestor(of: find.text('Innovación UN'), matching: find.byType(InkWell)),
    );

    expect(ink.onTap, isNull);
  });
}
