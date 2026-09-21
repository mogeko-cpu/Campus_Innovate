import 'dart:convert';

import '../../../../../core/roble/roble_client.dart';
import '../../../../../core/roble/roble_config.dart';
import '../../../../../core/roble/roble_exception.dart';
import '../../../domain/listing_exception.dart';
import '../../../domain/models/join_request.dart';
import '../../../domain/models/join_request_status.dart';
import '../../../domain/models/listing.dart';
import '../i_listing_source.dart';

/// Listings, members and join requests stored in ROBLE.
///
/// Three tables, because ROBLE has no transactions and no arrays worth
/// updating: members live in their own `listing_members` rows so that joining is
/// a single insert nobody can lose. A `jsonb` array of member ids inside
/// `listings` would need read-modify-write, and two people joining at the same
/// second would overwrite each other.
///
/// The database — not this class — is what makes double joins and double
/// requests impossible: `listing_members` and `join_requests` each carry a
/// composite `UNIQUE`, so the second insert is rejected even if two devices race.
class RobleListingSource implements IListingSource {
  RobleListingSource(this._client);

  final RobleClient _client;

  @override
  Future<List<Listing>> getListings() async {
    // Two full table reads: ROBLE offers no join and no `IN (…)`, so grouping
    // the members happens here. Fine at course scale (tens of projects), and the
    // place to revisit first if the data grows — see `docs/roble.md`.
    final rows = await _client.read(RobleConfig.listingsTable);
    final memberRows = await _client.read(RobleConfig.listingMembersTable);

    final membersByListing = <String, List<String>>{};
    for (final row in memberRows) {
      final listingId = row['listing_id']?.toString();
      final userId = row['user_id']?.toString();
      if (listingId == null || userId == null) continue;

      membersByListing.putIfAbsent(listingId, () => []).add(userId);
    }

    // Newest first. ROBLE cannot order a read, so the app sorts what it got.
    rows.sort((a, b) => _dateOf(b['created_at']).compareTo(_dateOf(a['created_at'])));

    return rows
        .map((row) => _listingFrom(row, membersByListing))
        .whereType<Listing>()
        .toList();
  }

  @override
  Future<Listing?> getListingById(String id) async {
    // A malformed id is "not found", never a request: `_id` is a `uuid` column
    // and comparing it with something else makes ROBLE answer 500.
    if (!RobleClient.isRowId(id)) return null;

    final rows = await _client.read(
      RobleConfig.listingsTable,
      filters: {'_id': id},
    );
    if (rows.isEmpty) return null;

    final memberIds = await _memberIdsOf(id);

    return _listingFrom(rows.first, {id: memberIds});
  }

  @override
  Future<Listing> createListing(Listing listing) async {
    final row = await _client.insertOne(RobleConfig.listingsTable, {
      'title': listing.title,
      'description': listing.description,
      'category': listing.category,
      'creator_id': listing.creatorId,
      'creator_name': listing.creatorName,
      'max_members': listing.maxMembers,
      'required_skills': listing.requiredSkills,
      'group_id': listing.groupId,
      'group_name': listing.groupName,
      'created_at': _now(),
    });

    final id = row['_id']?.toString();

    if (id == null || id.isEmpty) {
      throw const ListingException(
        'ROBLE guardó el proyecto pero no devolvió su identificador. '
        'Recarga la lista antes de volver a publicarlo.',
      );
    }

    // The creator's membership is a second write. If it fails the project would
    // exist with nobody in it and no screen to fix that, so the insert is undone
    // and the user sees the original error and can publish again.
    try {
      await _addMemberRow(listingId: id, userId: listing.creatorId);
    } catch (_) {
      await _deleteQuietly(RobleConfig.listingsTable, id);
      rethrow;
    }

    return listing.copyWith(id: id, memberIds: [listing.creatorId]);
  }

  @override
  Future<JoinRequest> createJoinRequest(JoinRequest request) async {
    final Map<String, dynamic> row;

    try {
      row = await _client.insertOne(RobleConfig.joinRequestsTable, {
        'listing_id': request.listingId,
        'applicant_id': request.applicantId,
        'applicant_name': request.applicantName,
        'motivation': request.motivation,
        'skills': request.skills,
        'availability': request.availability,
        'status': request.status.name,
        'created_at': _now(),
      });
    } on RobleException catch (error) {
      if (_looksLikeDuplicate(error)) {
        throw const ListingException(
          'Ya enviaste una solicitud a este proyecto.',
        );
      }
      rethrow;
    }

    return request.copyWith(id: row['_id']?.toString() ?? '');
  }

