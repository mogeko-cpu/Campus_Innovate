enum JoinRequestStatus {
  pending,
  accepted,
  rejected;

  String get label => switch (this) {
        JoinRequestStatus.pending => 'Pendiente',
        JoinRequestStatus.accepted => 'Aceptada',
        JoinRequestStatus.rejected => 'Rechazada',
      };
}
