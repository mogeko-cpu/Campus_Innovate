import '../models/listing_comment.dart';
import '../models/listing_stats.dart';
import '../models/reaction_type.dart';

abstract class IEngagementRepository {
  Future<Map<String, ListingStats>> getStats({required String userId});

  Future<ListingStats> getStatsFor({
    required String listingId,
    required String userId,
  });

  /// Applies a tap on the like or dislike button.
  ///
  /// Tapping the one already chosen takes the vote back; tapping the other one
  /// replaces it. The view models pass the button that was pressed, not the
  /// resulting state, so that rule lives in one place.
  Future<void> toggleReaction({
    required String listingId,
    required String groupId,
    required String userId,
    required ReactionType reaction,
    required ReactionType? current,
  });

  Future<void> registerView({
    required String listingId,
    required String groupId,
    required String userId,
  });

  Future<List<ListingComment>> getComments(String listingId);

  Future<ListingComment> addComment(ListingComment comment);

  Future<void> deleteComment(String commentId);

  Future<void> purgeListing(String listingId);
}
