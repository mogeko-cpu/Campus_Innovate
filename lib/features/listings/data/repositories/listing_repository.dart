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
  Future<Listing?> getListingById(String id) => _source.getListingById(id);

  @override
  Future<Listing> createListing(Listing listing) =>
      _source.createListing(listing);

  @override
  Future<JoinRequest> createJoinRequest(JoinRequest request) =>
      _source.createJoinRequest(request);

  @override
  Future<List<JoinRequest>> getRequestsForListing(String listingId) =>
      _source.getRequestsForListing(listingId);

  @override
  Future<JoinRequest?> getMyRequestForListing({
    required String listingId,
    required String applicantId,
  }) async {
    final requests = await _source.getRequestsForListing(listingId);
    final index = requests.indexWhere(
      (request) => request.applicantId == applicantId,
    );

    return index == -1 ? null : requests[index];
  }

  @override
  /// Accepting is two writes and ROBLE has no transactions, so the order is
  /// chosen for what a failure between them leaves behind: the membership goes
  /// in **first**, and only then is the request marked accepted.
  ///
  /// Fail after the membership and the request still reads "Pendiente", so the
  /// creator accepts again and the second run fixes it — [IListingSource.addMember]
  /// is idempotent. The opposite order would show an accepted request whose
  /// applicant never joined, and retrying would look like a no-op.
  Future<void> acceptJoinRequest(String requestId) async {
    final request = await _source.getRequestById(requestId);

    if (request == null) {
      throw StateError('Solicitud $requestId no encontrada');
    }

    await _source.addMember(
      listingId: request.listingId,
      userId: request.applicantId,
    );
    await _source.updateRequestStatus(requestId, JoinRequestStatus.accepted);
  }

  @override
  Future<void> rejectJoinRequest(String requestId) =>
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

  @override
  Future<List<Listing>> getListingsByGroup(String groupId) async {
    if (groupId.isEmpty) return const [];

    final listings = await _source.getListings();

    return listings.where((listing) => listing.groupId == groupId).toList();
  }

  @override
  Future<List<JoinRequest>> getMyRequests(String applicantId) =>
      _source.getRequestsByApplicant(applicantId);

  @override
  Future<void> deleteListing(String listingId) =>
      _source.deleteListing(listingId);

}
