import 'listing.dart';
import 'listing_stats.dart';

/// A project with the place it earned in the ranking.
class RankedListing {
  /// 1 for the project at the top. Stored rather than derived from the index so
  /// the widget does not have to know it is inside an ordered list.
  final int position;
  final Listing listing;
  final ListingStats stats;

  const RankedListing({
    required this.position,
    required this.listing,
    required this.stats,
  });

  /// Orders projects the way the ranking screen shows them.
  ///
  /// Score first — likes minus dislikes — and then the tie-breakers, in the
  /// order of how much work they represent: being discussed beats being seen,
  /// being seen beats nothing. The title settles the rest so that two projects
  /// with no activity at all keep a stable order between reloads instead of
  /// swapping places on every refresh.
  static int compare(
    ({Listing listing, ListingStats stats}) a,
    ({Listing listing, ListingStats stats}) b,
  ) {
    final byScore = b.stats.score.compareTo(a.stats.score);
    if (byScore != 0) return byScore;

    final byComments = b.stats.comments.compareTo(a.stats.comments);
    if (byComments != 0) return byComments;

    final byViews = b.stats.views.compareTo(a.stats.views);
    if (byViews != 0) return byViews;

    return a.listing.title.toLowerCase().compareTo(
          b.listing.title.toLowerCase(),
        );
  }
}
