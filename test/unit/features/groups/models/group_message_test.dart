import 'package:campus_innovate/core/user_facing_exception.dart';
import 'package:campus_innovate/features/groups/domain/group_exception.dart';
import 'package:campus_innovate/features/groups/domain/models/group_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GroupMessage', () {
    test('un borrador no tiene id y queda fechado ahora', () {
      final before = DateTime.now();
      final draft = GroupMessage.draft(
        groupId: 'group_1',
        senderId: 'user_1',
        senderName: 'Leonel',
        body: 'Hola',
      );

      expect(draft.id, isEmpty);
      expect(draft.isPersisted, isFalse);
      expect(draft.createdAt.isBefore(before), isFalse);
    });

    test('copyWith con id lo guarda y conserva fecha y contenido', () {
      final message = GroupMessage(
        id: '',
        groupId: 'g',
        senderId: 's',
        senderName: 'n',
        body: 'texto',
        createdAt: DateTime(2026, 5, 4),
      );

      final stored = message.copyWith(id: 'm1');

      expect(stored.isPersisted, isTrue);
      expect(stored.groupId, 'g');
      expect(stored.senderId, 's');
      expect(stored.senderName, 'n');
      expect(stored.body, 'texto');
      expect(stored.createdAt, DateTime(2026, 5, 4));
    });
  });

  group('GroupException', () {
    test('es para el usuario y su toString es el mensaje', () {
      const error = GroupException('Este grupo ya no existe.');

      expect(error, isA<UserFacingException>());
      expect(error.message, 'Este grupo ya no existe.');
      expect(error.toString(), 'Este grupo ya no existe.');
    });
  });
}
