import '../models/join_request.dart';
import '../models/listing.dart';

abstract class IListingRepository {
  Future<List<Listing>> getListings();

  Future<List<Listing>> getFeaturedListings();

  Future<Listing?> getListingById(int id);

  Future<Listing> createListing(Listing listing);

  Future<JoinRequest> createJoinRequest(JoinRequest request);

  Future<List<JoinRequest>> getRequestsForListing(int listingId);

  Future<JoinRequest?> getMyRequestForListing({
    required int listingId,
    required String applicantId,
  });

  Future<void> acceptJoinRequest(int requestId);

  Future<void> rejectJoinRequest(int requestId);

  Future<List<Listing>> getMyListings(String userId);

  Future<List<Listing>> getJoinedListings(String userId);
}
