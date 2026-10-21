import '../models/mentorship_request.dart';

/// A team finding a mentor outside it: asking, and the answer.
abstract class IMentorshipRepository {
  /// The request a project is waiting on, or null.
  Future<MentorshipRequest?> getPendingFor(String listingId);

  /// Requests addressed to [mentorId] that are still waiting.
  Future<List<MentorshipRequest>> getMyInvitations(String mentorId);

  /// Somebody who works the project asks [MentorshipRequest.mentorId], who is
  /// not on the team, to mentor it.
  Future<MentorshipRequest> request(MentorshipRequest draft);

  /// The person asked says yes and joins the team as its mentor. Returns the
  /// request, so the caller knows whom to tell.
  Future<MentorshipRequest> accept({
    required String requestId,
    required String actorId,
  });

  Future<MentorshipRequest> reject({
    required String requestId,
    required String actorId,
  });

  /// Withdraws a request nobody has answered: whoever sent it, or the leader.
  Future<void> cancel({required String requestId, required String actorId});

  /// Removes the requests of a project that is being deleted.
  Future<void> purgeListing(String listingId);
}
