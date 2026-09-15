import '../../../../core/data/mock_data.dart';
import '../../domain/models/join_request.dart';
import '../../domain/models/listing.dart';
import '../../domain/repositories/i_listing_repository.dart';

class LocalListingRepository implements IListingRepository {
  @override
  Future<List<Listing>> getListings() async {
    return List.from(MockData.listings);
  }

  @override
  Future<Listing?> getListingById(int id) async {
    try {
      return MockData.listings.firstWhere(
        (listing) => listing.id == id,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Listing> createListing(Listing listing) async {
    MockData.listings.add(listing);

    return listing;
  }

  @override
  Future<JoinRequest> createJoinRequest(
    JoinRequest request,
  ) async {
    MockData.requests.add(request);

    return request;
  }

  @override
  Future<List<JoinRequest>> getRequestsForListing(
    int listingId,
  ) async {
    return MockData.requests
        .where(
          (request) => request.listingId == listingId,
        )
        .toList();
  }

  @override
  Future<void> acceptJoinRequest(int requestId) async {
    final index = MockData.requests.indexWhere(
      (request) => request.id == requestId,
    );

    if (index == -1) {
      throw Exception('Solicitud no encontrada');
    }

    final request = MockData.requests[index];

    MockData.requests[index] = request.copyWith(
      status: 'accepted',
    );

    final listingIndex = MockData.listings.indexWhere(
      (listing) => listing.id == request.listingId,
    );

    if (listingIndex == -1) {
      throw Exception('Proyecto no encontrado');
    }

    final listing = MockData.listings[listingIndex];

    if (!listing.memberIds.contains(request.applicantId)) {
      MockData.listings[listingIndex] = listing.copyWith(
        memberIds: [
          ...listing.memberIds,
          request.applicantId,
        ],
      );
    }
  }

  @override
  Future<void> rejectJoinRequest(int requestId) async {
    final index = MockData.requests.indexWhere(
      (request) => request.id == requestId,
    );

    if (index == -1) {
      throw Exception('Solicitud no encontrada');
    }

    MockData.requests[index] = MockData.requests[index].copyWith(
      status: 'rejected',
    );
  }

  @override
  Future<List<Listing>> getMyListings(
    String userId,
  ) async {
    return MockData.listings
        .where(
          (listing) => listing.creatorId == userId,
        )
        .toList();
  }

  @override
  Future<List<Listing>> getJoinedListings(
    String userId,
  ) async {
    return MockData.listings
        .where(
          (listing) => listing.memberIds.contains(userId),
        )
        .toList();
  }
}