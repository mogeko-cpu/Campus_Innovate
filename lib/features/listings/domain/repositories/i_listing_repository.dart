import '../models/join_request.dart';
import '../models/listing.dart';
import '../models/listing_role.dart';

abstract class IListingRepository {
  Future<List<Listing>> getListings();

  Future<List<Listing>> getFeaturedListings();

  Future<Listing?> getListingById(String id);

  Future<Listing> createListing(Listing listing);

  Future<JoinRequest> createJoinRequest(JoinRequest request);

  Future<List<JoinRequest>> getRequestsForListing(String listingId);

  Future<JoinRequest?> getMyRequestForListing({
    required String listingId,
    required String applicantId,
  });

  Future<void> acceptJoinRequest(String requestId);

  Future<void> rejectJoinRequest(String requestId);

  Future<List<Listing>> getMyListings(String userId);

  Future<List<Listing>> getJoinedListings(String userId);

  /// Projects published by one group, newest first.
  Future<List<Listing>> getListingsByGroup(String groupId);

  /// Requests the user sent to other people's projects, newest first.
  Future<List<JoinRequest>> getMyRequests(String applicantId);

  Future<void> deleteListing(String listingId);

  /// Saves the edit form. Only the leader may, and the team may not end up
  /// bigger than the new size.
  Future<Listing> updateListing(Listing updated, {required String actorId});

  /// Rejects every request still waiting on [listingId] and returns them, so the
  /// caller can tell each applicant. What closing a finished project means.
  Future<List<JoinRequest>> closePendingRequests(String listingId);

  /// The leader takes [userId] off the team.
  Future<void> removeMember({
    required String listingId,
    required String userId,
    required String actorId,
  });

  /// [userId] leaves the team by their own decision.
  Future<void> leaveListing({
    required String listingId,
    required String userId,
  });

  /// The leader makes [userId] a member or a mentor. Leadership changes hands
  /// only through [transferLeadership].
  Future<void> setMemberRole({
    required String listingId,
    required String userId,
    required ListingRole role,
    required String actorId,
  });

  /// The leader hands the project to [newLeaderId] and stays as a member.
  Future<void> transferLeadership({
    required String listingId,
    required String newLeaderId,
    required String actorId,
  });
}
