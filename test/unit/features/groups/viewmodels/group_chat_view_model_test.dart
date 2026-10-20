import 'package:campus_innovate/features/groups/domain/models/group_member.dart';
import 'package:campus_innovate/features/groups/domain/models/group_message.dart';
import 'package:campus_innovate/features/groups/ui/viewmodels/group_chat_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../../support/test_session.dart';
import '../../view_model_harness.dart';

void main() {
  setUpViewModelTests();

  late ViewModelHarness harness;

  Future<GroupChatViewModel> open({
    TestUser user = TestUsers.leonel,
    String id = 'group_1',
  }) {
    harness.session.signInAs(user);

    return start(
      GroupChatViewModel(harness.chat, harness.groups, harness.session),
      routeId: id,
    );
  }

  Future<void> addMariana() => harness.groupSource.addMember(
        const GroupMember(
          groupId: 'group_1',
          userId: 'user_2',
          userName: 'Mariana Ospina',
        ),
      );

  /// A message written from another phone, straight into storage.
  Future<GroupMessage> arrives(String body) => harness.chatSource.sendMessage(
        GroupMessage.draft(
          groupId: 'group_1',
          senderId: 'user_2',
          senderName: 'Mariana Ospina',
          body: body,
        ),
      );

  setUp(() => harness = ViewModelHarness());

  group('load', () {
    test('un integrante ve la conversación', () async {
      await addMariana();
      await arrives('Hola equipo');

      final viewModel = await open();

      expect(viewModel.group.value?.id, 'group_1');
      expect(viewModel.messages.map((message) => message.body), [
        'Hola equipo',
      ]);
      expect(viewModel.currentUserId, 'user_1');
      expect(viewModel.error.value, isNull);
      expect(viewModel.isLoading.value, isFalse);
    });

    test('alguien de afuera recibe un error y no ve mensajes', () async {
      await arrives('Privado');

      final viewModel = await open(user: TestUsers.mariana);

      expect(
        viewModel.error.value,
        'Solo las personas del grupo pueden usar su chat.',
      );
      expect(viewModel.messages, isEmpty);
    });

    test('un grupo que ya no existe lo dice', () async {
      final viewModel = await open(id: 'ghost');

      expect(viewModel.error.value, 'Este grupo ya no existe.');
      expect(viewModel.group.value, isNull);
    });
  });

  group('send', () {
    test('agrega el mensaje al final apenas se envía', () async {
      await addMariana();
      await arrives('Primero');
      final viewModel = await open();

      final sent = await viewModel.send('  Segundo  ');

      expect(sent, isTrue);
      expect(viewModel.messages.last.body, 'Segundo');
      expect(viewModel.messages.last.senderId, 'user_1');
      expect(viewModel.messages.last.id, isNotEmpty);
      expect(viewModel.lastSendError, isNull);
      expect(viewModel.isSending.value, isFalse);
    });

    test('un mensaje en blanco no se envía y el error va aparte', () async {
      final viewModel = await open();

      final sent = await viewModel.send('   ');

      expect(sent, isFalse);
      expect(viewModel.lastSendError, 'Escribe algo antes de enviar.');
      expect(viewModel.error.value, isNull);
      expect(viewModel.messages, isEmpty);
    });

    test('alguien de afuera no puede enviar', () async {
      final viewModel = await open(user: TestUsers.mariana);

      final sent = await viewModel.send('Hola');

      expect(sent, isFalse);
      expect(
        viewModel.lastSendError,
        'Solo las personas del grupo pueden usar su chat.',
      );
      expect(await harness.chatSource.getMessages('group_1'), isEmpty);
    });
  });

  group('refreshMessages', () {
    test('trae lo que llegó desde otro teléfono', () async {
      await addMariana();
      final viewModel = await open();

      await arrives('Nuevo');
      await viewModel.refreshMessages();

      expect(viewModel.messages.map((message) => message.body), ['Nuevo']);
    });

    test('si nada cambió no reemplaza la lista', () async {
      await addMariana();
      await arrives('Hola');
      final viewModel = await open();

      var rebuilds = 0;
      final worker = ever<List<GroupMessage>>(
        viewModel.messages,
        (_) => rebuilds++,
      );
      addTearDown(worker.dispose);

      await viewModel.refreshMessages();
      await settle();
      expect(rebuilds, 0);

      await arrives('Otro');
      await viewModel.refreshMessages();
      await settle();
      expect(rebuilds, greaterThan(0));
      expect(viewModel.messages, hasLength(2));
    });

    test('sin grupo cargado no consulta', () async {
      final viewModel = await open(id: 'ghost');

      await viewModel.refreshMessages();

      expect(viewModel.messages, isEmpty);
    });
  });
}
