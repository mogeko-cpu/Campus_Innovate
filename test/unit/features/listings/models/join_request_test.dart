import 'package:campus_innovate/features/listings/domain/models/join_request.dart';
import 'package:campus_innovate/features/listings/domain/models/join_request_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const draft = JoinRequest.draft(
    listingId: 'listing_1',
    applicantId: 'user_2',
    applicantName: 'Mariana',
    motivation: 'Me interesa',
    skills: 'Flutter',
    availability: '10 h',
  );

  test('un borrador no tiene id y está pendiente', () {
    expect(draft.id, isEmpty);
    expect(draft.isPersisted, isFalse);
    expect(draft.status, JoinRequestStatus.pending);
  });

  test('copyWith con id la marca como guardada y conserva el resto', () {
    final stored = draft.copyWith(id: 'request_1');

    expect(stored.isPersisted, isTrue);
    expect(stored.listingId, 'listing_1');
    expect(stored.applicantId, 'user_2');
    expect(stored.applicantName, 'Mariana');
    expect(stored.motivation, 'Me interesa');
    expect(stored.skills, 'Flutter');
    expect(stored.availability, '10 h');
    expect(stored.status, JoinRequestStatus.pending);
  });

  test('copyWith puede cambiar el estado', () {
    expect(
      draft.copyWith(status: JoinRequestStatus.accepted).status,
      JoinRequestStatus.accepted,
    );
  });

  test('cada estado tiene su etiqueta en español', () {
    expect(JoinRequestStatus.pending.label, 'Pendiente');
    expect(JoinRequestStatus.accepted.label, 'Aceptada');
    expect(JoinRequestStatus.rejected.label, 'Rechazada');
  });
}
