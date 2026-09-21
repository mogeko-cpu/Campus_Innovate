import 'package:campus_innovate/features/listings/data/datasources/i_engagement_source.dart';
import 'package:campus_innovate/features/listings/domain/models/listing_comment.dart';
import 'package:campus_innovate/features/listings/domain/models/listing_stats.dart';
import 'package:campus_innovate/features/listings/domain/models/reaction_type.dart';

/// [IEngagementSource] in memory, for the widget tests.
///
/// It mimics the two guarantees the real tables give: one reaction and one view
/// per person and project, which in ROBLE are composite `UNIQUE`s and here are
/// a map keyed the same way.
class InMemoryEngagementSource implements IEngagementSource {
  /// Reaction by "listingId|userId", the in-memory stand-in for
  /// `UNIQUE (listing_id, user_id)`.
  final Map<String, ReactionType> _reactions = {};
  final Set<String> _views = {};
  final List<ListingComment> _comments = [];

  var _nextId = 500;

  String _key(String listingId, String userId) => '$listingId|$userId';

  @override
  Future<Map<String, ListingStats>> getStats({required String userId}) async {
    final ids = <String>{
      ..._reactions.keys.map((key) => key.split('|').first),
      ..._views.map((key) => key.split('|').first),
      ..._comments.map((comment) => comment.listingId),
    };

    return {
      for (final id in ids) id: await getStatsFor(listingId: id, userId: userId),
    };
  }

  @override
  Future<ListingStats> getStatsFor({
    required String listingId,
    required String userId,
  }) async {
    var likes = 0;
    var dislikes = 0;

    _reactions.forEach((key, reaction) {
      if (key.split('|').first != listingId) return;

      if (reaction == ReactionType.like) {
        likes++;
      } else {
        dislikes++;
      }
    });

    return ListingStats(
      likes: likes,
      dislikes: dislikes,
      views: _views.where((key) => key.split('|').first == listingId).length,
      comments:
          _comments.where((comment) => comment.listingId == listingId).length,
      myReaction: _reactions[_key(listingId, userId)],
    );
  }

  @override
  Future<void> setReaction({
    required String listingId,
    required String groupId,
    required String userId,
    required ReactionType? reaction,
  }) async {
    final key = _key(listingId, userId);

    if (reaction == null) {
      _reactions.remove(key);
      return;
    }

    _reactions[key] = reaction;
  }

  @override
  Future<void> registerView({
    required String listingId,
    required String groupId,
    required String userId,
  }) async {
    // A Set, so the same person opening it twice does not count twice.
    _views.add(_key(listingId, userId));
  }

  @override
  Future<List<ListingComment>> getComments(String listingId) async {
    final comments = _comments
        .where((comment) => comment.listingId == listingId)
        .toList();

    comments.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return comments;
  }

  @override
  Future<ListingComment> addComment(ListingComment comment) async {
    final stored = comment.copyWith(id: 'comment_${_nextId++}');
    _comments.add(stored);

    return stored;
  }

  @override
  Future<void> deleteComment(String commentId) async {
    _comments.removeWhere((comment) => comment.id == commentId);
  }

  @override
  Future<void> purgeListing(String listingId) async {
    _reactions.removeWhere((key, _) => key.split('|').first == listingId);
    _views.removeWhere((key) => key.split('|').first == listingId);
    _comments.removeWhere((comment) => comment.listingId == listingId);
  }
}
