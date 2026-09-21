import '../../../../../core/roble/roble_client.dart';
import '../../../../../core/roble/roble_config.dart';
import '../../../../../core/roble/roble_duplicate.dart';
import '../../../../../core/roble/roble_exception.dart';
import '../../../domain/listing_exception.dart';
import '../../../domain/models/listing_comment.dart';
import '../../../domain/models/listing_stats.dart';
import '../../../domain/models/reaction_type.dart';
import '../i_engagement_source.dart';

/// Votes, visits and comments stored in ROBLE.
///
/// Counters are rows, never columns on `listings`: ROBLE has no conditional
/// writes, so `likes = likes + 1` would be a read-modify-write and two people
/// voting in the same second would lose one of the two votes. Counting rows
/// cannot drift, and the composite `UNIQUE`s are what stop a second vote or a
/// second view from the same person.
class RobleEngagementSource implements IEngagementSource {
  RobleEngagementSource(this._client);

  final RobleClient _client;

  @override
  Future<Map<String, ListingStats>> getStats({required String userId}) async {
    final reactionRows = await _client.read(RobleConfig.listingReactionsTable);
    final viewRows = await _client.read(RobleConfig.listingViewsTable);
    final commentRows = await _client.read(RobleConfig.listingCommentsTable);

    final likes = <String, int>{};
    final dislikes = <String, int>{};
    final mine = <String, ReactionType>{};
    final views = <String, int>{};
    final comments = <String, int>{};

    for (final row in reactionRows) {
      final listingId = row['listing_id']?.toString();
      if (listingId == null) continue;

      final reaction = ReactionType.fromValue(_intOf(row['value']));
      if (reaction == null) continue;

      if (reaction == ReactionType.like) {
        likes[listingId] = (likes[listingId] ?? 0) + 1;
      } else {
        dislikes[listingId] = (dislikes[listingId] ?? 0) + 1;
      }

      if (row['user_id']?.toString() == userId) {
        mine[listingId] = reaction;
      }
    }

    for (final row in viewRows) {
      final listingId = row['listing_id']?.toString();
      if (listingId == null) continue;

      views[listingId] = (views[listingId] ?? 0) + 1;
    }

    for (final row in commentRows) {
      final listingId = row['listing_id']?.toString();
      if (listingId == null) continue;

      comments[listingId] = (comments[listingId] ?? 0) + 1;
    }

    final ids = <String>{
      ...likes.keys,
      ...dislikes.keys,
      ...views.keys,
      ...comments.keys,
    };

    return {
      for (final id in ids)
        id: ListingStats(
          likes: likes[id] ?? 0,
          dislikes: dislikes[id] ?? 0,
          views: views[id] ?? 0,
          comments: comments[id] ?? 0,
          myReaction: mine[id],
        ),
    };
  }

  @override
  Future<ListingStats> getStatsFor({
    required String listingId,
    required String userId,
  }) async {
    if (!RobleClient.isRowId(listingId)) return ListingStats.empty;

    final reactionRows = await _client.read(
      RobleConfig.listingReactionsTable,
      filters: {'listing_id': listingId},
    );
    final viewRows = await _client.read(
      RobleConfig.listingViewsTable,
      filters: {'listing_id': listingId},
    );
    final commentRows = await _client.read(
      RobleConfig.listingCommentsTable,
      filters: {'listing_id': listingId},
    );

    var likes = 0;
    var dislikes = 0;
    ReactionType? mine;

    for (final row in reactionRows) {
      final reaction = ReactionType.fromValue(_intOf(row['value']));
      if (reaction == null) continue;

      if (reaction == ReactionType.like) {
        likes++;
      } else {
        dislikes++;
      }

      if (row['user_id']?.toString() == userId) mine = reaction;
    }

    return ListingStats(
      likes: likes,
      dislikes: dislikes,
      views: viewRows.length,
      comments: commentRows.length,
      myReaction: mine,
    );
  }

