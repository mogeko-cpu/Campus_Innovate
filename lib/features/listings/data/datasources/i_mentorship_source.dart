import '../../domain/models/mentorship_request.dart';

/// Storage contract for the mentorship requests waiting for an answer.
abstract class IMentorshipSource {
  /// The request waiting on [listingId], or null. There is one at most: the
  /// table's `UNIQUE (listing_id)` decides.
  Future<MentorshipRequest?> getForListing(String listingId);

  /// Requests addressed to [mentorId], newest first.
  Future<List<MentorshipRequest>> getForMentor(String mentorId);

  Future<MentorshipRequest?> getById(String id);

  /// Stores [request] and returns it with its id. A second one for the same
  /// project is refused with a `ListingException`.
  Future<MentorshipRequest> create(MentorshipRequest request);

  Future<void> delete(String id);

  /// Removes every request of a project that is being deleted.
  Future<void> deleteFor(String listingId);
}
