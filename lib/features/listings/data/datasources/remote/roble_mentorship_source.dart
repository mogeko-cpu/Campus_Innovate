import '../../../../../core/roble/roble_client.dart';
import '../../../../../core/roble/roble_config.dart';
import '../../../../../core/roble/roble_duplicate.dart';
import '../../../../../core/roble/roble_exception.dart';
import '../../../domain/listing_exception.dart';
import '../../../domain/models/mentorship_request.dart';
import '../i_mentorship_source.dart';

/// Mentorship requests stored in ROBLE, one row per project while it waits.
///
/// The `UNIQUE (listing_id)` of the table — not this class — is what keeps a
/// project to one request at a time when two members ask in the same second.
class RobleMentorshipSource implements IMentorshipSource {
  RobleMentorshipSource(this._client);

  final RobleClient _client;

  @override
  Future<MentorshipRequest?> getForListing(String listingId) async {
    if (!RobleClient.isRowId(listingId)) return null;

    final rows = await _client.read(
      RobleConfig.mentorshipRequestsTable,
      filters: {'listing_id': listingId},
    );

    // Should a table created without the UNIQUE hold more than one, the oldest
    // is the one that was asked first.
    rows.sort(
      (a, b) => _dateOf(a['created_at']).compareTo(_dateOf(b['created_at'])),
    );

    return rows.map(_requestFrom).whereType<MentorshipRequest>().firstOrNull;
  }

  @override
  Future<List<MentorshipRequest>> getForMentor(String mentorId) async {
    if (mentorId.isEmpty) return const [];

    final rows = await _client.read(
      RobleConfig.mentorshipRequestsTable,
      filters: {'mentor_id': mentorId},
    );

    rows.sort(
      (a, b) => _dateOf(b['created_at']).compareTo(_dateOf(a['created_at'])),
    );

    return rows.map(_requestFrom).whereType<MentorshipRequest>().toList();
  }

  @override
  Future<MentorshipRequest?> getById(String id) async {
    if (!RobleClient.isRowId(id)) return null;

    final rows = await _client.read(
      RobleConfig.mentorshipRequestsTable,
      filters: {'_id': id},
    );

    return rows.isEmpty ? null : _requestFrom(rows.first);
  }

  @override
  Future<MentorshipRequest> create(MentorshipRequest request) async {
    final Map<String, dynamic> row;

    try {
      row = await _client.insertOne(RobleConfig.mentorshipRequestsTable, {
        'listing_id': request.listingId,
        'listing_title': request.listingTitle,
        'requester_id': request.requesterId,
        'requester_name': request.requesterName,
        'mentor_id': request.mentorId,
        'mentor_name': request.mentorName,
        'message': request.message,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    } on RobleException catch (error) {
      if (isDuplicateRow(error)) {
        throw const ListingException(
          'Este proyecto ya tiene una solicitud de mentoría pendiente.',
        );
      }
      rethrow;
    }

    return request.copyWith(id: row['_id']?.toString() ?? '');
  }

  @override
  Future<void> delete(String id) async {
    await _client.delete(
      tableName: RobleConfig.mentorshipRequestsTable,
      idValue: id,
    );
  }

  @override
  Future<void> deleteFor(String listingId) async {
    if (!RobleClient.isRowId(listingId)) return;

    final rows = await _client.read(
      RobleConfig.mentorshipRequestsTable,
      filters: {'listing_id': listingId},
    );

    for (final row in rows) {
      final id = row['_id']?.toString();
      if (id == null || id.isEmpty) continue;

      await delete(id);
    }
  }

  DateTime _dateOf(dynamic value) =>
      DateTime.tryParse(value?.toString() ?? '') ??
      DateTime.fromMillisecondsSinceEpoch(0);

  MentorshipRequest? _requestFrom(Map<String, dynamic> row) {
    final id = row['_id']?.toString();
    final listingId = row['listing_id']?.toString();
    if (id == null || id.isEmpty || listingId == null) return null;

    return MentorshipRequest(
      id: id,
      listingId: listingId,
      listingTitle: row['listing_title']?.toString() ?? '',
      requesterId: row['requester_id']?.toString() ?? '',
      requesterName: row['requester_name']?.toString() ?? 'Integrante',
      mentorId: row['mentor_id']?.toString() ?? '',
      mentorName: row['mentor_name']?.toString() ?? 'Mentor',
      message: row['message']?.toString() ?? '',
      createdAt: _dateOf(row['created_at']),
    );
  }
}
