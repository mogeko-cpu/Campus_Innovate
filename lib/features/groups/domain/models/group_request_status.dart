/// Where a request to join a group stands.
///
/// Deliberately its own enum instead of reusing the listings one: the two
/// features store their status in different tables and neither should have to
/// change because the other does.
enum GroupRequestStatus {
  pending,
  accepted,
  rejected;

  String get label => switch (this) {
        GroupRequestStatus.pending => 'Pendiente',
        GroupRequestStatus.accepted => 'Aceptada',
        GroupRequestStatus.rejected => 'Rechazada',
      };
}
