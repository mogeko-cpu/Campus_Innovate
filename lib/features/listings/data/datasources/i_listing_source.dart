import '../../domain/models/join_request.dart';
import '../../domain/models/join_request_status.dart';
import '../../domain/models/listing.dart';
import '../../domain/models/listing_role.dart';

/// Storage contract for listings and join requests.
///
/// Implemented against ROBLE by `RobleListingSource`, which the app uses, and
/// in memory by the double the widget tests run on.
///
/// Ids are the `_id` UUIDs of the rows, as strings: whoever creates a row gets
/// its id back from [createListing] / [createJoinRequest] and only then can
/// point at it.
abstract class IListingSource {
  Future<List<Listing>> getListings();

  Future<Listing?> getListingById(String id);

  /// Stores [listing] — which arrives without an id — and returns it with the
  /// id the database assigned.
  Future<Listing> createListing(Listing listing);

  /// Writes what the edit form changes — title, description, category, size,
  /// skills and status — onto the stored project, and returns it as stored.
  ///
  /// Members, creator and group are not touched: they change through their own
  /// operations, never as a side effect of editing the text.
  Future<Listing> updateListing(Listing listing);

  Future<JoinRequest> createJoinRequest(JoinRequest request);

  Future<List<JoinRequest>> getRequestsForListing(String listingId);

  Future<JoinRequest?> getRequestById(String id);

  /// Every request one person sent, across projects. Backs the profile screen,
  /// which is where someone looks to remember what they applied to.
  Future<List<JoinRequest>> getRequestsByApplicant(String applicantId);

  Future<void> updateRequestStatus(String requestId, JoinRequestStatus status);

  /// Adds [userId] to the members of [listingId] as a plain member.
  ///
  /// Idempotent: adding someone who is already a member is not an error.
  Future<void> addMember({
    required String listingId,
    required String userId,
    String userName = '',
  });

  /// Takes [userId] off the team. Removing somebody who is not on it is not an
  /// error.
  Future<void> removeMember({
    required String listingId,
    required String userId,
  });

  /// Gives [userId], who is on the team, the [role].
  Future<void> setMemberRole({
    required String listingId,
    required String userId,
    required ListingRole role,
  });

  /// Removes the project and the rows that only made sense inside it: its
  /// members and its join requests.
  ///
  /// Its likes, views and comments live in another source and are removed by
  /// the caller — ROBLE has no cascades, so somebody has to do it by hand.
  Future<void> deleteListing(String listingId);
}