  @override
  Future<void> setReaction({
    required String listingId,
    required String groupId,
    required String userId,
    required ReactionType? reaction,
  }) async {
    if (!RobleClient.isRowId(listingId)) {
      throw const ListingException('Este proyecto ya no existe.');
    }

    final rows = await _client.read(
      RobleConfig.listingReactionsTable,
      filters: {'listing_id': listingId, 'user_id': userId},
    );

    final existingId = rows.isEmpty ? null : rows.first['_id']?.toString();

    // Taking the vote back.
    if (reaction == null) {
      if (existingId != null) {
        await _client.delete(
          tableName: RobleConfig.listingReactionsTable,
          idValue: existingId,
        );
      }

      return;
    }

    // Changing your mind: the row is already yours, so this is an update and the
    // UNIQUE never comes into play.
    if (existingId != null) {
      await _client.update(
        tableName: RobleConfig.listingReactionsTable,
        idValue: existingId,
        updates: {'value': reaction.value},
      );

      return;
    }

    try {
      await _client.insertOne(RobleConfig.listingReactionsTable, {
        'listing_id': listingId,
        'group_id': groupId,
        'user_id': userId,
        'value': reaction.value,
        'created_at': _now(),
      });
    } on RobleException catch (error) {
      // Another device voted between the read and this insert. Their row is as
      // good as ours would have been, so this is not a failure worth showing.
      if (isDuplicateRow(error)) return;
      rethrow;
    }
  }

  @override
  Future<void> registerView({
    required String listingId,
    required String groupId,
    required String userId,
  }) async {
    if (!RobleClient.isRowId(listingId)) return;

    try {
      await _client.insertOne(RobleConfig.listingViewsTable, {
        'listing_id': listingId,
        'group_id': groupId,
        'user_id': userId,
        'viewed_at': _now(),
      });
    } on RobleException catch (error) {
      // Already counted. A view is a side effect of opening a screen, so a
      // failure here must never become an error in front of the user.
      if (isDuplicateRow(error)) return;
      rethrow;
    }
  }

  @override
  Future<List<ListingComment>> getComments(String listingId) async {
    if (!RobleClient.isRowId(listingId)) return const [];

    final rows = await _client.read(
      RobleConfig.listingCommentsTable,
      filters: {'listing_id': listingId},
    );

    // Newest first: a conversation is read from the top.
    rows.sort(
      (a, b) => _dateOf(b['created_at']).compareTo(_dateOf(a['created_at'])),
    );

    return rows.map(_commentFrom).whereType<ListingComment>().toList();
  }

  @override
  Future<ListingComment> addComment(ListingComment comment) async {
    final row = await _client.insertOne(RobleConfig.listingCommentsTable, {
      'listing_id': comment.listingId,
      'group_id': comment.groupId,
      'author_id': comment.authorId,
      'author_name': comment.authorName,
      'body': comment.body,
      'created_at': _now(),
    });

    return comment.copyWith(id: row['_id']?.toString() ?? '');
  }

  @override
  Future<void> deleteComment(String commentId) => _client.delete(
        tableName: RobleConfig.listingCommentsTable,
        idValue: commentId,
      );

  @override
  Future<void> purgeListing(String listingId) async {
    await _deleteRowsOf(RobleConfig.listingReactionsTable, listingId);
    await _deleteRowsOf(RobleConfig.listingViewsTable, listingId);
    await _deleteRowsOf(RobleConfig.listingCommentsTable, listingId);
  }

  // ------------------------------------------------------------- helpers

  /// ROBLE deletes by `_id` only, so this is a read followed by one delete per
  /// row.
  Future<void> _deleteRowsOf(String tableName, String listingId) async {
    final rows = await _client.read(
      tableName,
      filters: {'listing_id': listingId},
    );

    for (final row in rows) {
      final id = row['_id']?.toString();
      if (id == null || id.isEmpty) continue;

      await _client.delete(tableName: tableName, idValue: id);
    }
  }

  String _now() => DateTime.now().toUtc().toIso8601String();

  DateTime _dateOf(dynamic value) =>
      DateTime.tryParse(value?.toString() ?? '') ??
      DateTime.fromMillisecondsSinceEpoch(0);

  ListingComment? _commentFrom(Map<String, dynamic> row) {
    final id = row['_id']?.toString();
    final listingId = row['listing_id']?.toString();
    if (id == null || id.isEmpty || listingId == null) return null;

    return ListingComment(
      id: id,
      listingId: listingId,
      groupId: row['group_id']?.toString() ?? '',
      authorId: row['author_id']?.toString() ?? '',
      authorName: row['author_name']?.toString() ?? 'Estudiante',
      body: row['body']?.toString() ?? '',
      createdAt: _dateOf(row['created_at']),
    );
  }

  int? _intOf(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();

    return int.tryParse(value?.toString() ?? '');
  }
}
