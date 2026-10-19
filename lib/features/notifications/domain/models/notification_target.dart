/// What opening a notification should take the person to.
///
/// Kept as a kind and an id instead of a route: the domain does not know how the
/// app navigates, and a route written into the database would break the day a
/// path is renamed.
enum NotificationTarget {
  listing,
  group,
  none;

  static NotificationTarget fromName(String? name) {
    for (final target in values) {
      if (target.name == name) return target;
    }

    return NotificationTarget.none;
  }
}
