/// What someone is to a project's team.
///
/// Stored as the enum's name in the `role` column of `listing_members`.
enum ListingRole {
  /// Runs the project: edits it, decides who joins, manages the team and the
  /// tasks. Exactly one, ideally — see `ListingRepository.transferLeadership`.
  leader,

  /// Works on it: creates and moves tasks.
  member,

  /// Follows it and advises — a professor, typically — without working the
  /// board: a mentor reads the tasks but does not create or move them.
  mentor;

  String get label => switch (this) {
        ListingRole.leader => 'Líder',
        ListingRole.member => 'Integrante',
        ListingRole.mentor => 'Mentor',
      };

  /// Whether this role works the task board.
  bool get canWorkTasks => this != ListingRole.mentor;

  /// Null for a row without a role, which is every row written before roles
  /// existed; the caller decides what such a row means.
  static ListingRole? fromName(String? name) {
    for (final role in values) {
      if (role.name == name) return role;
    }

    return null;
  }
}
