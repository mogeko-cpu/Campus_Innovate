/// Something someone wrote under a project.
class ListingComment {
  /// `_id` of the row in `listing_comments`; empty on a draft.
  final String id;
  final String listingId;

  /// The group the project belongs to, copied in when the row is written.
  ///
  /// Redundant with `listings.group_id` on purpose: it lets a group screen read
  /// every comment under its own projects with one equality filter, which is the
  /// only kind of filter ROBLE offers, and keeps the comments of one group from
  /// ever being counted for another.
  final String groupId;
  final String authorId;
  final String authorName;
  final String body;
  final DateTime createdAt;

  const ListingComment({
    required this.id,
    required this.listingId,
    required this.groupId,
    required this.authorId,
    required this.authorName,
    required this.body,
    required this.createdAt,
  });

  /// A comment as the field leaves it: no [id] yet, dated now.
  ListingComment.draft({
    required this.listingId,
    required this.groupId,
    required this.authorId,
    required this.authorName,
    required this.body,
    DateTime? createdAt,
  })  : id = '',
        createdAt = createdAt ?? DateTime.now();

  bool get isPersisted => id.isNotEmpty;

  ListingComment copyWith({
    String? id,
    String? listingId,
    String? groupId,
    String? authorId,
    String? authorName,
    String? body,
    DateTime? createdAt,
  }) {
    return ListingComment(
      id: id ?? this.id,
      listingId: listingId ?? this.listingId,
      groupId: groupId ?? this.groupId,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      body: body ?? this.body,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
