/// Where a project stands, from the first idea to the finished thing.
///
/// Stored as the enum's name in the `status` column of `listings`. Rows written
/// before the column existed have no value and read as [idea], which is what
/// every project was until now.
enum ListingStatus {
  idea,
  inProgress,
  paused,
  done;

  String get label => switch (this) {
        ListingStatus.idea => 'Idea',
        ListingStatus.inProgress => 'En curso',
        ListingStatus.paused => 'Pausado',
        ListingStatus.done => 'Terminado',
      };

  /// Only a project still taking shape or under way is looking for people. A
  /// paused one may come back, but asking to join something nobody is working
  /// on would leave the request waiting with no one to answer it.
  bool get acceptsRequests =>
      this == ListingStatus.idea || this == ListingStatus.inProgress;

  /// An unknown value reads as [idea]: the state that keeps the project visible
  /// and open, rather than hiding it because of a value this version does not
  /// know.
  static ListingStatus fromName(String? name) {
    for (final status in values) {
      if (status.name == name) return status;
    }

    return ListingStatus.idea;
  }
}
