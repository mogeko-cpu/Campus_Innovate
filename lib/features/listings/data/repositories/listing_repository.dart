import '../../domain/models/join_request.dart';
import '../../domain/models/join_request_status.dart';
import '../../domain/models/listing.dart';
import '../../domain/repositories/i_listing_repository.dart';
import '../datasources/i_listing_source.dart';

class ListingRepository implements IListingRepository {
  final IListingSource _source;

  ListingRepository(this._source);

  @override
  Future<List<Listing>> getListings() => _source.getListings();

  @override
  Future<List<Listing>> getFeaturedListings() async {
    final listings = await _source.getListings();

    return listings.where((listing) => !listing.isFull).take(5).toList();
  }

  @override
  Future<Listing?> getListingById(int id) => _source.getListingById(id);

  @override
  Future<Listing> createListing(Listing listing) =>
      _source.createListing(listing);

  @override
  Future<JoinRequest> createJoinRequest(JoinRequest request) =>
      _source.createJoinRequest(request);

  @override
  Future<List<JoinRequest>> getRequestsForListing(int listingId) =>
      _source.getRequestsForListing(listingId);

  @override
  Future<JoinRequest?> getMyRequestForListing({
    required int listingId,
    required String applicantId,
  }) async {
    final requests = await _source.getRequestsForListing(listingId);
    final index = requests.indexWhere(
      (request) => request.applicantId == applicantId,
    );

    return index == -1 ? null : requests[index];
  }

  @override
  Future<void> acceptJoinRequest(int requestId) async {
    final request = await _source.getRequestById(requestId);

    if (request == null) {
      throw StateError('Solicitud $requestId no encontrada');
    }

    await _source.updateRequestStatus(requestId, JoinRequestStatus.accepted);
    await _source.addMember(
      listingId: request.listingId,
      userId: request.applicantId,
    );
  }

  @override
  Future<void> rejectJoinRequest(int requestId) =>
      _source.updateRequestStatus(requestId, JoinRequestStatus.rejected);

  @override
  Future<List<Listing>> getMyListings(String userId) async {
    final listings = await _source.getListings();

    return listings.where((listing) => listing.creatorId == userId).toList();
  }

  @override
  Future<List<Listing>> getJoinedListings(String userId) async {
    final listings = await _source.getListings();

    return listings
        .where((listing) => listing.memberIds.contains(userId))
        .toList();
  }

}
