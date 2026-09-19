import '../../domain/models/join_request.dart';
import '../../domain/models/join_request_status.dart';
import '../../domain/models/listing.dart';

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

  Future<JoinRequest> createJoinRequest(JoinRequest request);

  Future<List<JoinRequest>> getRequestsForListing(String listingId);

  Future<JoinRequest?> getRequestById(String id);

  Future<void> updateRequestStatus(String requestId, JoinRequestStatus status);

  /// Adds [userId] to the members of [listingId].
  ///
  /// Idempotent: adding someone who is already a member is not an error.
  Future<void> addMember({required String listingId, required String userId});
}
