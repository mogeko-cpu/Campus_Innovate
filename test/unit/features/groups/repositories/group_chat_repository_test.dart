import 'package:campus_innovate/features/groups/data/repositories/group_chat_repository.dart';
import 'package:campus_innovate/features/groups/data/repositories/group_repository.dart';
import 'package:campus_innovate/features/groups/domain/group_exception.dart';
import 'package:campus_innovate/features/groups/domain/models/group_message.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/in_memory_group_chat_source.dart';
import '../../../../support/in_memory_group_source.dart';

/// Members-only reading/sending, empty lines and the upper limit are covered in
/// `group_collaboration_test.dart`; these are the remaining edges.
void main() {
  late InMemoryGroupChatSource chatSource;
  late GroupChatRepository chat;

  setUp(() {
    chatSource = InMemoryGroupChatSource();
    chat = GroupChatRepository(
      chatSource,
      GroupRepository(InMemoryGroupSource()),
    );
  });

  GroupMessage line(String body, {String groupId = 'group_1'}) =>
      GroupMessage.draft(
        groupId: groupId,
        senderId: 'user_1',
        senderName: 'Leonel Triana',
        body: body,
      );

  test('en un grupo que ya no existe no se puede leer ni enviar', () async {
    await expectLater(
      chat.getMessages(groupId: 'no-existe', userId: 'user_1'),
      throwsA(
        isA<GroupException>()
            .having((e) => e.message, 'message', contains('ya no existe')),
      ),
    );
    await expectLater(
      chat.send(line('hola', groupId: 'no-existe')),
      throwsA(isA<GroupException>()),
    );
  });

  test('guarda el mensaje sin los espacios de los bordes', () async {
    final stored = await chat.send(line('   hola equipo \n'));

    expect(stored.body, 'hola equipo');
    expect(stored.isPersisted, isTrue);
    expect(stored.senderName, 'Leonel Triana');
  });

  test('un mensaje de exactamente el máximo se acepta', () async {
    final stored =
        await chat.send(line('a' * GroupChatRepository.maxLength));

    expect(stored.body, hasLength(GroupChatRepository.maxLength));
  });

  test('el límite se mide sin los espacios de los bordes', () async {
    final padded = '  ${'a' * GroupChatRepository.maxLength}  ';

    expect((await chat.send(line(padded))).body,
        hasLength(GroupChatRepository.maxLength));
  });

  test('un mensaje rechazado no llega a guardarse', () async {
    await expectLater(chat.send(line('   ')), throwsA(isA<GroupException>()));

    expect(await chatSource.getMessages('group_1'), isEmpty);
  });

  test('los mensajes se leen en orden de llegada', () async {
    await chat.send(line('primero'));
    await chat.send(line('segundo'));

    final messages =
        await chat.getMessages(groupId: 'group_1', userId: 'user_1');

    expect(messages.map((m) => m.body), ['primero', 'segundo']);
  });
}
