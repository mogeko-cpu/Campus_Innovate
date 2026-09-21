import '../../domain/models/listing_comment.dart';
import '../../domain/models/listing_stats.dart';
import '../../domain/models/reaction_type.dart';

/// Storage contract for what happens *around* a project: votes, visits and
/// comments.
///
/// Kept apart from [IListingSource] because it answers a different question —
/// how a project is doing, not what it is — and because a screen that only
/// needs the counters should not have to know how a project is stored.
///
/// Every write carries the `groupId` of the project it belongs to, so a row can
/// be traced to one group without a join and the counters of two groups can
/// never mix.
abstract class IEngagementSource {
  /// Counters for every project at once, with [userId]'s own vote filled in.
  ///
  /// Three full table reads. ROBLE cannot group or count, so a screen listing
  /// twenty projects would otherwise need sixty requests against a budget of
  /// 100 per minute.
  Future<Map<String, ListingStats>> getStats({required String userId});

  Future<ListingStats> getStatsFor({
    required String listingId,
    required String userId,
  });

  /// Sets, changes or clears [userId]'s vote on a project.
  ///
  /// A null [reaction] removes the row, which is how a second tap on the button
  /// you already pressed undoes it.
  Future<void> setReaction({
    required String listingId,
    required String groupId,
    required String userId,
    required ReactionType? reaction,
  });

  /// Records that [userId] opened the project.
  ///
  /// Idempotent: the same person opening it again is not an error and does not
  /// count twice.
  Future<void> registerView({
    required String listingId,
    required String groupId,
    required String userId,
  });

  /// Comments of one project, newest first.
  Future<List<ListingComment>> getComments(String listingId);

  Future<ListingComment> addComment(ListingComment comment);

  Future<void> deleteComment(String commentId);

  /// Removes every reaction, view and comment of a project. Called when the
  /// project itself is deleted, since ROBLE has no cascades.
  Future<void> purgeListing(String listingId);
}
