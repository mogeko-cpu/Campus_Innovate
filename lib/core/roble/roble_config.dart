/// Where ROBLE lives and which project the app talks to.
///
/// Neither value is a secret: the contract id is printed in the header of the
/// ROBLE console and travels in the path of every request, so it is compiled in
/// instead of being read from a file. Passwords and tokens never appear here —
/// they are typed by the user and kept in [RobleSession].
///
/// Point the app at another contract without touching the source:
///
/// ```bash
/// flutter run --dart-define=ROBLE_CONTRACT_ID=otro_contrato_ab12cd34
/// ```
abstract final class RobleConfig {
  /// Host of the API. The console lives on `roble.openlab…`, the API on
  /// `roble-api.openlab…`; mixing them up yields a 404 page, not a JSON error.
  static const String baseUrl = String.fromEnvironment(
    'ROBLE_BASE_URL',
    defaultValue: 'https://roble-api.openlab.uninorte.edu.co',
  );

  /// The project identifier from the ROBLE console.
  static const String contractId = String.fromEnvironment(
    'ROBLE_CONTRACT_ID',
    defaultValue: 'campus_innov_0ee3af93b1',
  );

  /// Tables the app owns. Every name used by a data source comes from here so
  /// that a rename is one edit and `docs/roble.md` has one place to match.
  /// Name of the return destination the social login comes back to.
  ///
  /// Not a URL on purpose: the ROBLE console keeps the list of allowed addresses
  /// and the app only names one of them, so a build can never send people to a
  /// destination the project owner did not approve. `default` is the entry that
  /// points at the web app.
  static const String socialRedirect = String.fromEnvironment(
    'ROBLE_SOCIAL_REDIRECT',
    defaultValue: 'default',
  );

  static const String listingsTable = 'listings';
  static const String listingMembersTable = 'listing_members';
  static const String joinRequestsTable = 'join_requests';

  /// Groups: the standing teams that publish projects.
  static const String groupsTable = 'groups';
  static const String groupMembersTable = 'group_members';
  static const String groupRequestsTable = 'group_requests';

  /// What happens around a project: votes, visits and comments. Counters are
  /// rows here and never columns on `listings`, because ROBLE has no conditional
  /// writes and `likes = likes + 1` would lose votes when two people tap at once.
  static const String listingReactionsTable = 'listing_reactions';
  static const String listingViewsTable = 'listing_views';
  static const String listingCommentsTable = 'listing_comments';
}
