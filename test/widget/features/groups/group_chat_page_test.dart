import 'package:campus_innovate/features/groups/domain/models/group_member.dart';
import 'package:campus_innovate/features/groups/domain/models/group_message.dart';
import 'package:campus_innovate/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/app_tester.dart';
import '../../../support/in_memory_group_chat_source.dart';
import '../../../support/in_memory_group_source.dart';
import '../../../support/test_bindings.dart';
import '../../../support/test_session.dart';

Finder get _composer => find.byType(TextField);

void main() {
  tearDown(Get.reset);

  testWidgets('el título lleva el nombre del grupo y abre sin mensajes',
      (tester) async {
    await tester.pumpApp(route: AppRoutes.chatOf('group_1'));

    expect(find.text('Chat · Innovación UN'), findsOneWidget);
    expect(find.text('Todavía no hay mensajes'), findsOneWidget);
    expect(_composer, findsOneWidget);
  });

  testWidgets('enviar un mensaje lo muestra y vacía el campo', (tester) async {
    final chat = InMemoryGroupChatSource();

    await tester.pumpApp(
      route: AppRoutes.chatOf('group_1'),
      bindings: TestBindings(chatSource: chat),
    );

    await tester.enterText(_composer, '  ¿Nos vemos el jueves?  ');
    await tester.tap(find.byTooltip('Enviar'));
    await tester.pumpAndSettle();

    expect(find.text('Todavía no hay mensajes'), findsNothing);
    // Stored and shown trimmed.
    expect(find.text('¿Nos vemos el jueves?'), findsOneWidget);
    expect(tester.widget<TextField>(_composer).controller!.text, isEmpty);

    final stored = await chat.getMessages('group_1');
    expect(stored.single.body, '¿Nos vemos el jueves?');
    expect(stored.single.senderId, 'user_1');
  });

  testWidgets('un campo vacío no envía nada', (tester) async {
    final chat = InMemoryGroupChatSource();

    await tester.pumpApp(
      route: AppRoutes.chatOf('group_1'),
      bindings: TestBindings(chatSource: chat),
    );

    await tester.enterText(_composer, '    ');
    await tester.tap(find.byTooltip('Enviar'));
    await tester.pumpAndSettle();

    expect(find.text('Todavía no hay mensajes'), findsOneWidget);
    expect(await chat.getMessages('group_1'), isEmpty);
  });

  testWidgets('los mensajes de otros muestran quién los escribió',
      (tester) async {
    final groups = InMemoryGroupSource();
    final chat = InMemoryGroupChatSource();
    await groups.addMember(
      const GroupMember(
        groupId: 'group_1',
        userId: 'user_2',
        userName: 'Mariana Ospina',
      ),
    );
    await chat.sendMessage(
      GroupMessage.draft(
        groupId: 'group_1',
        senderId: 'user_2',
        senderName: 'Mariana Ospina',
        body: 'Ya subí el prototipo',
      ),
    );

    await tester.pumpApp(
      route: AppRoutes.chatOf('group_1'),
      bindings: TestBindings(groupSource: groups, chatSource: chat),
    );

    expect(find.text('Ya subí el prototipo'), findsOneWidget);
    expect(find.text('Mariana Ospina'), findsOneWidget);
    expect(find.text('MO'), findsOneWidget);

    // One's own messages carry no name.
    await tester.enterText(_composer, 'Perfecto, gracias');
    await tester.tap(find.byTooltip('Enviar'));
    await tester.pumpAndSettle();

    expect(find.text('Perfecto, gracias'), findsOneWidget);
    expect(find.text('Leonel Triana'), findsNothing);
  });

  testWidgets('a quien no es del grupo no se le abre el chat', (tester) async {
    await tester.pumpApp(
      route: AppRoutes.chatOf('group_1'),
      bindings: TestBindings(session: TestSession(TestUsers.mariana)),
    );

    expect(find.text('No se pudo abrir el chat'), findsOneWidget);
    expect(
      find.text('Solo las personas del grupo pueden usar su chat.'),
      findsOneWidget,
    );
    // The group did load, so the title still names it.
    expect(find.text('Chat · Innovación UN'), findsOneWidget);
  });

  testWidgets('un grupo que no existe tampoco abre el chat', (tester) async {
    await tester.pumpApp(route: AppRoutes.chatOf('no_existe'));

    expect(find.text('Chat del grupo'), findsOneWidget);
    expect(find.text('No se pudo abrir el chat'), findsOneWidget);
    expect(find.text('Este grupo ya no existe.'), findsOneWidget);
  });
}
