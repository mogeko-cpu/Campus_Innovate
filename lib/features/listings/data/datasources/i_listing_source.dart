import '../../domain/models/join_request.dart';
import '../../domain/models/join_request_status.dart';
import '../../domain/models/listing.dart';

/// Storage contract for listings and join requests.
///
/// Shared by the in-memory implementation used today and by the HTTP
/// implementation that will replace it once the backend exists.
abstract class IListingSource {
  Future<List<Listing>> getListings();

  Future<Listing?> getListingById(int id);

  Future<Listing> createListing(Listing listing);

  Future<JoinRequest> createJoinRequest(JoinRequest request);

  Future<List<JoinRequest>> getRequestsForListing(int listingId);

  Future<JoinRequest?> getRequestById(int id);

  Future<void> updateRequestStatus(int requestId, JoinRequestStatus status);

  Future<void> addMember({required int listingId, required String userId});
}