  @override
  Future<List<JoinRequest>> getRequestsForListing(String listingId) async {
    if (!RobleClient.isRowId(listingId)) return const [];

    final rows = await _client.read(
      RobleConfig.joinRequestsTable,
      filters: {'listing_id': listingId},
    );

    // Oldest first: whoever asked earliest appears at the top of the queue.
    rows.sort((a, b) => _dateOf(a['created_at']).compareTo(_dateOf(b['created_at'])));

    return rows.map(_requestFrom).whereType<JoinRequest>().toList();
  }

  @override
  Future<List<JoinRequest>> getRequestsByApplicant(String applicantId) async {
    final rows = await _client.read(
      RobleConfig.joinRequestsTable,
      filters: {'applicant_id': applicantId},
    );

    // Newest first: the last thing you applied to is the one you are waiting on.
    rows.sort((a, b) => _dateOf(b['created_at']).compareTo(_dateOf(a['created_at'])));

    return rows.map(_requestFrom).whereType<JoinRequest>().toList();
  }

  @override
  Future<JoinRequest?> getRequestById(String id) async {
    if (!RobleClient.isRowId(id)) return null;

    final rows = await _client.read(
      RobleConfig.joinRequestsTable,
      filters: {'_id': id},
    );

    return rows.isEmpty ? null : _requestFrom(rows.first);
  }

  @override
  Future<void> updateRequestStatus(
    String requestId,
    JoinRequestStatus status,
  ) async {
    await _client.update(
      tableName: RobleConfig.joinRequestsTable,
      idValue: requestId,
      updates: {'status': status.name},
    );
  }

  @override
  Future<void> addMember({
    required String listingId,
    required String userId,
  }) async {
    final listing = await getListingById(listingId);

    if (listing == null) {
      throw ListingException('El proyecto $listingId ya no existe.');
    }

    if (listing.memberIds.contains(userId)) return;

    if (listing.isFull) {
      throw const ListingException('El proyecto ya alcanzó su número máximo de integrantes.');
    }

    // Between the check above and this insert another device could take the last
    // slot, and ROBLE has no conditional write to prevent it: the ceiling is
    // advisory, so a project can end up with one member over `max_members`.
    // Accepted on purpose — the alternative is a saved query with a locking
    // `INSERT … SELECT`, which is a lot of machinery for a group of students who
    // can remove a member by hand.
    await _addMemberRow(listingId: listingId, userId: userId);
  }

  @override
  Future<void> deleteListing(String listingId) async {
    if (!RobleClient.isRowId(listingId)) {
      throw ListingException('El proyecto $listingId ya no existe.');
    }

    // Children first, project last, because there are no transactions: a failure
    // halfway leaves the project in place, still listed and still deletable. The
    // opposite order would leave members and requests pointing at a project
    // nobody can open.
    await _deleteRowsWhere(
      RobleConfig.listingMembersTable,
      'listing_id',
      listingId,
    );
    await _deleteRowsWhere(
      RobleConfig.joinRequestsTable,
      'listing_id',
      listingId,
    );

    await _client.delete(
      tableName: RobleConfig.listingsTable,
      idValue: listingId,
    );
  }

  // ------------------------------------------------------------- helpers

  /// Deletes every row of [tableName] whose [column] equals [value]. ROBLE
  /// deletes by `_id` only, so this is a read followed by one delete per row.
  Future<void> _deleteRowsWhere(
    String tableName,
    String column,
    String value,
  ) async {
    final rows = await _client.read(tableName, filters: {column: value});

    for (final row in rows) {
      final id = row['_id']?.toString();
      if (id == null || id.isEmpty) continue;

      await _client.delete(tableName: tableName, idValue: id);
    }
  }

  Future<void> _addMemberRow({
    required String listingId,
    required String userId,
  }) async {
    try {
      await _client.insertOne(RobleConfig.listingMembersTable, {
        'listing_id': listingId,
        'user_id': userId,
        'joined_at': _now(),
      });
    } on RobleException catch (error) {
      // The composite UNIQUE did its job: they are already in. Being a member
      // is the outcome the caller wanted, so this is a success.
      if (_looksLikeDuplicate(error)) return;
      rethrow;
    }
  }

