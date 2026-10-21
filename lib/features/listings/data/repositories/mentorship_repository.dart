import '../../domain/listing_exception.dart';
import '../../domain/models/listing.dart';
import '../../domain/models/listing_role.dart';
import '../../domain/models/mentorship_request.dart';
import '../../domain/repositories/i_listing_repository.dart';
import '../../domain/repositories/i_mentorship_repository.dart';
import '../datasources/i_mentorship_source.dart';

/// Owns the rules of finding a mentor, which the source does not know:
///
/// - whoever works the project — leader or member — may ask; a mentor already
///   on it does not recruit the next one;
/// - the person asked is somebody **outside** the team, and the project does
///   not have a mentor yet;
/// - only that person answers, and saying yes puts them on the team with the
///   mentor role, where the rest of the project already knows what a mentor
///   may and may not do.
class MentorshipRepository implements IMentorshipRepository {
  MentorshipRepository(this._source, this._listings);

  final IMentorshipSource _source;
  final IListingRepository _listings;

  static const maxMessageLength = 500;

  @override
  Future<MentorshipRequest?> getPendingFor(String listingId) =>
      _source.getForListing(listingId);

  @override
  Future<List<MentorshipRequest>> getMyInvitations(String mentorId) =>
      _source.getForMentor(mentorId);

  @override
  Future<MentorshipRequest> request(MentorshipRequest draft) async {
    final message = draft.message.trim();

    if (draft.mentorId.isEmpty) {
      throw const ListingException(
        'Elige a la persona que quieres como mentor.',
      );
    }

    if (message.isEmpty) {
      throw const ListingException(
        'Cuéntale a la persona en qué necesita acompañamiento el equipo.',
      );
    }

    if (message.length > maxMessageLength) {
      throw const ListingException(
        'El mensaje es muy largo. Máximo $maxMessageLength caracteres.',
      );
    }

    final listing = await _requireListing(draft.listingId);

    if (!(listing.roleOf(draft.requesterId)?.canWorkTasks ?? false)) {
      throw const ListingException(
        'Solo el líder y los integrantes pueden solicitar mentoría.',
      );
    }

    if (listing.roleOf(draft.mentorId) != null) {
      throw const ListingException(
        'Esa persona ya hace parte del equipo. La mentoría es para alguien '
        'de afuera que acompañe el proyecto.',
      );
    }

    if (listing.hasMentor) {
      throw const ListingException('Este proyecto ya tiene mentor.');
    }

    final pending = await _source.getForListing(draft.listingId);

    if (pending != null) {
      throw ListingException(
        'Ya hay una solicitud de mentoría pendiente para '
        '${pending.mentorName}.',
      );
    }

    // The check above can be stale by the time this lands; the table's
    // `UNIQUE (listing_id)` is what really keeps it to one.
    return _source.create(
      draft.copyWith(message: message, listingTitle: listing.title),
    );
  }

  /// Two writes with no transaction, ordered like accepting a request to join:
  /// the mentor joins **first** and only then is the request deleted. Stopping
  /// between them leaves a request that can simply be accepted again — joining
  /// is idempotent — whereas the other order would lose the request with nobody
  /// added.
  @override
  Future<MentorshipRequest> accept({
    required String requestId,
    required String actorId,
  }) async {
    final request = await _requireRequest(requestId);
    _checkIsAsked(request, actorId);

    await _listings.addMentor(
      listingId: request.listingId,
      userId: request.mentorId,
      userName: request.mentorName,
    );
    await _source.delete(requestId);

    return request;
  }

  @override
  Future<MentorshipRequest> reject({
    required String requestId,
    required String actorId,
  }) async {
    final request = await _requireRequest(requestId);
    _checkIsAsked(request, actorId);

    await _source.delete(requestId);

    return request;
  }

  @override
  Future<void> cancel({
    required String requestId,
    required String actorId,
  }) async {
    final request = await _requireRequest(requestId);

    if (actorId != request.requesterId) {
      final listing = await _listings.getListingById(request.listingId);

      if (listing?.roleOf(actorId) != ListingRole.leader) {
        throw const ListingException(
          'Solo quien envió la solicitud o el líder del proyecto pueden '
          'cancelarla.',
        );
      }
    }

    await _source.delete(requestId);
  }

  @override
  Future<void> purgeListing(String listingId) => _source.deleteFor(listingId);

  void _checkIsAsked(MentorshipRequest request, String actorId) {
    if (request.mentorId == actorId) return;

    throw const ListingException(
      'Solo la persona a quien se le pidió la mentoría puede responderla.',
    );
  }

  Future<Listing> _requireListing(String listingId) async {
    final listing = await _listings.getListingById(listingId);

    if (listing == null) {
      throw const ListingException('Este proyecto ya no existe.');
    }

    return listing;
  }

  Future<MentorshipRequest> _requireRequest(String requestId) async {
    final request = await _source.getById(requestId);

    if (request == null) {
      throw const ListingException(
        'Esta solicitud de mentoría ya no existe.',
      );
    }

    return request;
  }
}
