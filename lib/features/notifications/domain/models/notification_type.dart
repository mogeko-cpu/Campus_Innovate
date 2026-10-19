/// What happened, which decides the icon and the wording of a notification.
enum NotificationType {
  comment,
  ideaPublished,
  requestReceived,
  requestAccepted,
  requestRejected,
  invitationReceived,
  invitationAccepted,
  invitationRejected;

  /// Stored in the `type` column. An unknown value (a type a newer version of
  /// the app wrote) reads as null so the notification can still be listed.
  static NotificationType? fromName(String? name) {
    for (final type in values) {
      if (type.name == name) return type;
    }

    return null;
  }
}