  Future<List<String>> _memberIdsOf(String listingId) async {
    final rows = await _client.read(
      RobleConfig.listingMembersTable,
      filters: {'listing_id': listingId},
    );

    return rows
        .map((row) => row['user_id']?.toString())
        .whereType<String>()
        .toList();
  }

  /// Best-effort cleanup: if this fails there is nothing more to try, and the
  /// caller's error is the one worth reporting.
  Future<void> _deleteQuietly(String tableName, String id) async {
    try {
      await _client.delete(tableName: tableName, idValue: id);
    } on RobleException {
      // Ignored on purpose.
    }
  }

  /// Whether ROBLE's error is a `UNIQUE` violation.
  ///
  /// It has to be read out of the message, because ROBLE forwards the PostgreSQL
  /// error without a code of its own and the status may be 400 or 500. When the
  /// wording changes this stops matching and the user sees the generic error
  /// instead of a friendly one — wrong message, never wrong data: the constraint
  /// is what actually prevents the duplicate.
  bool _looksLikeDuplicate(RobleException error) {
    final message = error.message.toLowerCase();

    return message.contains('duplicate') ||
        message.contains('unique') ||
        message.contains('llave duplicada') ||
        message.contains('23505');
  }

  String _now() => DateTime.now().toUtc().toIso8601String();

  /// Rows missing `created_at` sort last instead of crashing the list.
  DateTime _dateOf(dynamic value) =>
      DateTime.tryParse(value?.toString() ?? '') ??
      DateTime.fromMillisecondsSinceEpoch(0);

  Listing? _listingFrom(
    Map<String, dynamic> row,
    Map<String, List<String>> membersByListing,
  ) {
    final id = row['_id']?.toString();
    if (id == null || id.isEmpty) return null;

    return Listing(
      id: id,
      title: row['title']?.toString() ?? '',
      description: row['description']?.toString() ?? '',
      category: row['category']?.toString() ?? '',
      creatorId: row['creator_id']?.toString() ?? '',
      creatorName: row['creator_name']?.toString() ?? '',
      maxMembers: _intOf(row['max_members'], fallback: 1),
      requiredSkills: _stringsOf(row['required_skills']),
      memberIds: membersByListing[id] ?? const [],
      groupId: row['group_id']?.toString() ?? '',
      groupName: row['group_name']?.toString() ?? '',
    );
  }

  JoinRequest? _requestFrom(Map<String, dynamic> row) {
    final id = row['_id']?.toString();
    final listingId = row['listing_id']?.toString();
    if (id == null || id.isEmpty || listingId == null) return null;

    return JoinRequest(
      id: id,
      listingId: listingId,
      applicantId: row['applicant_id']?.toString() ?? '',
      applicantName: row['applicant_name']?.toString() ?? '',
      motivation: row['motivation']?.toString() ?? '',
      skills: row['skills']?.toString() ?? '',
      availability: row['availability']?.toString() ?? '',
      status: _statusOf(row['status']),
    );
  }

  /// `status` is a plain `text` column holding the enum's name. An unknown value
  /// reads as pending, the state that leaves the request visible and actionable.
  JoinRequestStatus _statusOf(dynamic value) {
    final name = value?.toString();

    return JoinRequestStatus.values.firstWhere(
      (status) => status.name == name,
      orElse: () => JoinRequestStatus.pending,
    );
  }

  int _intOf(dynamic value, {required int fallback}) {
    if (value is int) return value;
    if (value is num) return value.toInt();

    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  /// `required_skills` is `jsonb`, so it comes back as a real list — except when
  /// it arrives as the raw JSON text, which ROBLE does for some column types.
  List<String> _stringsOf(dynamic value) {
    if (value is List) {
      return value.map((item) => item.toString()).toList();
    }

    if (value is String && value.trim().isNotEmpty) {
      final trimmed = value.trim();
      if (!trimmed.startsWith('[')) return [trimmed];

      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is List) {
          return decoded.map((item) => item.toString()).toList();
        }
      } on FormatException {
        // Not JSON after all; better an empty skill list than a broken screen.
      }
    }

    return const [];
  }
}
