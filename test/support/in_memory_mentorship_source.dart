import 'package:campus_innovate/features/listings/data/datasources/i_mentorship_source.dart';
import 'package:campus_innovate/features/listings/domain/listing_exception.dart';
import 'package:campus_innovate/features/listings/domain/models/mentorship_request.dart';

/// [IMentorshipSource] in memory, with the one guarantee the table gives: the
/// `UNIQUE (listing_id)` that keeps a project to one request at a time.
class InMemoryMentorshipSource implements IMentorshipSource {
  final List<MentorshipRequest> _requests = [];

  var _nextId = 1;

  /// Everything waiting, for the assertions.
  List<MentorshipRequest> get all => List.unmodifiable(_requests);

  @override
  Future<MentorshipRequest?> getForListing(String listingId) async {
    for (final request in _requests) {
      if (request.listingId == listingId) return request;
    }

    return null;
  }

  @override
  Future<List<MentorshipRequest>> getForMentor(String mentorId) async =>
      _requests
          .where((request) => request.mentorId == mentorId)
          .toList()
          .reversed
          .toList();

  @override
  Future<MentorshipRequest?> getById(String id) async {
    for (final request in _requests) {
      if (request.id == id) return request;
    }

    return null;
  }

  @override
  Future<MentorshipRequest> create(MentorshipRequest request) async {
    if (_requests.any((item) => item.listingId == request.listingId)) {
      throw const ListingException(
        'Este proyecto ya tiene una solicitud de mentoría pendiente.',
      );
    }

    final stored = request.copyWith(id: 'mentorship_${_nextId++}');
    _requests.add(stored);

    return stored;
  }

  @override
  Future<void> delete(String id) async =>
      _requests.removeWhere((request) => request.id == id);

  @override
  Future<void> deleteFor(String listingId) async =>
      _requests.removeWhere((request) => request.listingId == listingId);
}
