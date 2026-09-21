import 'reaction_type.dart';

/// How a project is doing: the counters behind the card, the detail screen and
/// the ranking.
///
/// A value object built by counting rows, never stored as columns on `listings`.
/// Counters kept on the project row would need read-modify-write, and with no
/// transactions two people liking in the same second would lose one of the two
/// votes. Counting rows cannot drift.
class ListingStats {
  final int likes;
  final int dislikes;

  /// Distinct people who opened the project. A second visit by the same person
  /// does not count: the row already exists and `UNIQUE (listing_id, user_id)`
  /// rejects it, which also keeps the table from growing without limit.
  final int views;
  final int comments;

  /// What the current user voted, if anything. Drives the filled/outlined state
  /// of the two buttons.
  final ReactionType? myReaction;

  const ListingStats({
    this.likes = 0,
    this.dislikes = 0,
    this.views = 0,
    this.comments = 0,
    this.myReaction,
  });

  static const empty = ListingStats();

  /// What the ranking sorts by.
  int get score => likes - dislikes;

  bool get hasActivity =>
      likes > 0 || dislikes > 0 || views > 0 || comments > 0;

  ListingStats copyWith({
    int? likes,
    int? dislikes,
    int? views,
    int? comments,
    ReactionType? myReaction,
    bool clearMyReaction = false,
  }) {
    return ListingStats(
      likes: likes ?? this.likes,
      dislikes: dislikes ?? this.dislikes,
      views: views ?? this.views,
      comments: comments ?? this.comments,
      myReaction: clearMyReaction ? null : (myReaction ?? this.myReaction),
    );
  }
}
