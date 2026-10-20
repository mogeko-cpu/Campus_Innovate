import 'package:campus_innovate/features/groups/domain/models/group_invitation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const draft = GroupInvitation.draft(
    groupId: 'group_1',
    groupName: 'Innovación UN',
    inviterId: 'user_1',
    inviterName: 'Leonel',
    inviteeId: 'user_2',
    inviteeName: 'Mariana',
  );

  test('un borrador no tiene id', () {
    expect(draft.id, isEmpty);
    expect(draft.isPersisted, isFalse);
  });

  test('copyWith con id la guarda sin tocar quién invita a quién', () {
    final stored = draft.copyWith(id: 'inv_1');

    expect(stored.isPersisted, isTrue);
    expect(stored.id, 'inv_1');
    expect(stored.groupId, 'group_1');
    expect(stored.groupName, 'Innovación UN');
    expect(stored.inviterId, 'user_1');
    expect(stored.inviterName, 'Leonel');
    expect(stored.inviteeId, 'user_2');
    expect(stored.inviteeName, 'Mariana');
  });

  test('copyWith sin argumentos devuelve una copia igual', () {
    final stored = draft.copyWith(id: 'inv_1');

    expect(stored.copyWith().id, 'inv_1');
  });
}
