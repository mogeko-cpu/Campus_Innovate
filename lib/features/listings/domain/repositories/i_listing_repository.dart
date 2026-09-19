import '../models/join_request.dart';
import '../models/listing.dart';

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
}
