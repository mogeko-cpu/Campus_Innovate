/// How someone valued a project.
///
/// Stored as the `value` column of `listing_reactions`: `1` for a like, `-1` for
/// a dislike, so the ranking score is a sum and never a second query. One row per
/// person and project — `UNIQUE (listing_id, user_id)` — so nobody votes twice,
/// and changing your mind is an update of the row you already have.
enum ReactionType {
  like(1),
  dislike(-1);

  const ReactionType(this.value);

  /// What lands in the `value` column.
  final int value;

  static ReactionType? fromValue(int? value) => switch (value) {
        1 => ReactionType.like,
        -1 => ReactionType.dislike,
        _ => null,
      };
}
