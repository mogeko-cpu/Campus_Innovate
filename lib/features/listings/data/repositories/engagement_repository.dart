import '../../domain/listing_exception.dart';
import '../../domain/models/listing_comment.dart';
import '../../domain/models/listing_stats.dart';
import '../../domain/models/reaction_type.dart';
import '../../domain/repositories/i_engagement_repository.dart';
import '../datasources/i_engagement_source.dart';

class EngagementRepository implements IEngagementRepository {
  final IEngagementSource _source;

  EngagementRepository(this._source);

  @override
  Future<Map<String, ListingStats>> getStats({required String userId}) =>
      _source.getStats(userId: userId);

  @override
  Future<ListingStats> getStatsFor({
    required String listingId,
    required String userId,
  }) =>
      _source.getStatsFor(listingId: listingId, userId: userId);

  @override
  Future<void> toggleReaction({
    required String listingId,
    required String groupId,
    required String userId,
    required ReactionType reaction,
    required ReactionType? current,
  }) {
    // Pressing the button you already pressed undoes the vote; pressing the
    // other one replaces it.
    final next = current == reaction ? null : reaction;

    return _source.setReaction(
      listingId: listingId,
      groupId: groupId,
      userId: userId,
      reaction: next,
    );
  }

  @override
  Future<void> registerView({
    required String listingId,
    required String groupId,
    required String userId,
  }) =>
      _source.registerView(
        listingId: listingId,
        groupId: groupId,
        userId: userId,
      );

  @override
  Future<List<ListingComment>> getComments(String listingId) =>
      _source.getComments(listingId);

  @override
  Future<ListingComment> addComment(ListingComment comment) {
    if (comment.body.trim().isEmpty) {
      throw const ListingException('Escribe algo antes de comentar.');
    }

    return _source.addComment(comment);
  }

  @override
  Future<void> deleteComment(String commentId) =>
      _source.deleteComment(commentId);

  @override
  Future<void> purgeListing(String listingId) =>
      _source.purgeListing(listingId);
}
