import 'package:campus_innovate/features/groups/domain/models/group_request.dart';
import 'package:campus_innovate/features/groups/domain/models/group_request_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const draft = GroupRequest.draft(
    groupId: 'group_1',
    applicantId: 'user_2',
    applicantName: 'Mariana',
    message: 'Quiero entrar',
  );

  test('un borrador no tiene id y está pendiente', () {
    expect(draft.id, isEmpty);
    expect(draft.isPersisted, isFalse);
    expect(draft.status, GroupRequestStatus.pending);
    expect(draft.isPending, isTrue);
  });

  test('isPending es falso para una solicitud respondida', () {
    expect(draft.copyWith(status: GroupRequestStatus.accepted).isPending,
        isFalse);
    expect(draft.copyWith(status: GroupRequestStatus.rejected).isPending,
        isFalse);
  });

  test('copyWith con id conserva el resto', () {
    final stored = draft.copyWith(id: 'r1');

    expect(stored.isPersisted, isTrue);
    expect(stored.groupId, 'group_1');
    expect(stored.applicantId, 'user_2');
    expect(stored.applicantName, 'Mariana');
    expect(stored.message, 'Quiero entrar');
    expect(stored.status, GroupRequestStatus.pending);
  });

  test('cada estado tiene su etiqueta en español', () {
    expect(GroupRequestStatus.pending.label, 'Pendiente');
    expect(GroupRequestStatus.accepted.label, 'Aceptada');
    expect(GroupRequestStatus.rejected.label, 'Rechazada');
  });
}
